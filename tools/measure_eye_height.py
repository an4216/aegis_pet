"""정지 포즈 아트의 눈 세로 높이와 몸통(코어) 높이를 잰다.

왜 필요한가: mochi는 몸통이 아니라 **눈 세로 높이**가 사용자 지정 정규화 기준이다
(characters.gd TORSO_NORMALIZATION_EXEMPT). 그 기준을 검사하는 테스트가 없어서, 아트를
다시 뽑을 때 "눈 높이를 유지했는지"를 스스로 확인할 수단이 필요하다. 색상만으로 잡으면
눈·입·볼이 뭉쳐 40px처럼 나오므로 아래 세 조건을 모두 걸어야 눈만 남는다.

눈 판정 조건 (2026-08-11 확정, GDScript(tests/probe_tier_size.gd)와 동일 로직):
  1) 어두운 연결성분  — 루미넌스 <= 90, 알파 >= 128
  2) 채움률 >= 0.45   — bbox를 얼마나 채우는가 (안경테·나비넥타이는 낮다)
  3) 가로세로비 0.6~1.6 + 높이 15% 내 좌우 쌍  — 양복·머리장식 배제

코어(몸통) 높이는 **최대 연결성분**으로 잰다. naive 알파 bbox를 쓰면 안 된다 —
chars/mochi/sleep.png은 naive 87px인데 그중 18px이 Zzz 이펙트다(별개 덩어리 4개).
idle.png은 1덩어리라 두 방식이 같지만(72px), 다른 포즈로 재면 조용히 부풀어난다.

사용:
    python tools/measure_eye_height.py assets/sprites/chars/mochi/idle.png
    python tools/measure_eye_height.py assets/sprites/chars/mochi{,_evolved,_evolved2}/idle.png

출력의 `눈/코어`가 판정 지표다. mochi 진화 티어는 0.151~0.156이고 base는 0.229였다 —
이 비가 티어마다 다르면 눈 기준과 몸통 크기 사다리를 동시에 만족할 수 없다.
"""
import sys
from collections import deque

from PIL import Image

DARK_LUMA = 90      # 이보다 어두우면 눈 후보
MIN_ALPHA = 128
MIN_FILL = 0.45
MIN_AREA = 12
ASPECT_LO, ASPECT_HI = 0.6, 1.6
PAIR_HEIGHT_TOL = 0.15


def _components(image, keep):
    """keep(x, y)가 참인 픽셀들의 연결성분 목록."""
    width, height = image.size
    seen = bytearray(width * height)
    found = []
    for start_y in range(height):
        for start_x in range(width):
            index = start_y * width + start_x
            if seen[index] or not keep(start_x, start_y):
                seen[index] = 1
                continue
            queue = deque([(start_x, start_y)])
            seen[index] = 1
            points = []
            while queue:
                x, y = queue.popleft()
                points.append((x, y))
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < width and 0 <= ny < height):
                        continue
                    n = ny * width + nx
                    if seen[n]:
                        continue
                    seen[n] = 1
                    if keep(nx, ny):
                        queue.append((nx, ny))
            xs = [p[0] for p in points]
            ys = [p[1] for p in points]
            bw = max(xs) - min(xs) + 1
            bh = max(ys) - min(ys) + 1
            found.append({
                "h": bh, "w": bw, "area": len(points), "fill": len(points) / (bw * bh),
                "cx": (min(xs) + max(xs) + 1) / 2.0, "top": min(ys), "bottom": max(ys),
            })
    return found


def measure(path):
    image = Image.open(path).convert("RGBA")
    px = image.load()

    def opaque(x, y):
        return px[x, y][3] > 32

    def dark(x, y):
        r, g, b, a = px[x, y]
        return a >= MIN_ALPHA and (0.299 * r + 0.587 * g + 0.114 * b) <= DARK_LUMA

    body = _components(image, opaque)
    if not body:
        return None
    core = max(body, key=lambda c: c["area"])

    candidates = [c for c in _components(image, dark)
                  if c["area"] >= MIN_AREA and c["fill"] >= MIN_FILL
                  and ASPECT_LO <= c["w"] / c["h"] <= ASPECT_HI]
    candidates.sort(key=lambda c: -c["area"])
    eye = None
    for i, a in enumerate(candidates):
        for b in candidates[i + 1:]:
            if abs(a["h"] - b["h"]) / max(a["h"], b["h"]) > PAIR_HEIGHT_TOL:
                continue
            if abs(a["cx"] - b["cx"]) <= a["w"] * 0.8:
                continue
            eye = (a["h"] + b["h"]) / 2.0
            break
        if eye:
            break
    return {"canvas": image.size, "core": core["h"], "eye": eye,
            "naive": max(c["bottom"] for c in body) - min(c["top"] for c in body) + 1,
            "blobs": len(body)}


def main(paths):
    if not paths:
        print(__doc__)
        return 1
    for path in paths:
        result = measure(path)
        if result is None:
            print("%-52s (보이는 픽셀 없음)" % path)
            continue
        eye = result["eye"]
        canvas = result["canvas"][0]
        line = "%-52s 캔버스 %dpx  코어 %dpx" % (path, canvas, result["core"])
        if result["naive"] != result["core"]:
            # 출력에 em-dash를 쓰면 안 된다 — Windows 기본 콘솔(cp949)에서 UnicodeEncodeError가 난다.
            line += "  (naive bbox %dpx / 덩어리 %d개, 차이 %dpx는 이펙트다)" % (
                result["naive"], result["blobs"], result["naive"] - result["core"])
        if eye is None:
            line += "  눈: 쌍 검출 실패"
        else:
            line += "  눈 %.1fpx (128환산 %.1fpx)  눈/코어 %.3f" % (
                eye, eye * 128.0 / canvas, eye / result["core"])
        print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
