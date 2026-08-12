import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

from build_keypose_motion import (
    build_motion_sheets,
    extract_keyposes,
    load_keypose_directory,
)


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
    assert len(outputs) == 14
    with Image.open(tmp_path / "walk_8f_motion.png") as walk:
        assert walk.mode == "RGBA"
        assert walk.size == (768, 416)
    with Image.open(tmp_path / "play_6f_motion.png") as play:
        assert play.size == (1152, 208)
        alpha = play.getchannel("A")
        bottoms = []
        for index in range(6):
            cell = alpha.crop((index * 192, 0, (index + 1) * 192, 208))
            bounds = cell.getbbox()
            assert bounds is not None
            assert bounds[0] > 0 and bounds[1] > 0
            assert bounds[2] < 192 and bounds[3] < 208
            bottoms.append(bounds[3])
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
