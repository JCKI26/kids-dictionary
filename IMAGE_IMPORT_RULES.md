# Image Import Reprocessing Rules

These rules apply whenever images are imported from `C:\Users\jacky\kids_dict_app\images_backup` into `assets/images`.

## Rules

1. **Resize only**
   - Reduce image height to **250 pixels** when the source is taller than 250 px.
   - Maintain the original aspect ratio (do not stretch or crop).

2. **Preserve original formats**
   - PNG source files must remain PNGs.
   - JPG/JPEG source files must remain JPGs.
   - Do not convert between formats during import.

3. **Preserve transparency**
   - PNG files with alpha/transparency must keep their transparent background.
   - Do not convert RGBA images to RGB or flatten them to a solid color.
   - Verified by checking sampled PNGs are still in RGBA mode.

## Source of truth

- Original images: `C:\Users\jacky\kids_dict_app\images_backup`
- Processed images: `C:\Users\jacky\.openclaw\workspace\kids-dictionary\assets\images`
