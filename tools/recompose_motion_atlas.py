# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13", "typer>=0.16,<1"]
# ///
# ─── How to run ───
# uv run tools/recompose_motion_atlas.py <source-root> <output-root>

import subprocess
import sys
from collections.abc import Sequence
from dataclasses import dataclass
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Final

import typer
from PIL import Image

CELL_WIDTH: Final = 192
CELL_HEIGHT: Final = 208
SIDE_MARGIN: Final = 12
TOP_MARGIN: Final = 8
CHROMA_HELPER: Final = (
    Path.home() / ".codex/skills/.system/imagegen/scripts/remove_chroma_key.py"
)
ALPHA_OCCUPANCY_TABLE: Final = (0,) * 32 + (255,) * 224


@dataclass(frozen=True, slots=True)
class SheetLayout:
    columns: int
    rows: int
    bottom_padding: int
    preserve_vertical_motion: bool = False


@dataclass(frozen=True, slots=True)
class FrameSample:
    image: Image.Image
    source_bottom_gap: int


@dataclass(frozen=True, slots=True)
class StateSpec:
    source_name: str
    output_name: str
    frames: int
    layout: SheetLayout


STATE_SPECS: Final = (
    StateSpec("idle.png", "idle_6f_remake.png", 6, SheetLayout(6, 1, 16)),
    StateSpec("walk.png", "walk_8f_remake.png", 8, SheetLayout(4, 2, 16)),
    StateSpec("sleep.png", "sleep_6f_remake.png", 6, SheetLayout(6, 1, 16)),
    StateSpec("eat.png", "eat_6f_remake.png", 6, SheetLayout(6, 1, 16)),
    StateSpec("sick.png", "sick_6f_remake.png", 6, SheetLayout(6, 1, 16)),
    StateSpec("sulk.png", "sulk_6f_remake.png", 6, SheetLayout(6, 1, 16)),
    StateSpec("play.png", "play_6f_remake.png", 6, SheetLayout(6, 1, 16, True)),
    StateSpec("dragged.png", "dragged_4f_remake.png", 4, SheetLayout(4, 1, 16, True)),
    StateSpec("fall.png", "fall_4f_remake.png", 4, SheetLayout(4, 1, 16, True)),
    StateSpec("land.png", "land_4f_remake.png", 4, SheetLayout(4, 1, 16)),
    StateSpec("file_hover.png", "file_hover_4f_remake.png", 4, SheetLayout(4, 1, 16)),
    StateSpec(
        "file_consume.png", "file_consume_4f_remake.png", 4, SheetLayout(4, 1, 16)
    ),
    StateSpec("poop.png", "poop_6f_remake.png", 6, SheetLayout(6, 1, 16)),
    StateSpec("pet.png", "pet_6f_remake.png", 6, SheetLayout(6, 1, 16)),
)


def component_boxes(
    alpha: Image.Image, expected_frames: int
) -> tuple[tuple[int, int, int, int], ...]:
    solid_alpha = alpha.point(ALPHA_OCCUPANCY_TABLE)
    occupied = [
        solid_alpha.crop((x, 0, x + 1, solid_alpha.height)).getbbox() is not None
        for x in range(solid_alpha.width)
    ]
    runs: list[tuple[int, int]] = []
    start: int | None = None
    for x, has_alpha in enumerate((*occupied, False)):
        if has_alpha and start is None:
            start = x
        elif not has_alpha and start is not None:
            runs.append((start, x))
            start = None
    if len(runs) != expected_frames:
        counts = [
            solid_alpha.crop((x, 0, x + 1, solid_alpha.height)).histogram()[255]
            for x in range(solid_alpha.width)
        ]
        radius = max(1, solid_alpha.width // (expected_frames * 6))
        boundaries = [0]
        for index in range(1, expected_frames):
            target = round(index * solid_alpha.width / expected_frames)
            left = max(boundaries[-1] + 1, target - radius)
            right = min(solid_alpha.width - 1, target + radius)
            boundary = min(
                range(left, right + 1), key=lambda x: (counts[x], abs(x - target))
            )
            boundaries.append(boundary)
        boundaries.append(solid_alpha.width)
        runs = [
            (boundaries[index], boundaries[index + 1])
            for index in range(expected_frames)
        ]
    boxes: list[tuple[int, int, int, int]] = []
    for left, right in runs:
        vertical = solid_alpha.crop((left, 0, right, solid_alpha.height)).getbbox()
        if vertical is None:
            raise RuntimeError("alpha run unexpectedly empty")
        boxes.append((left, vertical[1], right, vertical[3]))
    return tuple(boxes)


def compose_sheet(
    frames: Sequence[FrameSample], output: Path, layout: SheetLayout
) -> None:
    if len(frames) != layout.columns * layout.rows:
        raise RuntimeError("frame count does not match sheet layout")
    max_width = max(frame.image.width for frame in frames)
    max_height = max(frame.image.height for frame in frames)
    minimum_gap = min(frame.source_bottom_gap for frame in frames)
    maximum_motion_gap = max(frame.source_bottom_gap - minimum_gap for frame in frames)
    scale = min(
        (CELL_WIDTH - SIDE_MARGIN * 2) / max_width,
        (CELL_HEIGHT - TOP_MARGIN - layout.bottom_padding)
        / (max_height + (maximum_motion_gap if layout.preserve_vertical_motion else 0)),
        1.0,
    )
    sheet = Image.new(
        "RGBA",
        (layout.columns * CELL_WIDTH, layout.rows * CELL_HEIGHT),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        width = max(1, round(frame.image.width * scale))
        height = max(1, round(frame.image.height * scale))
        resized = frame.image.resize((width, height), Image.Resampling.LANCZOS)
        motion_gap = 0
        if layout.preserve_vertical_motion:
            motion_gap = round((frame.source_bottom_gap - minimum_gap) * scale)
        cell_x = index % layout.columns
        cell_y = index // layout.columns
        x = cell_x * CELL_WIDTH + (CELL_WIDTH - width) // 2
        y = (cell_y + 1) * CELL_HEIGHT - layout.bottom_padding - motion_gap - height
        sheet.alpha_composite(resized, (x, y))
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, optimize=True)


def extract_frames(atlas: Image.Image, expected_frames: int) -> tuple[FrameSample, ...]:
    alpha = atlas.getchannel("A")
    boxes = component_boxes(alpha, expected_frames)
    return tuple(
        FrameSample(atlas.crop(box), source_bottom_gap=atlas.height - box[3])
        for box in boxes
    )


def remove_chroma(source: Path, output: Path) -> None:
    command = (
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
    )
    _ = subprocess.run(command, check=True)


def recompose_collection(source_root: Path, output_root: Path) -> None:
    with TemporaryDirectory(prefix="motion-atlas-") as temporary:
        temporary_root = Path(temporary)
        for spec in STATE_SPECS:
            alpha_path = temporary_root / spec.source_name
            remove_chroma(source_root / spec.source_name, alpha_path)
            with Image.open(alpha_path) as source:
                frames = extract_frames(source.convert("RGBA"), spec.frames)
            compose_sheet(frames, output_root / spec.output_name, spec.layout)
            typer.echo(f"saved {output_root / spec.output_name}")


def main(source_root: Path, output_root: Path) -> None:
    recompose_collection(source_root.resolve(), output_root.resolve())


if __name__ == "__main__":
    typer.run(main)
