"""뚱실이 캐릭터 이미지를 chars/ddungsil/로 임포트.
개별 파일이라 slice_sheet 아닌 별도 처리 (같은 배경 제거 + 규격화 사용)."""
import os
import shutil
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from slice_sheet import ensure_alpha, CANVAS, TARGET_H, BOTTOM_MARGIN, drop_stray_fragments

SRC = r"C:\Users\user1\Documents\aegisepMessenger\cat"
DST = os.path.join(os.path.dirname(__file__), "..", "assets", "sprites", "chars", "ddungsil")
POSES = ["idle", "walk1", "sleep", "happy", "sulk", "sick", "eat"]


def main() -> None:
    os.makedirs(DST, exist_ok=True)
    frames = []
    for pose in POSES:
        src_path = os.path.join(SRC, pose + ".png")
        if not os.path.exists(src_path):
            print("MISS", pose)
            continue
        im = ensure_alpha(Image.open(src_path))
        im = drop_stray_fragments(im)
        bbox = im.getbbox()
        if bbox is None:
            print("EMPTY", pose)
            continue
        frames.append((pose, im.crop(bbox)))

    # 자세별 높이가 크게 달라(sleep은 옆으로 누워있음) 개별 스케일링
    for pose, frame in frames:
        s = min(TARGET_H / frame.size[1], TARGET_H / frame.size[0], 1.0)
        fw, fh = int(frame.size[0] * s), int(frame.size[1] * s)
        frame = frame.resize((fw, fh), Image.LANCZOS)
        canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
        canvas.paste(frame, ((CANVAS - fw) // 2, CANVAS - BOTTOM_MARGIN - fh), frame)
        canvas.save(os.path.join(DST, pose + ".png"))
        print("saved", pose, "%dx%d" % (fw, fh))

    walk2 = os.path.join(DST, "walk2.png")
    walk1 = os.path.join(DST, "walk1.png")
    if os.path.exists(walk1) and not os.path.exists(walk2):
        shutil.copy(walk1, walk2)
        print("walk2 = copy of walk1 (원본 walk2 없음)")


if __name__ == "__main__":
    main()
