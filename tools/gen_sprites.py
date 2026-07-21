# Kakao-emoticon style smooth character sprites (10 hatchable characters + egg).
# Shapes drawn on 512x512 (coords in legacy 32-space, x16), LANCZOS-downsampled to 256x256,
# then wrapped with a thick rounded sticker outline. Output: assets/sprites/concept/*.png + sheet.
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os

GRID = 256         # final sprite resolution
C = 16             # 32-space -> hi-res scale (32 * 16 = 512)
HI = 32 * C
P2 = GRID // 32    # 32-space -> final-res scale (for post decorations)
OUTLINE_R = 3      # sticker outline thickness (px at 256)
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "concept")

EYE = (52, 40, 51, 255)
WHT = (255, 255, 255, 255)


def sc_box(box):
    x0, y0, x1, y1 = box
    return (x0 * C, y0 * C, (x1 + 1) * C - 1, (y1 + 1) * C - 1)


def sc_f(box):
    return [v * C for v in box]


class Sprite:
    def __init__(self):
        self.hi = Image.new("RGBA", (HI, HI), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.hi)
        self.img = None
        self.pd = None

    # --- hi-res drawing (32-space coords, int boxes keep legacy +1 semantics) ---
    def el(self, box, c):
        self.d.ellipse(sc_box(box), fill=c)

    def el_f(self, box, c):
        self.d.ellipse(sc_f(box), fill=c)

    def el_o(self, box, c, w=0.3):
        self.d.ellipse(sc_f(box), outline=c, width=max(1, int(w * C)))

    def rect(self, box, c):
        self.d.rectangle(sc_box(box), fill=c)

    def poly(self, pts, c):
        self.d.polygon([(x * C, y * C) for x, y in pts], fill=c)

    def line(self, pts, c, w=1.0):
        self.d.line([(x * C, y * C) for x, y in pts], fill=c, width=max(1, int(w * C)), joint="curve")

    def arc(self, box, a0, a1, c, w=0.3):
        self.d.arc(sc_f(box), a0, a1, fill=c, width=max(1, int(w * C)))

    # --- kawaii face parts ---
    def eye(self, cx, cy, w=3.2, h=3.6, pupil=EYE):
        """Big glossy eye with two highlights (Kakao emoticon style)."""
        self.el_f((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), pupil)
        hw, hh = w * 0.44, h * 0.42
        self.el_f((cx - w * 0.34, cy - h * 0.38, cx - w * 0.34 + hw, cy - h * 0.38 + hh), WHT)
        sw = w * 0.2
        self.el_f((cx + w * 0.08, cy + h * 0.14, cx + w * 0.08 + sw, cy + h * 0.14 + sw), (255, 255, 255, 255))

    def awake_eye(self, cx, cy, w=3.8, h=4.2):
        """Caffeinated wide-open eye: big white sclera + small pupil."""
        self.el_f((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), (252, 250, 248, 255))
        self.el_f((cx - 0.75, cy - 0.85, cx + 0.75, cy + 0.85), EYE)
        self.el_f((cx - 0.45, cy - 0.55, cx + 0.05, cy - 0.05), WHT)

    def closed_eye(self, cx, cy, w=3.0):
        """Happy/sleepy closed eye (thick rounded arc)."""
        self.arc((cx - w / 2, cy - w / 2, cx + w / 2, cy + w / 2), 20, 160, EYE, 0.55)

    def smile(self, cx, cy, w=3.0):
        self.arc((cx - w / 2, cy - w / 2, cx + w / 2, cy + w / 2), 25, 155, EYE, 0.45)

    def blush(self, cx, cy, c, w=2.6, h=1.6):
        self.el_f((cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2), c)

    def clear_below(self, y):
        self.d.rectangle((0, (y + 1) * C, HI, HI), fill=(0, 0, 0, 0))

    def shade_rows(self, y0, y1, from_c, to_c):
        p = self.hi.load()
        for yy in range(y0 * C, (y1 + 1) * C):
            for xx in range(HI):
                if p[xx, yy] == from_c:
                    p[xx, yy] = to_c

    # --- finalize: smooth downsample + thick rounded sticker outline ---
    def outline(self, c):
        img = self.hi.resize((GRID, GRID), Image.LANCZOS)
        a = img.getchannel("A").point(lambda v: 255 if v > 40 else 0)
        grown = a.filter(ImageFilter.MaxFilter(OUTLINE_R * 2 + 1))
        base = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
        base.paste(Image.new("RGBA", (GRID, GRID), c), (0, 0), grown)
        base.alpha_composite(img)
        self.img = base
        self.pd = ImageDraw.Draw(self.img)

    # --- post decorations (final-res, 32-space coords, no outline) ---
    def post_line(self, pts, c, w=0.7):
        self.pd.line([(x * P2, y * P2) for x, y in pts], fill=c, width=max(1, int(w * P2)), joint="curve")

    def post_el(self, box, c):
        self.pd.ellipse([v * P2 for v in box], fill=c)


