import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from recompose_motion_atlas import (
    FrameSample,
    SheetLayout,
    component_boxes,
    compose_sheet,
)


def test_component_boxes_when_three_figures_are_separated() -> None:
    # Given
    alpha = Image.new("L", (120, 60), 0)
    draw = ImageDraw.Draw(alpha)
    draw.rectangle((5, 10, 25, 50), fill=255)
    draw.rectangle((45, 8, 70, 50), fill=255)
    draw.rectangle((90, 12, 112, 50), fill=255)

    # When
    boxes = component_boxes(alpha, expected_frames=3)

    # Then
    assert boxes == ((5, 10, 26, 51), (45, 8, 71, 51), (90, 12, 113, 51))


def test_component_boxes_when_chroma_matte_leaves_a_faint_bridge() -> None:
    # Given
    alpha = Image.new("L", (120, 60), 0)
    draw = ImageDraw.Draw(alpha)
    draw.rectangle((5, 10, 25, 50), fill=255)
    draw.rectangle((45, 8, 70, 50), fill=255)
    draw.rectangle((90, 12, 112, 50), fill=255)
    draw.line((26, 30, 44, 30), fill=8)

    # When
    boxes = component_boxes(alpha, expected_frames=3)

    # Then
    assert boxes == ((5, 10, 26, 51), (45, 8, 71, 51), (90, 12, 113, 51))


def test_component_boxes_when_adjacent_figures_overlap_in_x_projection() -> None:
    # Given
    alpha = Image.new("L", (90, 60), 0)
    draw = ImageDraw.Draw(alpha)
    draw.rectangle((5, 8, 46, 29), fill=255)
    draw.rectangle((42, 31, 82, 53), fill=255)

    # When
    boxes = component_boxes(alpha, expected_frames=2)

    # Then
    assert len(boxes) == 2
    assert boxes[0][0] < boxes[0][2] <= boxes[1][0] < boxes[1][2]


def test_compose_sheet_when_frames_have_different_sizes(tmp_path: Path) -> None:
    # Given
    frames = []
    for width, height in ((50, 90), (70, 70), (45, 100), (60, 85)):
        frame = Image.new("RGBA", (width, height), (240, 180, 80, 255))
        frames.append(FrameSample(frame, source_bottom_gap=0))
    output = tmp_path / "sheet.png"

    # When
    compose_sheet(frames, output, SheetLayout(columns=4, rows=1, bottom_padding=16))

    # Then
    with Image.open(output) as sheet:
        assert sheet.mode == "RGBA"
        assert sheet.size == (768, 208)
        for index in range(4):
            alpha = sheet.getchannel("A").crop((index * 192, 0, (index + 1) * 192, 208))
            assert alpha.getbbox() is not None
            assert alpha.crop((0, 0, 192, 1)).getbbox() is None
            assert alpha.crop((0, 207, 192, 208)).getbbox() is None
            assert alpha.crop((0, 0, 1, 208)).getbbox() is None
            assert alpha.crop((191, 0, 192, 208)).getbbox() is None
            bounds = alpha.getbbox()
            assert bounds is not None
            assert bounds[3] == 192


def test_compose_sheet_when_vertical_motion_must_be_preserved(tmp_path: Path) -> None:
    # Given
    frame = Image.new("RGBA", (60, 80), (240, 180, 80, 255))
    frames = (
        FrameSample(frame, source_bottom_gap=0),
        FrameSample(frame, source_bottom_gap=20),
    )
    output = tmp_path / "airborne.png"

    # When
    compose_sheet(
        frames,
        output,
        SheetLayout(
            columns=2, rows=1, bottom_padding=16, preserve_vertical_motion=True
        ),
    )

    # Then
    with Image.open(output) as sheet:
        alpha = sheet.getchannel("A")
        grounded = alpha.crop((0, 0, 192, 208)).getbbox()
        airborne = alpha.crop((192, 0, 384, 208)).getbbox()
        assert grounded is not None
        assert airborne is not None
        assert grounded[3] - airborne[3] == 20
