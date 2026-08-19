# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13", "typer>=0.16,<1"]
# ///
# ─── How to run ───
# uv run tools/build_keypose_motion.py <design-sheet> <output-root>

import subprocess
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Final

import typer
from motion_alpha_cleanup import (
    clear_right_residue,
    remove_remote_fragments,
    remove_solid_fragments,
    remove_tiny_fragments,
    remove_tiny_fragments_in_box,
)
from PIL import Image

CELL_WIDTH: Final = 192
CELL_HEIGHT: Final = 208
BOTTOM_PADDING: Final = 16
CHROMA_HELPER: Final = (
    Path.home() / ".codex/skills/.system/imagegen/scripts/remove_chroma_key.py"
)


class MotionBuildError(RuntimeError):
    pass


KEYPOSE_NAMES: Final = (
    "idle",
    "walk1",
    "walk2",
    "sleep",
    "happy",
    "sulk",
    "sick",
    "eat",
)

EVOLVED2_FALL_WING_RESIDUE_BOXES: Final = (
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


@dataclass(frozen=True, slots=True)
class FrameTransform:
    pose: int
    scale_x: float = 1.0
    scale_y: float = 1.0
    rotation: float = 0.0
    lift: int = 0


@dataclass(frozen=True, slots=True)
class MotionSpec:
    name: str
    columns: int
    rows: int
    frames: tuple[FrameTransform, ...]


def _motion(name: str, columns: int, rows: int, encoded_frames: str) -> MotionSpec:
    frames: list[FrameTransform] = []
    for encoded in encoded_frames.split(";"):
        pose, scale_x, scale_y, rotation, lift = encoded.split(",")
        frames.append(
            FrameTransform(
                int(pose), float(scale_x), float(scale_y), float(rotation), int(lift)
            )
        )
    return MotionSpec(name, columns, rows, tuple(frames))


MOTIONS: Final = (
    _motion(
        "idle_6f_motion.png",
        6,
        1,
        "0,1,1,0,0;0,1.01,.99,0,0;0,1,1,0,0;0,.99,1.01,0,0;0,1,1,0,0;0,1.01,.99,0,0",
    ),
    _motion(
        "sleep_6f_motion.png",
        6,
        1,
        "3,1,1,0,0;3,1.01,.99,0,0;3,1.02,.98,0,0;3,1.01,.99,0,0;3,1,1,0,0;3,.99,1.01,0,0",
    ),
    _motion(
        "eat_6f_motion.png",
        6,
        1,
        "7,1,1,0,0;7,1.02,.98,0,0;7,.99,1.01,0,0;7,1.02,.98,0,0;7,1,1,0,0;7,.99,1.01,0,0",
    ),
    _motion(
        "sick_6f_motion.png",
        6,
        1,
        "6,1,1,-2,0;6,1,1,0,0;6,1,1,2,0;6,1,1,0,0;6,1,1,-2,0;6,1,1,0,0",
    ),
    _motion(
        "sulk_6f_motion.png",
        6,
        1,
        "5,1,1,0,0;5,1.01,.99,-1,0;5,1,1,0,0;5,1.01,.99,1,0;5,1,1,0,0;5,.99,1.01,0,0",
    ),
    _motion(
        "play_6f_motion.png",
        6,
        1,
        "4,1,1,0,0;4,.98,1.02,-3,20;4,1,1,0,40;4,.98,1.02,3,28;4,1.02,.98,0,10;4,1,1,0,0",
    ),
    _motion(
        "dragged_4f_motion.png", 4, 1, "6,1,1,-7,24;6,1,1,-2,30;6,1,1,4,22;6,1,1,7,28"
    ),
    _motion(
        "fall_4f_motion.png", 4, 1, "6,1,1,-8,24;6,1,1,-3,16;6,1,1,3,8;6,1.03,.97,7,0"
    ),
    _motion(
        "land_4f_motion.png",
        4,
        1,
        "0,1.08,.92,0,0;0,1.04,.96,0,0;0,.98,1.02,0,0;0,1,1,0,0",
    ),
    _motion(
        "file_hover_4f_motion.png",
        4,
        1,
        "4,1,1,-2,0;4,1.01,.99,0,0;4,1,1,2,0;4,.99,1.01,0,0",
    ),
    _motion(
        "file_consume_4f_motion.png",
        4,
        1,
        "7,1,1,0,0;7,1.04,.96,0,0;7,.97,1.03,0,0;7,1,1,0,0",
    ),
    _motion(
        "poop_6f_motion.png",
        6,
        1,
        "5,1,1,-1,0;5,1.04,.96,0,0;5,.98,1.02,1,0;5,1.04,.96,0,0;5,1,1,-1,0;5,.99,1.01,0,0",
    ),
    _motion(
        "pet_6f_motion.png",
        6,
        1,
        "4,1,1,0,0;4,1.02,.98,-2,0;4,.98,1.02,0,0;4,1.02,.98,2,0;4,1,1,0,0;4,.99,1.01,0,0",
    ),
)


def extract_keyposes(sheet: Image.Image) -> tuple[Image.Image, ...]:
    poses: list[Image.Image] = []
    for index in range(8):
        column = index % 4
        row = index // 4
        left = round(column * sheet.width / 4)
        right = round((column + 1) * sheet.width / 4)
        top = round(row * sheet.height / 2)
        bottom = round((row + 1) * sheet.height / 2)
        cell = sheet.crop((left, top, right, bottom))
        bounds = cell.getchannel("A").getbbox()
        if bounds is None:
            raise MotionBuildError(f"key pose {index} is empty")
        poses.append(cell.crop(bounds))
    return tuple(poses)


def load_keypose_directory(source_root: Path) -> tuple[Image.Image, ...]:
    poses: list[Image.Image] = []
    for name in KEYPOSE_NAMES:
        with Image.open(source_root / f"{name}.png") as source:
            pose = source.convert("RGBA")
        bounds = pose.getchannel("A").getbbox()
        if bounds is None:
            raise MotionBuildError(f"key pose {name} is empty")
        poses.append(remove_remote_fragments(pose.crop(bounds)))
    return tuple(poses)


def _render_frame(
    pose: Image.Image, transform: FrameTransform, common_scale: float
) -> Image.Image:
    width = max(1, round(pose.width * common_scale * transform.scale_x))
    height = max(1, round(pose.height * common_scale * transform.scale_y))
    frame = pose.resize((width, height), Image.Resampling.LANCZOS)
    if transform.rotation != 0:
        frame = frame.rotate(transform.rotation, Image.Resampling.BICUBIC, expand=True)
    return frame


def build_motion_sheets(
    poses: Sequence[Image.Image],
    output_root: Path,
    *,
    clear_dragged_right: bool = False,
    clean_fall_fragments: bool = False,
    clean_fall_wing_tip: bool = False,
) -> None:
    if len(poses) != 8:
        raise MotionBuildError("expected eight key poses")
    transformed_sizes = tuple(
        _render_frame(poses[transform.pose], transform, 1.0).size
        for motion in MOTIONS
        for transform in motion.frames
    )
    common_scale = min(
        (CELL_WIDTH - 24) / max(width for width, _height in transformed_sizes),
        (CELL_HEIGHT - 24) / max(height for _width, height in transformed_sizes),
        1.0,
    )
    output_root.mkdir(parents=True, exist_ok=True)
    for motion in MOTIONS:
        sheet = Image.new(
            "RGBA",
            (motion.columns * CELL_WIDTH, motion.rows * CELL_HEIGHT),
            (0, 0, 0, 0),
        )
        for index, transform in enumerate(motion.frames):
            frame = _render_frame(poses[transform.pose], transform, common_scale)
            if motion.name == "dragged_4f_motion.png" or (
                motion.name == "fall_4f_motion.png" and clean_fall_fragments
            ):
                frame = remove_tiny_fragments(frame)
                if clear_dragged_right:
                    frame = clear_right_residue(frame)
            cell_x = index % motion.columns
            cell_y = index // motion.columns
            x = cell_x * CELL_WIDTH + (CELL_WIDTH - frame.width) // 2
            y = (
                (cell_y + 1) * CELL_HEIGHT
                - BOTTOM_PADDING
                - transform.lift
                - frame.height
            )
            sheet.alpha_composite(frame, (x, y))
        if motion.name == "dragged_4f_motion.png" and clear_dragged_right:
            for index in range(len(motion.frames)):
                left = index * CELL_WIDTH
                box = (left, 0, left + CELL_WIDTH, CELL_HEIGHT)
                frame = clear_right_residue(sheet.crop(box))
                frame = remove_solid_fragments(remove_tiny_fragments(frame))
                sheet.paste(remove_tiny_fragments(frame), box)
        if motion.name == "fall_4f_motion.png" and clean_fall_wing_tip:
            for index in range(len(motion.frames)):
                left = index * CELL_WIDTH
                box = (left, 0, left + CELL_WIDTH, CELL_HEIGHT)
                frame = sheet.crop(box)
                frame = remove_tiny_fragments_in_box(frame, (150, 72, 170, 122))
                for residue_box in EVOLVED2_FALL_WING_RESIDUE_BOXES[index]:
                    frame.paste((0, 0, 0, 0), residue_box)
                sheet.paste(frame, box)
        sheet.save(output_root / motion.name, optimize=True)


def remove_background(source: Path, output: Path) -> None:
    _ = subprocess.run(
        (
            sys.executable,
            str(CHROMA_HELPER),
            "--input",
            str(source),
            "--out",
            str(output),
            "--auto-key",
            "border",
            "--soft-matte",
            "--transparent-threshold",
            "12",
            "--opaque-threshold",
            "220",
            "--despill",
        ),
        check=True,
    )


def main(source: Path, output_root: Path) -> None:
    if source.is_dir():
        build_motion_sheets(
            load_keypose_directory(source.resolve()),
            output_root.resolve(),
            clear_dragged_right=source.resolve().name == "bulgeumjo_evolved2",
            clean_fall_fragments=source.resolve().name == "bulgeumjo_evolved",
            clean_fall_wing_tip=source.resolve().name == "bulgeumjo_evolved2",
        )
        typer.echo(f"saved 13 non-walk motion sheets to {output_root.resolve()}")
        return
    with TemporaryDirectory(prefix="keypose-motion-") as temporary:
        alpha_path = Path(temporary) / "alpha.png"
        remove_background(source.resolve(), alpha_path)
        with Image.open(alpha_path) as source_image:
            poses = extract_keyposes(source_image.convert("RGBA"))
        build_motion_sheets(poses, output_root.resolve())
    typer.echo(f"saved 13 non-walk motion sheets to {output_root.resolve()}")


if __name__ == "__main__":
    typer.run(main)