def mochi():
    s = Sprite()
    M, SH, OUT, PT = (255, 217, 232, 255), (242, 167, 195, 255), (140, 74, 99, 255), (255, 143, 177, 255)
    s.el((7, 10, 25, 48), M)
    s.clear_below(29)
    s.el((22, 27, 25, 31), M)                    # melty drip
    s.rect((10, 24, 22, 29), M)
    s.el_f((9, 26.5, 23.5, 32), SH)              # soft bottom shade
    s.clear_below(29)
    s.el((22, 27, 25, 31), M)
    s.el_f((10.2, 13.2, 13.2, 16.6), (255, 245, 250, 255))   # jelly highlight
    s.eye(12.2, 20.2)
    s.eye(20.4, 20.2)
    s.smile(16.3, 23.8, 2.6)
    s.blush(9.7, 23.2, PT)
    s.blush(22.9, 23.2, PT)
    s.outline(OUT)
    return s, "mochi", "모찌"


def ppiyak():
    s = Sprite()
    M, SH, OUT, PT = (255, 224, 102, 255), (240, 180, 41, 255), (138, 109, 31, 255), (255, 159, 28, 255)
    s.line([(16.4, 4), (15.6, 6), (16.2, 8.5)], M, 0.7)      # head sprout
    s.line([(16.0, 5.2), (17.6, 4.4)], M, 0.6)
    s.el((7, 9, 25, 29), M)
    s.el((6, 17, 10, 24), SH)                    # wings
    s.el((22, 17, 26, 24), SH)
    s.eye(11.9, 16.0, 3.0, 3.4)
    s.eye(20.5, 16.0, 3.0, 3.4)
    s.poly([(15.0, 19.6), (17.6, 19.6), (16.3, 21.4)], PT)   # beak
    s.blush(9.4, 19.2, (255, 170, 150, 255), 2.2, 1.4)
    s.blush(23.0, 19.2, (255, 170, 150, 255), 2.2, 1.4)
    s.line([(12.6, 22.0), (14.2, 24.4)], (90, 90, 110, 255), 0.35)   # lanyard
    s.line([(19.8, 22.0), (18.2, 24.4)], (90, 90, 110, 255), 0.35)
    s.rect((13, 24, 19, 28), (248, 249, 250, 255))           # badge
    s.rect((14, 25, 15, 27), (110, 150, 220, 255))
    s.rect((16, 25, 18, 25), (180, 185, 195, 255))
    s.rect((16, 27, 18, 27), (180, 185, 195, 255))
    s.el_f((10.8, 28.6, 13, 30.6), PT)           # feet
    s.el_f((19.4, 28.6, 21.6, 30.6), PT)
    s.outline(OUT)
    return s, "ppiyak", "삐약"


def nyang():
    s = Sprite()
    M, SH, OUT, PT = (154, 160, 166, 255), (123, 128, 135, 255), (74, 78, 84, 255), (248, 249, 250, 255)
    s.poly([(8, 13), (10, 6), (14.5, 12)], M)    # ears
    s.poly([(17.5, 12), (22, 6), (24, 13)], M)
    s.poly([(9.4, 11.2), (10.4, 8.2), (12.6, 10.8)], (240, 170, 180, 255))
    s.poly([(19.6, 10.8), (21.6, 8.2), (22.6, 11.2)], (240, 170, 180, 255))
    s.el((7, 11, 25, 29), M)
    s.line([(25, 24), (28.2, 26.8), (28.2, 29.5)], M, 1.8)   # droopy tail
    s.closed_eye(12.0, 18.3, 3.2)
    s.closed_eye(20.2, 18.3, 3.2)
    s.blush(9.4, 19.6, (235, 165, 175, 255), 2.2, 1.3)
    s.blush(23.0, 19.6, (235, 165, 175, 255), 2.2, 1.3)
    s.rect((12, 22, 20, 27), PT)                 # resignation envelope
    s.line([(12, 22.2), (16.2, 25.2), (20.4, 22.2)], (200, 200, 205, 255), 0.3)
    s.el_f((15.7, 25.8, 16.9, 27), (230, 57, 70, 255))       # seal
    s.outline(OUT)
    return s, "nyang", "나른냥"


