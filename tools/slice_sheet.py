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
