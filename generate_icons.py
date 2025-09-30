#!/usr/bin/env python3
"""Generate Blockbuster-style app icons for NintendoEmulator."""

from PIL import Image, ImageDraw, ImageFont
import os

def create_blockbuster_icon(size):
    """Create a Blockbuster-style icon at the specified size."""
    # Colors matching Blockbuster brand
    blue = (0, 51, 153)  # Blockbuster blue
    yellow = (255, 204, 0)  # Blockbuster yellow

    # Create image with blue background
    img = Image.new('RGBA', (size, size), blue + (255,))
    draw = ImageDraw.Draw(img)

    # Calculate proportions
    border_width = max(2, size // 64)
    ticket_indent = size // 8

    # Draw yellow torn ticket border
    # Top edge (jagged)
    points_top = []
    num_teeth = max(8, size // 32)
    tooth_width = size / num_teeth
    for i in range(num_teeth):
        x = i * tooth_width
        points_top.append((x, 0 if i % 2 == 0 else border_width * 2))
    points_top.append((size, 0))

    # Bottom edge (jagged)
    points_bottom = []
    for i in range(num_teeth):
        x = i * tooth_width
        points_bottom.append((x, size if i % 2 == 0 else size - border_width * 2))
    points_bottom.append((size, size))

    # Draw yellow border rectangle with ticket cutouts
    # Left side with ticket punch
    draw.polygon([
        (0, ticket_indent),
        (border_width * 3, ticket_indent),
        (border_width * 3, ticket_indent + size // 16),
        (0, ticket_indent + size // 16)
    ], fill=yellow)

    # Right side with ticket punch
    draw.polygon([
        (size - border_width * 3, ticket_indent),
        (size, ticket_indent),
        (size, ticket_indent + size // 16),
        (size - border_width * 3, ticket_indent + size // 16)
    ], fill=yellow)

    # Draw torn edges at top and bottom
    if size >= 64:
        for i in range(0, size, size // 16):
            # Top tears
            tear_height = (i % 2) * border_width + border_width
            draw.rectangle([i, 0, i + size // 16, tear_height], fill=yellow)
            # Bottom tears
            draw.rectangle([i, size - tear_height, i + size // 16, size], fill=yellow)
    else:
        # Simple borders for small sizes
        draw.rectangle([0, 0, size, border_width], fill=yellow)
        draw.rectangle([0, size - border_width, size, size], fill=yellow)

    # Draw left and right borders
    draw.rectangle([0, 0, border_width * 2, size], fill=yellow)
    draw.rectangle([size - border_width * 2, 0, size, size], fill=yellow)

    # Add text based on size
    if size >= 128:
        # Try to load a bold font, fall back to default
        try:
            font_size = size // 8
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size)
        except:
            font = ImageFont.load_default()

        # Draw "N64" text
        text = "N64"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        text_x = (size - text_width) // 2
        text_y = size // 3

        # Draw text with slight shadow
        draw.text((text_x + 2, text_y + 2), text, fill=(0, 0, 0, 128), font=font)
        draw.text((text_x, text_y), text, fill=yellow, font=font)

        # Draw "EMULATOR" text below
        if size >= 256:
            font_size_small = size // 16
            try:
                font_small = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", font_size_small)
            except:
                font_small = ImageFont.load_default()

            text2 = "EMULATOR"
            bbox2 = draw.textbbox((0, 0), text2, font=font_small)
            text2_width = bbox2[2] - bbox2[0]
            text2_x = (size - text2_width) // 2
            text2_y = text_y + text_height + size // 20

            draw.text((text2_x + 1, text2_y + 1), text2, fill=(0, 0, 0, 128), font=font_small)
            draw.text((text2_x, text2_y), text2, fill=yellow, font=font_small)

    elif size >= 32:
        # Small icon - just draw "N64" centered
        try:
            font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", size // 4)
        except:
            font = ImageFont.load_default()

        text = "N64"
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        text_x = (size - text_width) // 2
        text_y = (size - text_height) // 2

        draw.text((text_x, text_y), text, fill=yellow, font=font)

    # Add rounded corners for modern macOS look
    if size >= 64:
        radius = size // 8
        # Create alpha mask for rounded corners
        mask = Image.new('L', (size, size), 255)
        mask_draw = ImageDraw.Draw(mask)
        mask_draw.rectangle([0, 0, size, size], fill=255)

        # Round the corners
        mask_draw.ellipse([0, 0, radius * 2, radius * 2], fill=0)
        mask_draw.ellipse([size - radius * 2, 0, size, radius * 2], fill=0)
        mask_draw.ellipse([0, size - radius * 2, radius * 2, size], fill=0)
        mask_draw.ellipse([size - radius * 2, size - radius * 2, size, size], fill=0)

        # Apply mask
        img.putalpha(mask)

    return img


def main():
    """Generate all required icon sizes."""
    output_dir = "Resources/AppIcon.appiconset"
    os.makedirs(output_dir, exist_ok=True)

    # macOS icon sizes
    sizes = [16, 32, 64, 128, 256, 512, 1024]

    print("Generating Blockbuster-style icons...")

    for size in sizes:
        icon = create_blockbuster_icon(size)
        filename = f"icon_{size}x{size}.png"
        filepath = os.path.join(output_dir, filename)
        icon.save(filepath, 'PNG')
        print(f"✅ Created {filename}")

        # Also create @2x version
        if size <= 512:
            filename_2x = f"icon_{size}x{size}@2x.png"
            filepath_2x = os.path.join(output_dir, filename_2x)
            icon_2x = create_blockbuster_icon(size * 2)
            icon_2x.save(filepath_2x, 'PNG')
            print(f"✅ Created {filename_2x}")

    # Create Contents.json for the icon set
    contents_json = """{
  "images" : [
    {
      "filename" : "icon_16x16.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_16x16@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "filename" : "icon_32x32.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_32x32@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "filename" : "icon_128x128.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_128x128@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "filename" : "icon_256x256.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_256x256@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "filename" : "icon_512x512.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "filename" : "icon_512x512@2x.png",
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
"""

    contents_path = os.path.join(output_dir, "Contents.json")
    with open(contents_path, 'w') as f:
        f.write(contents_json)
    print(f"✅ Created Contents.json")

    # Generate .icns file for macOS
    print("\nGenerating .icns file...")
    os.system(f"cd Resources && iconutil -c icns AppIcon.appiconset -o AppIcon.icns")
    print("✅ Created AppIcon.icns")

    print("\n🎉 Icon set complete! Files created in Resources/AppIcon.appiconset/")
    print("📦 To use in your app, add AppIcon.icns to your Xcode project.")


if __name__ == "__main__":
    main()