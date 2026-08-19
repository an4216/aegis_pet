import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from fit_keypose import measure


def _pose(cane_bottom: int | None = None, scale: float = 1.0) -> Image.Image:
    """머리-몸통-두 발로 된 최소 포즈. cane_bottom을 주면 발보다 아래로 내려가는
    가는 지팡이를 왼쪽에 추가한다."""
    image = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    top = 40
    feet = 240
    height = (feet - top) * scale
    body_top = top
    body_bottom = top + height
    draw.ellipse((100, body_top, 160, body_top + height * 0.5), fill=(90, 180, 90, 255))
    draw.rectangle((110, body_top + height * 0.4, 150, body_bottom - 10), fill=(90, 180, 90, 255))
    # 발 두 개 — 합쳐서 FOOT_MIN_WIDTH(30px)보다 넓다
    draw.rectangle((105, body_bottom - 10, 125, body_bottom), fill=(70, 150, 70, 255))
    draw.rectangle((135, body_bottom - 10, 155, body_bottom), fill=(70, 150, 70, 255))
    if cane_bottom is not None:
        draw.rectangle((80, body_top + 30, 86, cane_bottom), fill=(140, 90, 40, 255))
    return image


def test_measure_ignores_a_thin_cane_below_the_feet() -> None:
    # 지팡이가 발보다 20px 아래까지 내려가도 접지선은 발이어야 한다.
    with_cane = _pose(cane_bottom=260 - 1)
    without_cane = _pose()

    a = measure(with_cane)
    b = measure(without_cane)

    assert a["feet_bottom"] == b["feet_bottom"]
    # bbox 아래끝은 지팡이 때문에 실제로 더 내려가 있다 — 그래서 이 구분이 필요하다.
    assert a["bottom"] > a["feet_bottom"]


def test_measure_height_spans_head_top_to_feet_not_bbox() -> None:
    pose = _pose(cane_bottom=255)

    stats = measure(pose)

    assert stats["height"] == stats["feet_bottom"] - stats["top"]
    assert stats["height"] < stats["bottom"] - stats["top"]


def test_measure_feet_center_is_between_the_two_feet() -> None:
    stats = measure(_pose())

    # 발은 105..125 과 135..155 → 중심은 130 근처. 지팡이가 있어도 흔들리면 안 된다.
    assert abs(stats["feet_center_x"] - 130) <= 3
    assert abs(measure(_pose(cane_bottom=250))["feet_center_x"] - 130) <= 3
