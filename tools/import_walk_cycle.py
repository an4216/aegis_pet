# /// script
# requires-python = ">=3.11"
# dependencies = ["pillow>=11,<13", "typer>=0.16,<1"]
# ///
# ─── How to run ───
# uv run tools/import_walk_cycle.py <generated-atlas> <output-png>

import hashlib
import subprocess
import sys
from collections import deque
from collections.abc import Sequence
from itertools import permutations
from math import sqrt
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Final

import typer
from PIL import Image

CELL_WIDTH: Final = 192
CELL_HEIGHT: Final = 208
BOTTOM_PADDING: Final = 16
MAX_WIDTH: Final = 184
MAX_HEIGHT: Final = 184
VISIBLE_ALPHA: Final = 32
VISIBLE_ALPHA_LUT: Final = tuple(
    255 if alpha >= VISIBLE_ALPHA else 0 for alpha in range(256)
)
CHROMA_HELPER: Final = (
    Path.home() / ".codex/skills/.system/imagegen/scripts/remove_chroma_key.py"
)


class WalkCycleError(RuntimeError):
    pass


def extract_walk_frames(sheet: Image.Image) -> tuple[Image.Image, ...]:
    frames: list[Image.Image] = []
    for index in range(8):
        column = index % 4
        row = index // 4
        left = round(column * sheet.width / 4)
        right = round((column + 1) * sheet.width / 4)
        top = round(row * sheet.height / 2)
        bottom = round((row + 1) * sheet.height / 2)
        cell = sheet.crop((left, top, right, bottom))
        bounds = cell.getchannel("A").point(VISIBLE_ALPHA_LUT).getbbox()
        if bounds is None:
            raise WalkCycleError(f"walk frame {index} is empty")
        expanded = (
            max(0, bounds[0] - 2),
            max(0, bounds[1] - 2),
            min(cell.width, bounds[2] + 2),
            min(cell.height, bounds[3] + 2),
        )
        frames.append(cell.crop(expanded))
    return tuple(frames)


def _frame_digest(frame: Image.Image) -> bytes:
    normalized = frame.resize((64, 64), Image.Resampling.LANCZOS)
    return hashlib.sha256(normalized.tobytes()).digest()


def _visible_height(frame: Image.Image) -> int:
    visible = frame.getchannel("A").point(VISIBLE_ALPHA_LUT)
    bounds = visible.getbbox()
    if bounds is None:
        raise WalkCycleError("walk frame has no visible pixels")
    return bounds[3] - bounds[1]


def _visible_width(frame: Image.Image) -> int:
    visible = frame.getchannel("A").point(VISIBLE_ALPHA_LUT)
    bounds = visible.getbbox()
    if bounds is None:
        raise WalkCycleError("walk frame has no visible pixels")
    return bounds[2] - bounds[0]


def _visible_pixels(frame: Image.Image) -> int:
    visible = frame.getchannel("A").point(VISIBLE_ALPHA_LUT)
    return sum(1 for alpha in visible.tobytes() if alpha)


