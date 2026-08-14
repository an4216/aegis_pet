# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13", "typer>=0.16,<1"]
# ///
# ─── How to run ───
# uv run tools/fit_keypose.py measure <keypose-dir>
# uv run tools/fit_keypose.py fit <new-pose.png> <keypose-dir>/<name>.png
"""새로 생성한 키포즈 1장을 기존 키포즈 세트의 기하에 맞춘다.

`build_keypose_motion.py` 는 8장 키포즈를 **한 세트로** 읽어 공통 배율(`common_scale`)을
정하고, 각 프레임을 bbox 아래끝 기준으로 접지시킨다. 그래서 한 장만 다시 생성해 그대로
끼워 넣으면 그 장의 몸 크기·접지선이 나머지 7장과 어긋나고, 결과적으로 **모든** 모션 시트의
배율이 함께 틀어진다(2026-08-14: sheet_scale 4개가 낡아 애니메이션 몸통이 15~25% 커져 있던
사고가 정확히 이 경로였다).

그래서 새 포즈를 넣기 전에 세 가지를 기존 장과 맞춘다:

  머리 위끝(top) · 발 접지선(feet bottom) · 발 중심 x

발 접지선을 bbox 아래끝이 아니라 **폭이 넓은 행**으로 잡는 것이 핵심이다 — 지팡이처럼 가는
소품이 발보다 아래로 내려오면 bbox 아래끝은 발이 아니라 지팡이 끝이 되고, 그대로 맞추면
캐릭터가 공중에 뜬다.
"""

from pathlib import Path
from typing import Final

import typer
from PIL import Image

VISIBLE_ALPHA: Final = 32
VISIBLE_LUT: Final = tuple(255 if a >= VISIBLE_ALPHA else 0 for a in range(256))
# 발은 넓고 지팡이는 가늘다. 이 폭 이상인 행만 접지 후보로 본다.
FOOT_MIN_WIDTH: Final = 30
# 좌우 안전 여백(px). 기존 키포즈 세트가 지키고 있는 값이며
# tests/test_build_keypose_motion.py 가 같은 계약을 검사한다.
SAFE_MARGIN: Final = 24
KEYPOSE_NAMES: Final = (
    "idle", "walk1", "walk2", "sleep", "sick", "sulk", "happy", "eat",
)


class KeyposeFitError(RuntimeError):
    pass


def _visible(image: Image.Image) -> Image.Image:
    return image.getchannel("A").point(VISIBLE_LUT)


def measure(image: Image.Image) -> dict[str, int]:
    visible = _visible(image)
    bounds = visible.getbbox()
    if bounds is None:
        raise KeyposeFitError("pose has no visible pixels")
    width = image.width
    data = visible.tobytes()
    feet_bottom = None
    for y in range(bounds[3] - 1, bounds[1] - 1, -1):
        row = data[y * width : (y + 1) * width]
        xs = [x for x, a in enumerate(row) if a]
        if xs and (max(xs) - min(xs) + 1) >= FOOT_MIN_WIDTH:
            feet_bottom = y + 1
            break
    if feet_bottom is None:
        raise KeyposeFitError("no row wide enough to be the feet")
    # 발 중심은 **넓은 덩어리만** 본다. 지팡이가 바닥까지 내려오면 발 띠 안에 같이 들어오는데,
    # 그 가는 기둥까지 평균에 넣으면 중심이 지팡이 쪽으로 끌려간다(실측 7px). 행마다 연속 구간을
    # 나눠 그 행에서 가장 넓은 구간의 40% 미만인 조각은 뺀다 — 절대 폭이 아니라 비율이라
    # 캔버스 크기나 캐릭터 덩치가 달라져도 그대로 성립한다.
    foot_band_top = max(bounds[1], feet_bottom - 12)
    xs: list[int] = []
    for y in range(foot_band_top, feet_bottom):
        row = data[y * width : (y + 1) * width]
        runs: list[list[int]] = []
        for x, alpha in enumerate(row):
            if not alpha:
                continue
            if runs and x == runs[-1][-1] + 1:
                runs[-1].append(x)
            else:
                runs.append([x])
        if not runs:
            continue
        widest = max(len(run) for run in runs)
        for run in runs:
            if len(run) >= widest * 0.4:
                xs.extend(run)
    return {
        "top": bounds[1],
        "bottom": bounds[3],
        "feet_bottom": feet_bottom,
        "feet_center_x": round(sum(xs) / len(xs)),
        "height": feet_bottom - bounds[1],
    }


