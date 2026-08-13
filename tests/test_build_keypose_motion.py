import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from build_keypose_motion import (
    build_motion_sheets,
    extract_keyposes,
    load_keypose_directory,
)

PROJECT_ROOT = Path(__file__).resolve().parents[1]


def _alpha_component_sizes(alpha: Image.Image, threshold: int = 20) -> list[int]:
    pixels = alpha.load()
    width, height = alpha.size
    visited: set[tuple[int, int]] = set()
    sizes: list[int] = []
    for start_y in range(height):
        for start_x in range(width):
            if (start_x, start_y) in visited or pixels[start_x, start_y] < threshold:
                continue
            pending = [(start_x, start_y)]
            visited.add((start_x, start_y))
            size = 0
            while pending:
                x, y = pending.pop()
                size += 1
                for neighbor in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    neighbor_x, neighbor_y = neighbor
                    if (
                        0 <= neighbor_x < width
                        and 0 <= neighbor_y < height
                        and neighbor not in visited
                        and pixels[neighbor_x, neighbor_y] >= threshold
                    ):
                        visited.add(neighbor)
                        pending.append(neighbor)
            sizes.append(size)
    return sizes


def test_extract_keyposes_from_four_by_two_grid() -> None:
    sheet = Image.new("RGBA", (400, 200), (0, 0, 0, 0))
    draw = ImageDraw.Draw(sheet)
    for index in range(8):
        column = index % 4
        row = index // 4
        left = column * 100 + 20
        top = row * 100 + 10
        draw.rectangle((left, top, left + 49, top + 69), fill=(220, 140, 80, 255))

    poses = extract_keyposes(sheet)

    assert len(poses) == 8
    assert all(pose.size == (50, 70) for pose in poses)


def test_build_motion_sheets_have_safe_cells_and_airborne_motion(
    tmp_path: Path,
) -> None:
    poses = tuple(
        Image.new("RGBA", (60 + index, 80 + index), (220, 140, 80, 255))
        for index in range(8)
    )

    build_motion_sheets(poses, tmp_path)

    outputs = sorted(tmp_path.glob("*_motion.png"))
    assert len(outputs) == 13
    assert not (tmp_path / "walk_8f_motion.png").exists()
    with Image.open(tmp_path / "play_6f_motion.png") as play:
        assert play.size == (1152, 208)
        alpha = play.getchannel("A")
        bottoms: list[int] = []
        for index in range(6):
            cell = alpha.crop((index * 192, 0, (index + 1) * 192, 208))
            bounds = cell.getbbox()
            assert bounds is not None
            assert bounds[0] > 0 and bounds[1] > 0
            assert bounds[2] < 192 and bounds[3] < 208
            bottoms.append(round(bounds[3]))
        assert max(bottoms) - min(bottoms) >= 24


def test_build_motion_sheets_do_not_upscale_small_keyposes(tmp_path: Path) -> None:
    poses = tuple(
        Image.new("RGBA", (40, 50), (220, 140, 80, 255)) for _index in range(8)
    )

    build_motion_sheets(poses, tmp_path)

    with Image.open(tmp_path / "idle_6f_motion.png") as idle:
        bounds = idle.getchannel("A").crop((0, 0, 192, 208)).getbbox()
        assert bounds is not None
        assert bounds[2] - bounds[0] <= 40
        assert bounds[3] - bounds[1] <= 50


def test_load_keypose_directory_uses_runtime_pose_order(tmp_path: Path) -> None:
    names = ("idle", "walk1", "walk2", "sleep", "happy", "sulk", "sick", "eat")
    for index, name in enumerate(names):
        Image.new("RGBA", (20 + index, 30), (index, 0, 0, 255)).save(
            tmp_path / f"{name}.png"
        )

    poses = load_keypose_directory(tmp_path)

    assert [pose.width for pose in poses] == list(range(20, 28))