def kong():
    s = Sprite()
    M, SH, OUT = (139, 94, 60, 255), (111, 74, 47, 255), (62, 42, 27, 255)
    s.el((8, 9, 24, 29), M)
    s.el_f((10.5, 11.0, 13.5, 14.0), (185, 140, 100, 255))   # shine
    s.line([(16.4, 10), (15.6, 12), (16.4, 14)], OUT, 0.45)  # bean crack
    s.awake_eye(12.0, 18.2)
    s.awake_eye(20.4, 18.2)
    s.el_f((15.3, 23.0, 17.2, 24.9), EYE)        # surprised 'o' mouth
    s.blush(9.2, 21.4, (175, 120, 85, 255), 2.0, 1.3)
    s.blush(23.2, 21.4, (175, 120, 85, 255), 2.0, 1.3)
    s.outline(OUT)
    st = (248, 243, 235, 255)
    s.post_line([(11.5, 8), (12.3, 6), (11.5, 4), (12.3, 2.5)], st, 0.8)   # steam
    s.post_line([(19.8, 8), (19.0, 6), (19.8, 4), (19.0, 2.5)], st, 0.8)
    return s, "kong", "콩이"


def kkubeok():
    s = Sprite()
    M, SH, OUT, PT = (200, 161, 128, 255), (169, 127, 94, 255), (92, 68, 51, 255), (91, 74, 107, 255)
    s.el((6, 6, 12, 12), M)                      # ears
    s.el((20, 6, 26, 12), M)
    s.el((8, 8, 10, 10), SH)
    s.el((22, 8, 24, 10), SH)
    s.el((7, 10, 25, 29), M)
    s.closed_eye(11.9, 16.4, 3.0)
    s.closed_eye(20.1, 16.4, 3.0)
    s.el_f((10.4, 18.1, 13.3, 19.0), PT)         # dark circles
    s.el_f((18.7, 18.1, 21.6, 19.0), PT)
    s.el((12, 19, 20, 24), (232, 208, 180, 255))  # muzzle
    s.el_f((14.9, 19.8, 17.5, 21.6), OUT)         # nose
    B, B2 = (191, 211, 230, 255), (160, 185, 210, 255)
    s.rect((9, 25, 23, 26), B)                   # blanket wrapped low
    s.rect((9, 25, 12, 29), B)                   # hanging corner
    s.rect((9, 27, 12, 27), B2)
    s.line([(9.5, 26.6), (23, 26.6)], B2, 0.35)
    s.outline(OUT)
    z = (150, 170, 200, 255)
    s.post_line([(25, 3.5), (27, 3.5), (25, 5.5), (27, 5.5)], z, 0.7)      # floating Z
    return s, "kkubeok", "꾸벅"


def bulgeumjo():
    s = Sprite()
    M, SH, OUT = (255, 107, 53, 255), (230, 80, 40, 255), (74, 59, 51, 255)
    BELLY, CREST = (247, 197, 72, 255), (255, 209, 102, 255)
    s.poly([(11, 11), (13, 4), (15.5, 11)], CREST)           # flame crest
    s.poly([(14, 11), (16.2, 2), (18.5, 11)], CREST)
    s.poly([(17, 11), (20, 5), (21.5, 11)], CREST)
    s.poly([(15.2, 11), (16.2, 5.5), (17.4, 11)], M)         # inner flame
    s.el((8, 10, 24, 28), M)
    s.el((11, 17, 21, 27), BELLY)
    s.el((6, 16, 10, 23), SH)                    # wings
    s.el((22, 16, 26, 23), SH)
    s.eye(11.9, 15.8, 3.0, 3.4)
    s.eye(20.5, 15.8, 3.0, 3.4)
    s.poly([(15.0, 18.6), (17.6, 18.6), (16.3, 20.4)], (150, 55, 20, 255))  # beak
    s.blush(9.3, 18.8, (255, 180, 160, 255), 2.2, 1.4)
    s.blush(23.1, 18.8, (255, 180, 160, 255), 2.2, 1.4)
    s.line([(8, 26), (5, 28), (3.2, 26.8)], CREST, 1.6)      # flame tail
    s.el_f((11.6, 28, 13.6, 30.4), (150, 55, 20, 255))       # feet
    s.el_f((18.8, 28, 20.8, 30.4), (150, 55, 20, 255))
    s.outline(OUT)
    return s, "bulgeumjo", "불금조"