app = typer.Typer(add_completion=False)


@app.command("measure")
def measure_dir(keypose_dir: Path) -> None:
    """키포즈 폴더의 8장 기하를 나란히 찍는다."""
    for name in KEYPOSE_NAMES:
        path = keypose_dir / f"{name}.png"
        if not path.exists():
            typer.echo(f"{name:8s} MISSING")
            continue
        with Image.open(path) as source:
            stats = measure(source.convert("RGBA"))
        typer.echo(
            f"{name:8s} canvas={source.size[0]}x{source.size[1]} "
            f"top={stats['top']:3d} feet_bottom={stats['feet_bottom']:3d} "
            f"bbox_bottom={stats['bottom']:3d} height={stats['height']:3d} "
            f"feet_cx={stats['feet_center_x']:3d}"
        )


@app.command("fit")
def fit(source: Path, target: Path, reference: Path | None = None) -> None:
    """`source` 를 `reference`(기본: 덮어쓸 `target` 의 현재 내용) 기하에 맞춰 `target` 으로 쓴다."""
    reference_path = reference or target
    with Image.open(reference_path) as image:
        reference_image = image.convert("RGBA")
        anchor = measure(reference_image)
        canvas = reference_image.size
    with Image.open(source) as image:
        pose = image.convert("RGBA")
        stats = measure(pose)

    scale = anchor["height"] / stats["height"]
    scaled = pose.resize(
        (max(1, round(pose.width * scale)), max(1, round(pose.height * scale))),
        Image.Resampling.LANCZOS,
    )
    moved = measure(scaled)
    # 세로는 접지선을 맞춘다 — `build_keypose_motion` 이 bbox 아래끝으로 접지시키므로
    # 발과 bbox 아래끝이 같은 줄에 있어야 다른 상태와 발 높이가 어긋나지 않는다.
    offset_y = anchor["feet_bottom"] - moved["feet_bottom"]
    # 가로는 **bbox 중앙**에 놓는다. 하류가 포즈를 bbox 로 잘라 셀 중앙에 넣기 때문에 캔버스
    # 안의 가로 위치는 하류에 전혀 전달되지 않고, 여기서 지켜야 하는 실제 계약은 좌우 안전
    # 여백뿐이다. 발 중심에 맞추면 지팡이를 옆으로 짚은 포즈처럼 좌우 비대칭인 자세가 캔버스
    # 밖으로 밀려 여백 계약을 깬다(실측: 왼쪽 여백 24 -> 15).
    scaled_bounds = _visible(scaled).getbbox()
    if scaled_bounds is None:
        raise KeyposeFitError("scaled pose has no visible pixels")
    pose_width = scaled_bounds[2] - scaled_bounds[0]
    offset_x = round((canvas[0] - pose_width) / 2) - scaled_bounds[0]

    fitted = Image.new("RGBA", canvas, (0, 0, 0, 0))
    fitted.alpha_composite(scaled, (offset_x, offset_y))
    check = measure(fitted)
    if abs(check["height"] - anchor["height"]) > 2 \
            or abs(check["feet_bottom"] - anchor["feet_bottom"]) > 2:
        raise KeyposeFitError(f"fit missed the anchor: got {check}, wanted {anchor}")
    fitted_bounds = _visible(fitted).getbbox()
    margin = min(fitted_bounds[0], canvas[0] - fitted_bounds[2])
    if margin < SAFE_MARGIN:
        raise KeyposeFitError(
            f"fitted pose leaves only {margin}px side margin (need {SAFE_MARGIN}) — "
            "the pose is too wide for this canvas at the anchor scale"
        )
    target.parent.mkdir(parents=True, exist_ok=True)
    fitted.save(target, optimize=True)
    typer.echo(
        f"fitted {source} -> {target}  scale={scale:.4f} "
        f"offset=({offset_x},{offset_y})  height {stats['height']} -> {check['height']}"
    )


if __name__ == "__main__":
    app()
