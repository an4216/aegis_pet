# -*- coding: utf-8 -*-
# ChatGPT 포즈 시트 → 게임 프레임 변환기.
# 1) 가짜 체커보드 배경 제거 (테두리 flood fill, 중립 밝은 회색/흰색만)
# 2) 균등 격자 슬라이스 + 알파 bbox 트리밍
# 3) 전 프레임 공통 스케일로 256x256 캔버스에 바닥 정렬 (걷기 프레임 흔들림 방지)
# 사용: python tools/slice_sheet.py <시트.png> <출력폴더> [poses] [cols] [rows]
import sys, os
from collections import deque
from PIL import Image, ImageFilter

CANVAS = 256
TARGET_H = 230          # 캔버스 내 캐릭터 최대 높이
BOTTOM_MARGIN = 6
DEFAULT_POSES = "idle,walk1,walk2,sleep,happy,sulk,sick,eat"


def is_neutral_light(px):
    r, g, b = px[0], px[1], px[2]
    return r > 190 and g > 190 and b > 190 and (max(r, g, b) - min(r, g, b)) < 14


def remove_checkerboard(im):
    """테두리에서 연결된 중립 밝은 픽셀만 배경으로 제거 (눈 하이라이트 등 내부 흰색 보존)."""
    im = im.convert("RGB")
    w, h = im.size
    px = im.load()
    bg = bytearray(w * h)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_neutral_light(px[x, y]) and not bg[y * w + x]:
                bg[y * w + x] = 1
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_neutral_light(px[x, y]) and not bg[y * w + x]:
                bg[y * w + x] = 1
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny * w + nx] and is_neutral_light(px[nx, ny]):
                bg[ny * w + nx] = 1
                queue.append((nx, ny))
    alpha = Image.new("L", (w, h), 255)
    alpha.putdata([0 if v else 255 for v in bg])
    # 경계 부드럽게 (체커보드 프린지 완화)
    alpha = alpha.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(0.7))
    out = im.convert("RGBA")
    out.putalpha(alpha)
    return out


def ensure_alpha(im):
    if im.mode == "RGBA":
        a = im.getchannel("A")
        lo = sum(a.histogram()[:16])
        if lo > im.size[0] * im.size[1] * 0.05:
            return im  # 진짜 투명
    return remove_checkerboard(im)


def drop_stray_fragments(cell, near_ratio=0.18):
    """칸 경계로 새어 들어온 이웃 캐릭터 조각 제거.
    가장 큰 덩어리 기준, bbox가 그 근처(near_ratio × 칸 크기)에 있는 덩어리만 유지
    (Zzz·반짝이 같은 본체 주변 장식은 보존)."""
    w, h = cell.size
    alpha = cell.getchannel("A").load()
    visited = bytearray(w * h)
    comps = []
    for sy in range(h):
        for sx in range(w):
            if visited[sy * w + sx] or alpha[sx, sy] < 20:
                continue
            queue = deque([(sx, sy)])
            visited[sy * w + sx] = 1
            minx, miny, maxx, maxy, count = sx, sy, sx, sy, 0
            while queue:
                x, y = queue.popleft()
                count += 1
                minx = min(minx, x); maxx = max(maxx, x)
                miny = min(miny, y); maxy = max(maxy, y)
                for nx, ny in ((x+1, y), (x-1, y), (x, y+1), (x, y-1)):
                    if 0 <= nx < w and 0 <= ny < h and not visited[ny * w + nx] and alpha[nx, ny] >= 20:
                        visited[ny * w + nx] = 1
                        queue.append((nx, ny))
            comps.append((count, (minx, miny, maxx, maxy)))
    if len(comps) <= 1:
        return cell
    comps.sort(reverse=True)
    mx0, my0, mx1, my1 = comps[0][1]
    margin = near_ratio * max(w, h)
    keep_zone = (mx0 - margin, my0 - margin, mx1 + margin, my1 + margin)
    out = cell.copy()
    px = out.load()
    for count, (x0, y0, x1, y1) in comps[1:]:
        if x1 >= keep_zone[0] and x0 <= keep_zone[2] and y1 >= keep_zone[1] and y0 <= keep_zone[3]:
            continue  # 본체 근처 장식 유지
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                p = px[x, y]
                px[x, y] = (p[0], p[1], p[2], 0)
    return out


def main():
    src = sys.argv[1]
    outdir = sys.argv[2]
    poses = (sys.argv[3] if len(sys.argv) > 3 else DEFAULT_POSES).split(",")
    cols = int(sys.argv[4]) if len(sys.argv) > 4 else 4
    rows = int(sys.argv[5]) if len(sys.argv) > 5 else 2
    os.makedirs(outdir, exist_ok=True)

    im = ensure_alpha(Image.open(src))
    w, h = im.size
    cw, ch = w / cols, h / rows

    frames = []
    for i, pose in enumerate(poses):
        if pose.startswith("_"):
            continue  # 사용하지 않는 칸 건너뛰기
        cx, cy = i % cols, i // cols
        cell = im.crop((int(cx * cw), int(cy * ch), int((cx + 1) * cw), int((cy + 1) * ch)))
        cell = drop_stray_fragments(cell)
        bbox = cell.getbbox()
        if bbox is None:
            print("WARN: empty cell", pose)
            continue
        frames.append((pose, cell.crop(bbox)))

    max_h = max(f.size[1] for _, f in frames)
    scale = min(TARGET_H / max_h, 1.0)
    for pose, frame in frames:
        fw, fh = int(frame.size[0] * scale), int(frame.size[1] * scale)
        frame = frame.resize((fw, fh), Image.LANCZOS)
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        canvas.paste(frame, ((CANVAS - fw) // 2, CANVAS - BOTTOM_MARGIN - fh), frame)
        path = os.path.join(outdir, pose + ".png")
        canvas.save(path)
        print("saved", path, "(%dx%d)" % (fw, fh))


if __name__ == "__main__":
    main()