def haemjji():
    s = Sprite()
    M, SH, OUT, PT = (255, 232, 200, 255), (232, 196, 154, 255), (122, 92, 62, 255), (244, 162, 89, 255)
    s.el((7, 6, 12, 11), M)                      # ears
    s.el((20, 6, 25, 11), M)
    s.el((9, 8, 11, 10), (250, 180, 170, 255))
    s.el((21, 8, 23, 10), (250, 180, 170, 255))
    s.el((6, 10, 26, 29), M)
    s.el((16, 9, 23, 13), PT)                    # orange head patch
    s.el((4, 16, 11, 24), M)                     # puffed cheeks
    s.el((21, 16, 28, 24), M)
    s.eye(11.8, 15.3, 3.0, 3.4)
    s.eye(20.4, 15.3, 3.0, 3.4)
    s.el_f((15.1, 17.9, 17.0, 19.1), (250, 150, 160, 255))   # nose
    s.el((12, 20, 20, 28), (255, 244, 225, 255))             # belly
    s.el_f((14.3, 24, 17.2, 28), (150, 100, 60, 255))        # sunflower seed
    s.line([(15.4, 25), (16.1, 27.2)], (210, 165, 115, 255), 0.4)
    s.el_f((13.0, 25.4, 15.0, 27.4), M)          # paws
    s.el_f((16.6, 25.4, 18.6, 27.4), M)
    s.blush(6.9, 20.3, (255, 170, 150, 255), 2.4, 1.5)
    s.blush(25.3, 20.3, (255, 170, 150, 255), 2.4, 1.5)
    s.outline(OUT)
    return s, "haemjji", "햄찌"


def mundeok():
    s = Sprite()
    M, SH, OUT, PT = (179, 157, 219, 255), (142, 124, 195, 255), (78, 67, 112, 255), (241, 243, 244, 255)
    s.el((7, 7, 25, 24), M)                      # head
    s.el((6, 22, 12, 30), M)                     # leg scallops
    s.el((11, 23, 17, 30), M)
    s.el((16, 23, 22, 30), M)
    s.el((21, 22, 26, 30), M)
    for x in (11.5, 16.5, 21.0):                 # leg seams
        s.line([(x, 27.5), (x, 29.5)], SH, 0.35)
    s.line([(10.4, 13.0), (12.8, 11.9)], EYE, 0.45)          # worried brows
    s.line([(19.6, 11.9), (22.0, 13.0)], EYE, 0.45)
    s.eye(11.9, 16.0, 3.2, 3.6)
    s.eye(20.4, 16.0, 3.2, 3.6)
    s.el_f((15.3, 19.6, 17.1, 21.4), EYE)        # small 'o' mouth
    s.blush(9.0, 19.2, (205, 160, 200, 255), 2.0, 1.3)
    s.blush(23.4, 19.2, (205, 160, 200, 255), 2.0, 1.3)
    s.rect((3, 18, 7, 23), PT)                   # paper
    s.rect((4, 20, 6, 20), (170, 175, 185, 255))
    s.rect((4, 22, 6, 22), (170, 175, 185, 255))
    s.rect((25, 18, 28, 23), PT)                 # coffee cup
    s.rect((25, 20, 28, 21), (139, 94, 60, 255))
    s.outline(OUT)
    s.post_el((24.6, 8, 26, 10.4), (160, 200, 240, 255))     # sweat drop
    return s, "mundeok", "문덕"