def test_load_keypose_directory_removes_remote_sheet_fragments(tmp_path: Path) -> None:
    names = ("idle", "walk1", "walk2", "sleep", "happy", "sulk", "sick", "eat")
    for name in names:
        pose = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
        draw = ImageDraw.Draw(pose)
        draw.ellipse((42, 20, 110, 116), fill=(220, 140, 80, 255))
        draw.rectangle((2, 60, 6, 68), fill=(220, 140, 80, 255))
        draw.rectangle((10, 72, 14, 76), fill=(220, 140, 80, 8))
        pose.save(tmp_path / f"{name}.png")

    poses = load_keypose_directory(tmp_path)

    assert all(
        pose.getchannel("A").getbbox() == (0, 0, pose.width, pose.height)
        for pose in poses
    )
    assert all(pose.width < 90 for pose in poses)


def test_fall_motion_keeps_large_keypose_inside_cell(tmp_path: Path) -> None:
    poses = tuple(
        Image.new("RGBA", (160, 144), (220, 140, 80, 255)) for _index in range(8)
    )

    build_motion_sheets(poses, tmp_path)

    with Image.open(tmp_path / "fall_4f_motion.png") as fall:
        alpha = fall.getchannel("A")
        for index in range(4):
            bounds = alpha.crop((index * 192, 0, (index + 1) * 192, 208)).getbbox()
            assert bounds is not None
            assert bounds[0] > 0 and bounds[1] > 0
            assert bounds[2] < 192 and bounds[3] < 208


def test_build_motion_sheets_keep_wide_props_inside_every_cell(tmp_path: Path) -> None:
    poses = tuple(
        Image.new("RGBA", (188, 110), (220, 140, 80, 255)) for _index in range(8)
    )

    build_motion_sheets(poses, tmp_path)

    for output in tmp_path.glob("*_motion.png"):
        with Image.open(output) as sheet:
            columns = sheet.width // 192
            rows = sheet.height // 208
            alpha = sheet.getchannel("A")
            for row in range(rows):
                for column in range(columns):
                    cell = alpha.crop(
                        (column * 192, row * 208, (column + 1) * 192, (row + 1) * 208)
                    )
                    bounds = cell.getbbox()
                    assert bounds is not None
                    assert bounds[0] > 0 and bounds[1] > 0
                    assert bounds[2] < 192 and bounds[3] < 208


def test_geobujang_evolved2_eat_keeps_complete_cane_hook() -> None:
    static_path = PROJECT_ROOT / "assets/sprites/chars/geobujang_evolved2/eat.png"
    with Image.open(static_path) as static_pose:
        alpha = static_pose.getchannel("A")
        hook = alpha.crop((28, 45, 62, 110))
        assert hook.getbbox() is not None
        assert alpha.getbbox()[0] >= 24


def test_geobujang_evolved2_eat_has_only_one_cane_hook() -> None:
    static_path = PROJECT_ROOT / "assets/sprites/chars/geobujang_evolved2/eat.png"
    with Image.open(static_path) as static_pose:
        duplicate_hook = static_pose.getchannel("A").crop((17, 73, 28, 121))
        assert duplicate_hook.getbbox() is None

    sheet_path = (
        PROJECT_ROOT / "assets/sprites/chars/geobujang_evolved2/eat_6f_motion.png"
    )
    with Image.open(sheet_path) as sheet:
        alpha = sheet.getchannel("A")
        for frame_index in range(6):
            frame = alpha.crop((frame_index * 192, 0, (frame_index + 1) * 192, 208))
            bounds = frame.getbbox()
            assert bounds is not None
            left_hook = frame.crop((0, 0, 32, bounds[1] + 92))
            assert left_hook.getbbox() is not None


def test_bulgeumjo_dragged_has_no_tiny_detached_sprite_residue() -> None:
    for suffix in ("", "_evolved", "_evolved2"):
        sheet_path = (
            PROJECT_ROOT
            / f"assets/sprites/chars/bulgeumjo{suffix}/dragged_4f_motion.png"
        )
        with Image.open(sheet_path) as sheet:
            alpha = sheet.getchannel("A")
            for frame_index in range(4):
                frame = alpha.crop((frame_index * 192, 0, (frame_index + 1) * 192, 208))
                component_sizes = _alpha_component_sizes(frame)
                assert all(size >= 40 for size in component_sizes)


