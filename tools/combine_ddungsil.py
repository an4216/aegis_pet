"""뚱실이 개별 포즈 이미지 7장 → 4x2 투명 배경 시트 1장으로 통합.
다른 캐릭터와 동일한 방식으로 design/뚱실이.png에 저장한 뒤 slice_sheet로 재슬라이스한다.
walk2는 원본이 없어 walk1 복사."""
import os
import sys
from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from slice_sheet import ensure_alpha, drop_stray_fragments

SRC = r"C:\Users\user1\Documents\aegisepMessenger\cat"
DST_SHEET = os.path.join(os.path.dirname(__file__), "..", "design", "뚱실이.png")

# 4열 x 2행 순서 (slice_sheet 기본 순서와 동일)
POSE_ORDER = ["idle", "walk1", "walk2", "sleep", "happy", "sulk", "sick", "eat"]
CELL = 480       # 각 셀 크기
CHAR_MAX = 420   # 캐릭터 최대 크기 (셀 안에 여백 30px)


def main() -> None:
    cols, rows = 4, 2
    sheet = Image.new("RGBA", (cols * CELL, rows * CELL), (0, 0, 0, 0))
    for i, pose in enumerate(POSE_ORDER):
        src_pose = "walk1" if pose == "walk2" else pose
        src = os.path.join(SRC, src_pose + ".png")
        if not os.path.exists(src):
            print("MISS", pose)
            continue
        im = ensure_alpha(Image.open(src))
        im = drop_stray_fragments(im)
        bbox = im.getbbox()
        if bbox is None:
            print("EMPTY", pose)
            continue
        im = im.crop(bbox)
        scale = min(CHAR_MAX / im.size[0], CHAR_MAX / im.size[1], 1.0)
        w, h = int(im.size[0] * scale), int(im.size[1] * scale)
        im = im.resize((w, h), Image.LANCZOS)
        cx = (i % cols) * CELL + (CELL - w) // 2
        cy = (i // cols) * CELL + (CELL - h) // 2
        sheet.paste(im, (cx, cy), im)
        print("placed", pose, "at cell %d,%d (%dx%d)" % (i % cols, i // cols, w, h))
    os.makedirs(os.path.dirname(DST_SHEET), exist_ok=True)
    sheet.save(DST_SHEET)
    print("sheet saved:", DST_SHEET, sheet.size)


if __name__ == "__main__":
    main()
