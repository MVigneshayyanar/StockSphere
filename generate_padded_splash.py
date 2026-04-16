from PIL import Image

def create_padded_splash(source_path, dest_path):
    print(f"Processing {source_path}...")
    try:
        img = Image.open(source_path).convert("RGBA")
        base_size = 1024
        icon_size = 512  # 50% of base_size, safe for Android 12 circle mask (diameter ~60-66%)

        # Resize icon maintaining aspect ratio
        img.thumbnail((icon_size, icon_size), Image.Resampling.LANCZOS)

        # Create new transparent image
        new_img = Image.new("RGBA", (base_size, base_size), (0, 0, 0, 0))

        # Calculate position to center
        pos_x = (base_size - img.width) // 2
        pos_y = (base_size - img.height) // 2

        new_img.paste(img, (pos_x, pos_y), img)

        new_img.save(dest_path)
        print(f"Saved padded splash logo to {dest_path}")

    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    create_padded_splash("assets/MAX_my_bill_mic.png", "assets/max_splash_mic_padded.png")

