import os
from pathlib import Path
from PIL import Image, ImageDraw

BACKUP_DIR = Path(r"C:\Users\jacky\.openclaw\workspace\kids_dict_app\assets\images_backup")
OUTPUT_DIR = Path(r"C:\Users\jacky\.openclaw\workspace\kids_dict_app\assets\images")
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Corner radius as a fraction of the smaller dimension.
# 0.05 means 5% of min(width, height), matching typical app card radius.
RADIUS_FRACTION = 0.05


def add_rounded_corners(img: Image.Image, radius_fraction: float = RADIUS_FRACTION) -> Image.Image:
    """Apply a symmetric rounded-rectangle mask (RGBA output with transparent corners)."""
    if img.mode != "RGBA":
        # Convert to RGBA so corners can be transparent if saved as PNG/WebP.
        # For JPEG output, transparency becomes matte; we keep RGBA then convert at save.
        img = img.convert("RGBA")

    width, height = img.size
    radius = int(min(width, height) * radius_fraction)
    # Clamp to a sensible upper bound (large radii look odd)
    radius = max(4, min(radius, min(width, height) // 4))

    mask = Image.new("L", (width, height), 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, width - 1, height - 1), radius=radius, fill=255)

    result = img.copy()
    result.putalpha(mask)
    return result


def save_image(img: Image.Image, dest_path: Path) -> None:
    ext = dest_path.suffix.lower()
    if ext in {".jpg", ".jpeg"}:
        # JPEG cannot store alpha; composite onto white before saving.
        rgb = Image.new("RGB", img.size, (255, 255, 255))
        if img.mode == "RGBA":
            rgb.paste(img, mask=img.getchannel("A"))
        else:
            rgb.paste(img)
        rgb.save(dest_path, quality=95)
    elif ext == ".png":
        img.save(dest_path)
    else:
        # For webp/gif/etc., keep original conversion behavior.
        if img.mode == "RGBA":
            img.save(dest_path)
        else:
            img.convert("RGB").save(dest_path)


def main():
    files = sorted([p for p in BACKUP_DIR.iterdir() if p.is_file()])
    total = len(files)
    processed = 0
    skipped = 0
    errors = 0

    for i, src_path in enumerate(files, 1):
        dest_path = OUTPUT_DIR / src_path.name
        try:
            with Image.open(src_path) as img:
                rounded = add_rounded_corners(img)
                save_image(rounded, dest_path)
            processed += 1
        except Exception as e:
            errors += 1
            print(f"ERROR {src_path.name}: {e}")

        if i % 100 == 0 or i == total:
            print(f"Progress: {i}/{total} processed, {errors} errors")

    print(f"\nDone. Processed {processed} images into {OUTPUT_DIR}. Errors: {errors}.")


if __name__ == "__main__":
    main()