def test_bulgeumjo_evolved2_dragged_has_no_far_right_wing_residue() -> None:
    sheet_path = (
        PROJECT_ROOT / "assets/sprites/chars/bulgeumjo_evolved2/dragged_4f_motion.png"
    )
    with Image.open(sheet_path) as sheet:
        alpha = sheet.getchannel("A")
        for frame_index in range(4):
            frame = alpha.crop((frame_index * 192, 0, (frame_index + 1) * 192, 208))
            far_right = frame.crop((160, 0, 192, 208))
            assert far_right.getbbox() is None


def test_bulgeumjo_evolved2_dragged_has_no_detached_solid_residue() -> None:
    sheet_path = (
        PROJECT_ROOT / "assets/sprites/chars/bulgeumjo_evolved2/dragged_4f_motion.png"
    )
    with Image.open(sheet_path) as sheet:
        alpha = sheet.getchannel("A")
        for frame_index in range(4):
            frame = alpha.crop((frame_index * 192, 0, (frame_index + 1) * 192, 208))
            component_sizes = _alpha_component_sizes(frame, threshold=128)
            assert all(size >= 20 for size in component_sizes)


def test_bulgeumjo_evolved_fall_has_no_tiny_detached_residue() -> None:
    sheet_path = (
        PROJECT_ROOT / "assets/sprites/chars/bulgeumjo_evolved/fall_4f_motion.png"
    )
    with Image.open(sheet_path) as sheet:
        alpha = sheet.getchannel("A")
        for frame_index in range(4):
            frame = alpha.crop((frame_index * 192, 0, (frame_index + 1) * 192, 208))
            component_sizes = _alpha_component_sizes(frame)
            assert all(size >= 20 for size in component_sizes)


def test_bulgeumjo_evolved2_fall_has_no_wing_tip_highlight_residue() -> None:
    sheet_path = (
        PROJECT_ROOT / "assets/sprites/chars/bulgeumjo_evolved2/fall_4f_motion.png"
    )
    with Image.open(sheet_path) as sheet:
        alpha = sheet.getchannel("A")
        residue_boxes = (
            (
                (28, 70, 42, 84),
                (31, 86, 38, 100),
                (39, 106, 46, 116),
                (39, 126, 58, 158),
                (158, 78, 162, 84),
                (155, 104, 159, 109),
            ),
            (
                (33, 76, 39, 87),
                (31, 91, 39, 100),
                (33, 105, 40, 119),
                (42, 123, 50, 134),
                (157, 75, 161, 90),
                (157, 112, 162, 127),
            ),
            (
                (32, 78, 36, 89),
                (32, 106, 39, 115),
                (35, 119, 43, 132),
                (43, 135, 56, 164),
                (156, 73, 163, 96),
                (158, 110, 164, 130),
            ),
            (
                (29, 88, 38, 114),
                (29, 117, 36, 125),
                (35, 129, 44, 141),
                (40, 145, 57, 171),
                (156, 79, 164, 98),
                (157, 107, 168, 131),
            ),
        )
        for frame_index, boxes in enumerate(residue_boxes):
            frame = alpha.crop((frame_index * 192, 0, (frame_index + 1) * 192, 208))
            for box in boxes:
                assert frame.crop(box).getbbox() is None


def test_reported_motion_textures_use_lossless_alpha_safe_imports() -> None:
    import_paths = (
        PROJECT_ROOT
        / "assets/sprites/chars/bulgeumjo_evolved/fall_4f_motion.png.import",
        PROJECT_ROOT
        / "assets/sprites/chars/bulgeumjo_evolved2/fall_4f_motion.png.import",
        PROJECT_ROOT
        / "assets/sprites/chars/geobujang_evolved2/eat_6f_motion.png.import",
    )
    for import_path in import_paths:
        config = import_path.read_text(encoding="utf-8")
        assert "compress/mode=3" in config
        assert "mipmaps/generate=false" in config
        assert "process/fix_alpha_border=false" in config
