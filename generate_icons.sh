#!/usr/bin/env bash

set -e

# ----------------------------------------------------
# 0. Detect Project Root (whether run from root or packaging/)
# ----------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/pubspec.yaml" ]; then
    PROJECT_ROOT="$SCRIPT_DIR"
elif [ -f "$SCRIPT_DIR/../pubspec.yaml" ]; then
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
elif [ -f "$(pwd)/pubspec.yaml" ]; then
    PROJECT_ROOT="$(pwd)"
else
    PROJECT_ROOT="$(pwd)"
fi
cd "$PROJECT_ROOT"

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}        Universal App Icon Generator (16 - 1024)    ${NC}"
echo -e "${BLUE}====================================================${NC}"
echo -e "${GREEN}Project Root:${NC} $PROJECT_ROOT"

# 1. Determine Source Icon
INPUT_FILE="$1"

if [ -n "$INPUT_FILE" ] && [ -f "$INPUT_FILE" ]; then
    ICON_SRC="$INPUT_FILE"
elif [ -f "assets/icons/app_icon.png" ]; then
    ICON_SRC="assets/icons/app_icon.png"
elif [ -f "assets/icon/app_icon.png" ]; then
    ICON_SRC="assets/icon/app_icon.png"
elif [ -f "assets/app_icon.png" ]; then
    ICON_SRC="assets/app_icon.png"
elif [ -f "assets/icons/icon.png" ]; then
    ICON_SRC="assets/icons/icon.png"
elif [ -f "assets/icon/icon.png" ]; then
    ICON_SRC="assets/icon/icon.png"
elif [ -f "assets/icon.png" ]; then
    ICON_SRC="assets/icon.png"
elif [ -f "linux/flutter/icon.png" ]; then
    ICON_SRC="linux/flutter/icon.png"
else
    echo -e "${RED}Error: Source icon not found in project!${NC}"
    echo -e "${YELLOW}Checked the following default locations:${NC}"
    echo "  - assets/icons/app_icon.png"
    echo "  - assets/icon/app_icon.png"
    echo "  - assets/app_icon.png"
    echo "  - assets/icons/icon.png"
    echo "  - assets/icon/icon.png"
    echo "  - assets/icon.png"
    echo ""
    echo -e "${BOLD}Usage:${NC} $0 [path/to/source_icon.png] [output_directory]"
    exit 1
fi

# Output directory (defaults to the directory containing the source icon)
OUT_DIR="$2"
if [ -z "$OUT_DIR" ]; then
    OUT_DIR="$(dirname "$ICON_SRC")"
fi
mkdir -p "$OUT_DIR"

echo -e "${GREEN}Source Image:${NC}     $ICON_SRC"
echo -e "${GREEN}Output Directory:${NC} $OUT_DIR"
echo ""

# 2. Determine Resizing Engine
RESIZE_ENGINE=""
if command -v magick &> /dev/null; then
    RESIZE_ENGINE="magick"
elif command -v convert &> /dev/null; then
    RESIZE_ENGINE="convert"
elif command -v ffmpeg &> /dev/null; then
    RESIZE_ENGINE="ffmpeg"
elif command -v sips &> /dev/null; then
    RESIZE_ENGINE="sips"
elif command -v python3 &> /dev/null && python3 -c "from PIL import Image" &> /dev/null; then
    RESIZE_ENGINE="python_pil"
elif command -v python3 &> /dev/null; then
    RESIZE_ENGINE="python"
fi

if [ -z "$RESIZE_ENGINE" ]; then
    echo -e "${RED}Error: No image resizing tool found (ImageMagick, ffmpeg, sips, or python3).${NC}"
    echo -e "${YELLOW}Please install ImageMagick (magick/convert) or ffmpeg.${NC}"
    exit 1
fi

echo -e "${BLUE}==> Using engine:${NC} ${BOLD}$RESIZE_ENGINE${NC}\n"

# Function to resize an image
resize_image() {
    local src="$1"
    local size="$2"
    local dst="$3"

    case "$RESIZE_ENGINE" in
        magick)
            magick "$src" -resize "${size}x${size}" "$dst"
            ;;
        convert)
            convert "$src" -resize "${size}x${size}" "$dst"
            ;;
        ffmpeg)
            ffmpeg -y -i "$src" -vf "scale=${size}:${size}:flags=lanczos" "$dst" -loglevel error
            ;;
        sips)
            cp "$src" "$dst"
            sips -z "$size" "$size" "$dst" > /dev/null 2>&1
            ;;
        python_pil|python)
            python3 -c "
from PIL import Image
img = Image.open('$src')
img = img.resize(($size, $size), Image.Resampling.LANCZOS if hasattr(Image, 'Resampling') else Image.LANCZOS)
img.save('$dst', 'PNG')
"
            ;;
    esac
}

# 3. Sizes to Generate (from 16 to 1024)
SIZES=(16 20 24 29 32 40 48 58 60 64 72 76 80 87 96 120 128 144 152 167 180 192 256 512 1024)

TOTAL=${#SIZES[@]}
COUNT=0

for size in "${SIZES[@]}"; do
    COUNT=$((COUNT + 1))
    TARGET_NAME="export_${size}x${size}.png"
    TARGET_PATH="$OUT_DIR/$TARGET_NAME"
    
    resize_image "$ICON_SRC" "$size" "$TARGET_PATH"
    echo -e " [${COUNT}/${TOTAL}] ${GREEN}✓ Generated:${NC} $TARGET_NAME (${size}x${size})"
done

# Also generate tray icon if applicable
if [ -d "$OUT_DIR" ]; then
    resize_image "$ICON_SRC" "32" "$OUT_DIR/tray_icon.png" 2>/dev/null || true
fi

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}    Successfully generated all icon resolutions!    ${NC}"
echo -e "${GREEN}====================================================${NC}"
ls -lh "$OUT_DIR"/export_*.png
echo ""