def _normalized_silhouette(frame: Image.Image) -> Image.Image:
    alpha = frame.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise WalkCycleError("walk frame has no alpha pixels")
    cropped = alpha.crop(bounds)
    cropped.thumbnail((56, 56), Image.Resampling.LANCZOS)
    normalized = Image.new("L", (64, 64))
    normalized.paste(cropped, ((64 - cropped.width) // 2, 60 - cropped.height))
    return normalized


def _transition_cost(first: Image.Image, second: Image.Image) -> int:
    first_bytes = first.tobytes()
    second_bytes = second.tobytes()
    return sum(abs(left - right) for left, right in zip(first_bytes, second_bytes))


def smooth_cycle_order(frames: Sequence[Image.Image]) -> tuple[Image.Image, ...]:
    if len(frames) != 8:
        raise WalkCycleError("expected eight walk frames")
    silhouettes = tuple(_normalized_silhouette(frame) for frame in frames)
    costs = tuple(
        tuple(_transition_cost(first, second) for second in silhouettes)
        for first in silhouettes
    )
    best_order: tuple[int, ...] | None = None
    best_cost: int | None = None
    for tail in permutations(range(1, 8)):
        order = (0, *tail)
        cost = sum(costs[order[index]][order[(index + 1) % 8]] for index in range(8))
        if best_cost is None or cost < best_cost:
            best_cost = cost
            best_order = order
    if best_order is None:
        raise WalkCycleError("walk frame ordering failed")
    return tuple(frames[index] for index in best_order)


def _torso_center(frame: Image.Image) -> float:
    alpha = frame.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise WalkCycleError("walk frame has no alpha pixels")
    torso_bottom = bounds[1] + round((bounds[3] - bounds[1]) * 0.7)
    alpha_bytes = alpha.tobytes()
    xs = [
        x
        for y in range(bounds[1], torso_bottom)
        for x in range(frame.width)
        if alpha_bytes[y * frame.width + x] >= VISIBLE_ALPHA
    ]
    if not xs:
        raise WalkCycleError("walk frame has no visible torso pixels")
    return sum(xs) / len(xs)


def anchor_torso_centers(frames: Sequence[Image.Image]) -> tuple[Image.Image, ...]:
    centers = tuple(_torso_center(frame) for frame in frames)
    padding = max(round(abs(center - sum(centers) / len(centers))) for center in centers)
    canvas_width = max(frame.width for frame in frames) + padding * 2
    target = canvas_width // 2
    anchored: list[Image.Image] = []
    for frame, center in zip(frames, centers):
        canvas = Image.new("RGBA", (canvas_width, frame.height))
        canvas.alpha_composite(frame, (target - round(center), 0))
        anchored.append(canvas)
    return tuple(anchored)


def remove_detached_debris(frame: Image.Image, minimum_pixels: int = 250) -> Image.Image:
    alpha = frame.getchannel("A")
    alpha_bytes = alpha.tobytes()
    visited: set[tuple[int, int]] = set()
    debris: list[tuple[int, int]] = []
    for y in range(frame.height):
        for x in range(frame.width):
            if (x, y) in visited or alpha.getpixel((x, y)) == 0:
                continue
            component: list[tuple[int, int]] = []
            pending = deque([(x, y)])
            visited.add((x, y))
            while pending:
                current_x, current_y = pending.popleft()
                component.append((current_x, current_y))
                for neighbor_x, neighbor_y in (
                    (current_x - 1, current_y),
                    (current_x + 1, current_y),
                    (current_x, current_y - 1),
                    (current_x, current_y + 1),
                ):
                    neighbor = (neighbor_x, neighbor_y)
                    if (
                        0 <= neighbor_x < frame.width
                        and 0 <= neighbor_y < frame.height
                        and neighbor not in visited
                        and alpha_bytes[neighbor_y * frame.width + neighbor_x] > 0
                    ):
                        visited.add(neighbor)
                        pending.append(neighbor)
            if len(component) < minimum_pixels:
                debris.extend(component)
    cleaned = frame.copy()
    for x, y in debris:
        cleaned.putpixel((x, y), (0, 0, 0, 0))
    return cleaned


def render_walk_sheet(
    frames: Sequence[Image.Image], target_visible_area: int | None = None
) -> Image.Image:
    if len(frames) != 8:
        raise WalkCycleError("expected eight walk frames")
    if len({_frame_digest(frame) for frame in frames}) != 8:
        raise WalkCycleError("walk cycle must contain eight distinct frames")
    ordered_frames = anchor_torso_centers(frames)
    common_scale = min(
        MAX_WIDTH / max(_visible_width(frame) for frame in ordered_frames),
        MAX_HEIGHT / max(_visible_height(frame) for frame in ordered_frames),
        1.0,
    )
    if target_visible_area is not None:
        common_scale = min(
            sqrt(target_visible_area / _visible_pixels(ordered_frames[0])),
            MAX_WIDTH / max(_visible_width(frame) for frame in ordered_frames),
            MAX_HEIGHT / max(_visible_height(frame) for frame in ordered_frames),
        )
    sheet = Image.new("RGBA", (CELL_WIDTH * 4, CELL_HEIGHT * 2), (0, 0, 0, 0))
    for index, frame in enumerate(ordered_frames):
        width = max(1, round(frame.width * common_scale))
        height = max(1, round(frame.height * common_scale))
        rendered = remove_detached_debris(
            frame.resize((width, height), Image.Resampling.LANCZOS)
        )
        column = index % 4
        row = index // 4
        x = column * CELL_WIDTH + (CELL_WIDTH - width) // 2
        y = (row + 1) * CELL_HEIGHT - BOTTOM_PADDING - height
        sheet.alpha_composite(rendered, (x, y))
    return sheet


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


def import_walk_cycle(source: Path, output: Path) -> None:
    with TemporaryDirectory(prefix="walk-cycle-") as temporary:
        alpha_path = Path(temporary) / "alpha.png"
        remove_background(source.resolve(), alpha_path)
        with Image.open(alpha_path) as source_image:
            frames = extract_walk_frames(source_image.convert("RGBA"))
        idle_path = output.parent / "idle_6f_motion.png"
        target_visible_area: int | None = None
        if idle_path.exists():
            with Image.open(idle_path) as idle_sheet:
                idle_frame = idle_sheet.convert("RGBA").crop(
                    (0, 0, CELL_WIDTH, CELL_HEIGHT)
                )
                target_visible_area = _visible_pixels(idle_frame)
        sheet = render_walk_sheet(frames, target_visible_area)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, optimize=True)


def main(source: Path, output: Path) -> None:
    import_walk_cycle(source, output.resolve())
    typer.echo(f"saved true 8-frame walk cycle to {output.resolve()}")


if __name__ == "__main__":
    typer.run(main)
