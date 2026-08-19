from PIL import Image, ImageFilter

ALPHA_THRESHOLD = 20


def remove_remote_fragments(pose: Image.Image) -> Image.Image:
    alpha_bytes = pose.getchannel("A").tobytes()
    width, height = pose.size
    visited = bytearray(width * height)
    components: list[list[tuple[int, int]]] = []
    for start_y in range(height):
        for start_x in range(width):
            start = start_y * width + start_x
            if visited[start] or alpha_bytes[start] < ALPHA_THRESHOLD:
                continue
            components.append(
                _collect_component(
                    alpha_bytes, width, height, visited, start_x, start_y
                )
            )
    if not components:
        return pose
    largest = max(components, key=len)
    body_left, body_top, body_right, body_bottom = _component_bounds(largest)
    proximity = max(width, height) * 0.12
    cleanup_box = (
        max(0, round(body_left - proximity)),
        max(0, round(body_top - proximity)),
        min(width, round(body_right + proximity)),
        min(height, round(body_bottom + proximity)),
    )
    cleaned = pose.copy()
    for y in range(height):
        for x in range(width):
            if not _box_contains(cleanup_box, x, y):
                cleaned.putpixel((x, y), (0, 0, 0, 0))
    for component in components:
        if component is largest or _boxes_intersect(
            _component_bounds(component), cleanup_box
        ):
            continue
        for x, y in component:
            cleaned.putpixel((x, y), (0, 0, 0, 0))
    bounds = cleaned.getchannel("A").getbbox()
    return cleaned.crop(bounds) if bounds is not None else cleaned


def remove_tiny_fragments(frame: Image.Image, minimum_pixels: int = 41) -> Image.Image:
    prepared = frame.copy()
    alpha = prepared.getchannel("A")
    prepared.putalpha(
        alpha.point(lambda value: value if value >= ALPHA_THRESHOLD else 0)
    )
    alpha_bytes = prepared.getchannel("A").tobytes()
    width, height = prepared.size
    visited = bytearray(width * height)
    cleaned = prepared.copy()
    for start_y in range(height):
        for start_x in range(width):
            start = start_y * width + start_x
            if visited[start] or alpha_bytes[start] < ALPHA_THRESHOLD:
                continue
            component = _collect_component(
                alpha_bytes, width, height, visited, start_x, start_y
            )
            if len(component) >= minimum_pixels:
                continue
            left, top, right, bottom = _component_bounds(component)
            cleaned.paste(
                (0, 0, 0, 0),
                (
                    max(0, left - 2),
                    max(0, top - 2),
                    min(width, right + 2),
                    min(height, bottom + 2),
                ),
            )
    alpha = cleaned.getchannel("A")
    opaque = alpha.point(lambda value: 255 if value >= ALPHA_THRESHOLD else 0)
    connected = opaque.filter(ImageFilter.MaxFilter(5))
    cleaned.putalpha(Image.composite(alpha, Image.new("L", frame.size), connected))
    return cleaned


def clear_right_residue(frame: Image.Image, cutoff: int = 160) -> Image.Image:
    cleaned = frame.copy()
    cleaned.paste((0, 0, 0, 0), (cutoff, 0, cleaned.width, cleaned.height))
    return cleaned


def remove_solid_fragments(
    frame: Image.Image, minimum_pixels: int = 20, threshold: int = 128
) -> Image.Image:
    alpha_bytes = frame.getchannel("A").tobytes()
    width, height = frame.size
    visited = bytearray(width * height)
    cleaned = frame.copy()
    for start_y in range(height):
        for start_x in range(width):
            start = start_y * width + start_x
            if visited[start] or alpha_bytes[start] < threshold:
                continue
            component = _collect_component(
                alpha_bytes, width, height, visited, start_x, start_y, threshold
            )
            if len(component) >= minimum_pixels:
                continue
            left, top, right, bottom = _component_bounds(component)
            cleaned.paste((0, 0, 0, 0), (left, top, right, bottom))
    return cleaned


def remove_tiny_fragments_in_box(
    frame: Image.Image,
    box: tuple[int, int, int, int],
    minimum_pixels: int = 20,
) -> Image.Image:
    alpha_bytes = frame.getchannel("A").tobytes()
    width, height = frame.size
    visited = bytearray(width * height)
    cleaned = frame.copy()
    for start_y in range(height):
        for start_x in range(width):
            start = start_y * width + start_x
            if visited[start] or alpha_bytes[start] < ALPHA_THRESHOLD:
                continue
            component = _collect_component(
                alpha_bytes, width, height, visited, start_x, start_y
            )
            bounds = _component_bounds(component)
            if len(component) >= minimum_pixels or not _boxes_intersect(bounds, box):
                continue
            for x, y in component:
                cleaned.putpixel((x, y), (0, 0, 0, 0))
    return cleaned


def _collect_component(
    alpha_bytes: bytes,
    width: int,
    height: int,
    visited: bytearray,
    start_x: int,
    start_y: int,
    threshold: int = ALPHA_THRESHOLD,
) -> list[tuple[int, int]]:
    pending = [(start_x, start_y)]
    visited[start_y * width + start_x] = 1
    component: list[tuple[int, int]] = []
    while pending:
        x, y = pending.pop()
        component.append((x, y))
        for neighbor_x, neighbor_y in (
            (x + 1, y),
            (x - 1, y),
            (x, y + 1),
            (x, y - 1),
        ):
            if not (0 <= neighbor_x < width and 0 <= neighbor_y < height):
                continue
            neighbor = neighbor_y * width + neighbor_x
            if visited[neighbor] or alpha_bytes[neighbor] < threshold:
                continue
            visited[neighbor] = 1
            pending.append((neighbor_x, neighbor_y))
    return component


def _component_bounds(
    component: list[tuple[int, int]],
) -> tuple[int, int, int, int]:
    return (
        min(x for x, _y in component),
        min(y for _x, y in component),
        max(x for x, _y in component) + 1,
        max(y for _x, y in component) + 1,
    )


def _box_contains(box: tuple[int, int, int, int], x: int, y: int) -> bool:
    left, top, right, bottom = box
    return left <= x < right and top <= y < bottom


def _boxes_intersect(
    first: tuple[int, int, int, int], second: tuple[int, int, int, int]
) -> bool:
    first_left, first_top, first_right, first_bottom = first
    second_left, second_top, second_right, second_bottom = second
    return (
        first_right > second_left
        and first_left < second_right
        and first_bottom > second_top
        and first_top < second_bottom
    )
