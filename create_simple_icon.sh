#!/bin/bash
# Create a quick Blockbuster-blue style icon
RESOURCES="$HOME/NintendoEmulator/Resources"
mkdir -p "$RESOURCES"

# Create a simple 1024x1024 blue square with text using Python
python3 << 'PYTHON'
from PIL import Image, ImageDraw, ImageFont
import os

# Create 1024x1024 blue image
img = Image.new('RGB', (1024, 1024), '#003087')
draw = ImageDraw.Draw(img)

# Add yellow border
border_width = 20
draw.rectangle(
    [(border_width, border_width), (1024-border_width, 1024-border_width)],
    outline='#FFD700',
    width=border_width
)

# Try to add text (may fail if no fonts available)
try:
    font = ImageFont.truetype('/System/Library/Fonts/Helvetica.ttc', 200)
except:
    font = ImageFont.load_default()

# Add "N64" text in yellow
text = "N64"
bbox = draw.textbbox((0, 0), text, font=font)
text_width = bbox[2] - bbox[0]
text_height = bbox[3] - bbox[1]
x = (1024 - text_width) // 2
y = (1024 - text_height) // 2

draw.text((x, y), text, fill='#FFD700', font=font)

# Save
save_path = os.path.expanduser('~/NintendoEmulator/Resources/icon_temp.png')
img.save(save_path)
print(f"Icon created: {save_path}")
PYTHON

# Convert to .icns
ICONSET="$RESOURCES/AppIcon.iconset"
mkdir -p "$ICONSET"

# Generate all sizes
for size in 16 32 64 128 256 512 1024; do
    sips -z $size $size "$RESOURCES/icon_temp.png" --out "$ICONSET/icon_${size}x${size}.png" 2>/dev/null
done

# Convert to icns
iconutil -c icns "$ICONSET" -o "$RESOURCES/AppIcon.icns"

# Cleanup
rm -rf "$ICONSET" "$RESOURCES/icon_temp.png"

echo "✅ Icon created: $RESOURCES/AppIcon.icns"
