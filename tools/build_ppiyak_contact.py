from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "docs/02-design/characters/ppiyak-remake-14state-contact.png"
TIERS = ("ppiyak", "ppiyak_evolved", "ppiyak_evolved2")
TIER_LABELS = ("BASE", "EVOLVED", "EVOLVED 2")
SHEETS = (
    ("Idle", "idle_blink_6f_remake.png"),
    ("Walk", "walk_8f_remake.png"),
    ("Sleep", "sleep_6f_remake.png"),
    ("Eat", "eat_6f_remake.png"),
    ("Sick", "sick_6f_remake.png"),
    ("Sulk", "sulk_6f_remake.png"),
    ("Play", "happy_6f_remake.png"),
    ("Dragged", "dragged_4f_remake.png"),
    ("Fall", "fall_4f_remake.png"),
    ("Land", "land_4f_remake.png"),
    ("FileHover", "file_hover_4f_remake.png"),
    ("FileConsume", "file_consume_6f_remake.png"),
    ("Poop", "poop_6f_remake.png"),
    ("Pet", "pet_6f_remake.png"),
)


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = Path("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf")
    return ImageFont.truetype(path, size) if path.exists() else ImageFont.load_default()


def validate_sheet(sheet: Image.Image, sheet_path: Path, filename: str) -> None:
    columns = 4 if "4f_" in filename or filename.startswith("walk_") else 6
    rows = 2 if filename.startswith("walk_") else 1
    expected_size = (columns * 192, rows * 208)
    if sheet.mode != "RGBA" or sheet.size != expected_size:
        raise ValueError(f"invalid sheet contract: {sheet_path} ({sheet.mode}, {sheet.size})")
    alpha = sheet.getchannel("A")
    for row in range(rows):
        for column in range(columns):
            cell = alpha.crop((column * 192, row * 208, (column + 1) * 192, (row + 1) * 208))
            if cell.getbbox() is None:
                raise ValueError(f"empty cell: {sheet_path} ({column}, {row})")
            edge_has_alpha = any(
                edge.getbbox() is not None
                for edge in (
                    cell.crop((0, 0, 192, 1)),
                    cell.crop((0, 207, 192, 208)),
                    cell.crop((0, 0, 1, 208)),
                    cell.crop((191, 0, 192, 208)),
                )
            )
            if edge_has_alpha:
                raise ValueError(f"cell-edge alpha: {sheet_path} ({column}, {row})")
    import_text = sheet_path.with_suffix(sheet_path.suffix + ".import").read_text(encoding="utf-8")
    if "mipmaps/generate=true" not in import_text:
        raise ValueError(f"mipmaps disabled: {sheet_path}")


def main() -> None:
    title_font = load_font(34)
    header_font = load_font(25)
    state_font = load_font(22)
    row_heights = [464 if filename.startswith("walk_") else 256 for _, filename in SHEETS]
    width = 3_740
    height = 150 + sum(row_heights)
    board = Image.new("RGB", (width, height), "#f7f3ea")
    draw = ImageDraw.Draw(board)
    draw.text((28, 22), "PPIYAK REMAKE · ALL 42 RUNTIME SHEETS · EVERY FRAME", fill="#403a34", font=title_font)
    for tier_index, label in enumerate(TIER_LABELS):
        draw.text((180 + tier_index * 1_200, 88), label, fill="#5b5148", font=header_font)

    y = 142
    validated = 0
    for (state, filename), row_height in zip(SHEETS, row_heights, strict=True):
        draw.text((28, y + 10), state, fill="#403a34", font=state_font)
        for tier_index, tier in enumerate(TIERS):
            sheet_path = ROOT / "assets/sprites" / tier / filename
            with Image.open(sheet_path) as source:
                validate_sheet(source, sheet_path, filename)
                sheet = source.convert("RGBA")
            validated += 1
            backdrop = Image.new("RGBA", sheet.size, "#ede8de")
            backdrop.alpha_composite(sheet)
            board.paste(backdrop.convert("RGB"), (172 + tier_index * 1_200, y))
        draw.line((22, y + row_height - 1, width - 22, y + row_height - 1), fill="#d8d0c4", width=1)
        y += row_height

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    board.save(OUTPUT, optimize=True)
    print(f"PPIYAK CONTACT: {OUTPUT} ({width}x{height}); validated={validated}/42")


if __name__ == "__main__":
    main()