def geobujang():
    s = Sprite()
    SHELL, SH, OUT, PT = (107, 142, 35, 255), (79, 107, 27, 255), (46, 61, 20, 255), (217, 197, 139, 255)
    SKIN = (156, 186, 90, 255)
    s.arc((13, 7.5, 19.5, 14), 180, 360, PT, 0.6)            # briefcase handle
    s.el((6, 12, 26, 40), SHELL)                 # shell dome
    s.clear_below(29)
    s.line([(8, 20.5), (24.5, 20.5)], SH, 0.4)   # shell seams
    s.line([(16.3, 13), (16.3, 20)], SH, 0.4)
    s.rect((15, 15, 17, 16), PT)                 # clasp
    s.el_f((6.8, 27.5, 10.5, 30.5), SKIN)        # feet
    s.el_f((21.8, 27.5, 25.5, 30.5), SKIN)
    s.el((10, 19, 22, 30), SKIN)                 # head peeking out
    FR = (110, 88, 45, 255)
    s.el_o((10.6, 20.8, 15.0, 25.2), FR, 0.5)    # big round glasses
    s.el_o((17.6, 20.8, 22.0, 25.2), FR, 0.5)
    s.line([(15.0, 22.9), (17.6, 22.9)], FR, 0.45)
    s.eye(12.8, 23.0, 2.0, 2.2)                  # eyes behind lenses
    s.eye(19.8, 23.0, 2.0, 2.2)
    s.smile(16.3, 27.2, 2.6)
    s.outline(OUT)
    return s, "geobujang", "거부장"


def seureureuk():
    s = Sprite()
    A = 235
    M, OUT, PT = (168, 218, 220, A), (61, 107, 110, 255), (230, 57, 70, 255)
    s.el((8, 6, 24, 22), M)
    s.rect((8, 14, 24, 26), M)
    s.poly([(8, 26), (13, 26), (10.5, 30)], M)   # wavy tail tips
    s.poly([(13, 26), (19, 26), (16, 31)], M)
    s.poly([(19, 26), (24, 26), (21.5, 30)], M)
    s.eye(11.9, 13.8)
    s.eye(20.4, 13.8)
    s.smile(16.2, 17.6, 2.8)
    s.blush(9.4, 16.4, (240, 170, 190, 255), 2.2, 1.4)
    s.blush(22.9, 16.4, (240, 170, 190, 255), 2.2, 1.4)
    s.rect((13, 20, 19, 20), (240, 250, 250, A))             # shirt collar
    s.poly([(15.2, 21), (17.4, 21), (16.3, 22.4)], PT)       # tie knot
    s.poly([(16.3, 21.8), (17.3, 23.2), (16.3, 26), (15.3, 23.2)], (200, 40, 55, 255))
    s.outline(OUT)
    return s, "seureureuk", "스르륵"


def egg():
    s = Sprite()
    M, SH, OUT, PT = (255, 248, 230, 255), (235, 220, 190, 255), (150, 120, 90, 255), (255, 180, 200, 255)
    s.el((9, 7, 23, 29), M)
    s.shade_rows(25, 29, M, SH)
    s.el((13, 12, 15, 14), PT)                   # spots
    s.el((18, 17, 20, 19), PT)
    s.el_f((11.8, 20.6, 13.2, 22), PT)
    s.el_f((11.8, 9.6, 14.6, 12.6), WHT)         # shine
    s.outline(OUT)
    return s, "egg", "알"


CHARS = [egg, mochi, ppiyak, haemjji, kkubeok, nyang, kong, mundeok, geobujang, bulgeumjo, seureureuk]


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    sprites = []
    for fn in CHARS:
        s, name, kr = fn()
        s.img.save(os.path.join(OUT_DIR, f"{name}.png"))
        sprites.append((s.img, name, kr))

    cols, tile, label_h = 4, GRID, 36
    rows = (len(sprites) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * tile, rows * (tile + label_h)), (245, 245, 248, 255))
    d = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("C:/Windows/Fonts/malgun.ttf", 22)
    except OSError:
        font = ImageFont.load_default()
    for i, (img, name, kr) in enumerate(sprites):
        cx, cy = (i % cols) * tile, (i // cols) * (tile + label_h)
        sheet.paste(img, (cx, cy), img)
        d.text((cx + tile // 2, cy + tile + 4), kr, fill=(60, 60, 70), font=font, anchor="ma")
    sheet.save(os.path.join(OUT_DIR, "sheet.png"))
    print("saved", len(sprites), "sprites ->", os.path.abspath(OUT_DIR))


if __name__ == "__main__":
    main()
