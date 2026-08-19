import sys
from pathlib import Path
from typing import cast

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from import_walk_cycle import (
    anchor_torso_centers,
    extract_walk_frames,
    remove_detached_debris,
    renormalize_walk_sheet,
    render_walk_sheet,
    smooth_cycle_order,
)


def _visible_area(cell: Image.Image) -> int:
    return sum(1 for alpha in cell.getchannel("A").tobytes() if alpha >= 32)


def _cell(sheet: Image.Image, index: int) -> Image.Image:
    column = index % 4
    row = index // 4
    return sheet.crop((column * 192, row * 208, (column + 1) * 192, (row + 1) * 208))


def _walk_sheet_with_body(radius_x: int, radius_y: int) -> Image.Image:
    sheet = Image.new("RGBA", (768, 416), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for index in range(8):
        column = index % 4
        row = index // 4
        center_x = column * 192 + 96
        baseline = (row + 1) * 208 - 16
        draw.ellipse(
            (
                center_x - radius_x,
                baseline - radius_y * 2,
                center_x + radius_x,
                baseline,
            ),
            fill=(120, 80, 40, 255),
        )
    return sheet


def _idle_sheet_with_body(radius_x: int, radius_y: int) -> Image.Image:
    sheet = Image.new("RGBA", (192 * 6, 208), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for index in range(6):
        center_x = index * 192 + 96
        baseline = 208 - 16
        draw.ellipse(
            (
                center_x - radius_x,
                baseline - radius_y * 2,
                center_x + radius_x,
                baseline,
            ),
            fill=(120, 80, 40, 255),
        )
    return sheet


def test_renormalize_walk_sheet_matches_current_idle_body_area() -> None:
    # walk를 임포트한 뒤 idle 시트를 더 크게 재생성한 상황(2026-08-14 실제 회귀).
    walk = _walk_sheet_with_body(40, 50)
    idle = _idle_sheet_with_body(50, 62)

    renormalized = renormalize_walk_sheet(walk, idle)

    idle_area = _visible_area(_cell(idle.crop((0, 0, 192, 208)), 0))
    entry_area = _visible_area(_cell(renormalized, 0))
    assert abs(entry_area / idle_area - 1.0) <= 0.05


def test_renormalize_walk_sheet_keeps_foot_contact_and_cell_inset() -> None:
    walk = _walk_sheet_with_body(40, 50)
    idle = _idle_sheet_with_body(50, 62)
    before = [_cell(walk, index).getchannel("A").point(
        tuple(255 if a >= 32 else 0 for a in range(256))
    ).getbbox() for index in range(8)]

    renormalized = renormalize_walk_sheet(walk, idle)

    for index in range(8):
        cell = _cell(renormalized, index)
        bounds = cell.getchannel("A").getbbox()
        assert bounds is not None
        # 셀 경계에 닿지 않아야 런타임 알파 인셋 검사를 통과한다.
        assert bounds[0] > 0 and bounds[1] > 0
        assert bounds[2] < 192 and bounds[3] < 208
        # 발 접지선(보이는 아래끝)은 그대로여야 걷기 진입에서 발이 튀지 않는다.
        old = before[index]
        assert old is not None
        assert abs(bounds[3] - old[3]) <= 1


def test_extract_walk_frames_uses_top_then_bottom_order() -> None:
    sheet = Image.new("RGBA", (400, 200), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for index in range(8):
        column = index % 4
        row = index // 4
        draw.rectangle(
            (column * 100 + 10, row * 100 + 10, column * 100 + 40, row * 100 + 60),
            fill=(index + 1, 0, 0, 255),
        )

    frames = extract_walk_frames(sheet)

    colors = [
        cast(tuple[int, int, int, int], frame.getpixel((frame.width // 2, frame.height // 2)))
        for frame in frames
    ]
    assert [color[0] for color in colors] == list(range(1, 9))


def test_render_walk_sheet_creates_safe_runtime_cells() -> None:
    frames = tuple(
        Image.new("RGBA", (80 + index, 100 + index), (index + 1, 0, 0, 255))
        for index in range(8)
    )

    sheet = render_walk_sheet(frames)

    assert sheet.mode == "RGBA"
    assert sheet.size == (768, 416)
    for index in range(8):
        column = index % 4
        row = index // 4
        cell = sheet.crop(
            (column * 192, row * 208, (column + 1) * 192, (row + 1) * 208)
        )
        bounds = cell.getchannel("A").getbbox()
        assert bounds is not None
        assert bounds[0] > 0 and bounds[1] > 0
        assert bounds[2] < 192 and bounds[3] < 208
        color = cast(
            tuple[int, int, int, int], cell.getpixel((bounds[0], bounds[1]))
        )
        assert color[0] == index + 1


def test_render_walk_sheet_preserves_authored_gait_phase_order() -> None:
    positions = ((18, 42), (48, 18), (28, 48), (42, 12), (12, 28), (48, 42), (18, 18), (42, 48))
    authored: list[Image.Image] = []
    for index, position in enumerate(positions):
        frame = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw.ellipse((18, 6, 46, 42), fill=(index + 1, 0, 0, 255))
        draw.ellipse(
            (position[0], position[1], position[0] + 8, position[1] + 8),
            fill=(index + 1, 0, 0, 255),
        )
        authored.append(frame)

    sheet = render_walk_sheet(tuple(authored))

    rendered_order: list[int] = []
    for index in range(8):
        column = index % 4
        row = index // 4
        cell = sheet.crop(
            (column * 192, row * 208, (column + 1) * 192, (row + 1) * 208)
        )
        bounds = cell.getchannel("A").getbbox()
        assert bounds is not None
        color = cast(
            tuple[int, int, int, int],
            cell.getpixel(((bounds[0] + bounds[2]) // 2, (bounds[1] + bounds[3]) // 2)),
        )
        rendered_order.append(color[0])
    assert rendered_order == list(range(1, 9))


def test_render_walk_sheet_rejects_duplicate_frames() -> None:
    repeated = Image.new("RGBA", (80, 100), (120, 80, 40, 255))

    try:
        render_walk_sheet(tuple(repeated.copy() for _index in range(8)))
    except RuntimeError as error:
        assert str(error) == "walk cycle must contain eight distinct frames"
    else:
        raise AssertionError("duplicate walk frames were accepted")


def test_remove_detached_debris_preserves_character_and_removes_fragments() -> None:
    frame = Image.new("RGBA", (100, 100), (0, 0, 0, 0))
    draw = ImageDraw.Draw(frame)
    draw.rectangle((20, 20, 79, 79), fill=(200, 100, 50, 255))
    draw.rectangle((4, 50, 8, 54), fill=(200, 100, 50, 255))

    cleaned = remove_detached_debris(frame)

    body = cast(tuple[int, int, int, int], cleaned.getpixel((50, 50)))
    fragment = cast(tuple[int, int, int, int], cleaned.getpixel((6, 52)))
    assert body[3] == 255
    assert fragment[3] == 0


def test_render_walk_sheet_matches_idle_body_area_without_state_squash() -> None:
    frames = tuple(
        Image.new("RGBA", (90 + index, 120 + index * 2), (150, index, 0, 255))
        for index in range(8)
    )

    source_ratio = frames[0].width / frames[0].height
    sheet = render_walk_sheet(frames, target_visible_area=72 * 96)

    visible_areas: list[int] = []
    visible_heights: list[int] = []
    visible_ratios: list[float] = []
    for index in range(8):
        column = index % 4
        row = index // 4
        cell = sheet.crop(
            (column * 192, row * 208, (column + 1) * 192, (row + 1) * 208)
        )
        bounds = cell.getchannel("A").getbbox()
        assert bounds is not None
        width = bounds[2] - bounds[0]
        height = bounds[3] - bounds[1]
        visible_areas.append(width * height)
        visible_heights.append(height)
        visible_ratios.append(width / height)
    assert abs(visible_areas[0] / (72 * 96) - 1.0) <= 0.05
    assert abs(visible_ratios[0] / source_ratio - 1.0) <= 0.03
    assert max(visible_heights) - min(visible_heights) <= 12


def test_smooth_cycle_order_reduces_scrambled_transition_cost() -> None:
    ordered = []
    for index, position in enumerate(
        ((28, 8), (42, 14), (50, 28), (42, 42), (28, 50), (14, 42), (8, 28), (14, 14))
    ):
        frame = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        ImageDraw.Draw(frame).ellipse((22, 8, 42, 38), fill=(160, 100, 80, 255))
        ImageDraw.Draw(frame).ellipse(
            (position[0], position[1], position[0] + 8, position[1] + 8),
            fill=(index + 1, 0, 0, 255),
        )
        ordered.append(frame)
    scrambled = tuple(ordered[index] for index in (0, 4, 1, 5, 2, 6, 3, 7))

    smoothed = smooth_cycle_order(scrambled)

    centers = []
    for frame in smoothed:
        bounds = frame.getchannel("A").getbbox()
        assert bounds is not None
        centers.append(((bounds[0] + bounds[2]) // 2, (bounds[1] + bounds[3]) // 2))
    squared_steps = [
        (centers[(index + 1) % 8][0] - centers[index][0]) ** 2
        + (centers[(index + 1) % 8][1] - centers[index][1]) ** 2
        for index in range(8)
    ]
    assert max(squared_steps) <= 260


def test_anchor_torso_centers_removes_lateral_body_jitter() -> None:
    frames = []
    for shift in (0, 12, -8, 5, -4, 9, -6, 2):
        frame = Image.new("RGBA", (120, 150), (0, 0, 0, 0))
        draw = ImageDraw.Draw(frame)
        draw.ellipse((35 + shift, 12, 85 + shift, 105), fill=(120, 80, 40, 255))
        draw.ellipse((25, 105, 48, 140), fill=(120, 80, 40, 255))
        draw.ellipse((72, 105, 95, 140), fill=(120, 80, 40, 255))
        frames.append(frame)

    anchored = anchor_torso_centers(tuple(frames))

    torso_centers = []
    for frame in anchored:
        alpha = frame.getchannel("A")
        points = [
            x
            for y in range(12, 105)
            for x in range(frame.width)
            if cast(int, alpha.getpixel((x, y))) >= 32
        ]
        torso_centers.append(sum(points) / len(points))
    assert max(torso_centers) - min(torso_centers) <= 1.0
