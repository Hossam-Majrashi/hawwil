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

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BLUE}====================================================${NC}"
echo -e "${BLUE}    Universal Flatpak Packaging Script              ${NC}"
echo -e "${BLUE}====================================================${NC}"

# Package Manager Detection & Dependency Helper
detect_pkg_manager() {
    if command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    elif command -v apt-get &> /dev/null; then
        echo "apt"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

install_system_deps() {
    local pm=$(detect_pkg_manager)
    echo -e "${BLUE}==> Detected system package manager:${NC} ${BOLD}$pm${NC}"
    case "$pm" in
        dnf)
            echo -e "${CYAN}Installing Flatpak and build dependencies via DNF (Fedora / RHEL 8+ / Rocky / Alma)...${NC}"
            sudo dnf install -y clang cmake ninja-build pkgconf-pkg-config gtk3-devel flatpak flatpak-builder
            ;;
        yum)
            echo -e "${CYAN}Installing Flatpak and build dependencies via YUM (RHEL / CentOS 7 / Amazon Linux)...${NC}"
            sudo yum install -y clang cmake3 ninja-build pkgconfig gtk3-devel flatpak flatpak-builder
            ;;
        zypper)
            echo -e "${CYAN}Installing Flatpak and build dependencies via ZYPPER (openSUSE / SLES)...${NC}"
            sudo zypper install -y clang cmake ninja pkg-config gtk3-devel flatpak flatpak-builder
            ;;
        apt)
            echo -e "${CYAN}Installing Flatpak and build dependencies via APT (Debian / Ubuntu / Mint)...${NC}"
            sudo apt-get update && sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev flatpak flatpak-builder
            ;;
        pacman)
            echo -e "${CYAN}Installing Flatpak and build dependencies via PACMAN (Arch Linux / Manjaro)...${NC}"
            sudo pacman -S --needed --noconfirm clang cmake ninja pkgconf gtk3 flatpak flatpak-builder
            ;;
        *)
            echo -e "${YELLOW}Notice: Please ensure 'flatpak' and build tools are installed on your system.${NC}"
            ;;
    esac
    echo -e "${GREEN}✓ Dependencies installation complete.${NC}\n"
}

if [[ "$1" == "--install-deps" || "$1" == "-i" || "$1" == "--deps" ]]; then
    install_system_deps
fi

# 1. Parse pubspec.yaml for Name, Version, Description
if [ ! -f "pubspec.yaml" ]; then
    echo -e "${RED}Error: pubspec.yaml not found in project root ($PROJECT_ROOT).${NC}"
    exit 1
fi

APP_NAME=$(grep '^name:' pubspec.yaml | head -n 1 | awk '{print $2}' | tr -d '"' | tr -d "'")
FULL_VERSION=$(grep '^version:' pubspec.yaml | head -n 1 | awk '{print $2}' | tr -d '"' | tr -d "'")
VERSION=$(echo "$FULL_VERSION" | cut -d'+' -f1)
DESCRIPTION=$(grep '^description:' pubspec.yaml | head -n 1 | cut -d':' -f2- | sed 's/^[ \t]*//' | tr -d '"' | tr -d "'")

if [ -z "$APP_NAME" ]; then APP_NAME="$(basename "$PROJECT_ROOT")"; fi
if [ -z "$VERSION" ]; then VERSION="1.0.0"; fi
if [ -z "$DESCRIPTION" ]; then DESCRIPTION="Flutter Linux Application"; fi

FLATPAK_DIR="$(pwd)/flatpak"
mkdir -p "$FLATPAK_DIR"

# Determine Flatpak ID dynamically
FLATPAK_ID=""
if ls "$FLATPAK_DIR"/*.json 1> /dev/null 2>&1; then
    FIRST_JSON=$(ls "$FLATPAK_DIR"/*.json | head -n 1)
    FLATPAK_ID=$(grep '"app-id":' "$FIRST_JSON" | head -n 1 | awk -F'"' '{print $4}')
fi

if [ -z "$FLATPAK_ID" ]; then
    FLATPAK_ID="com.h.hawwil"
fi

FLATPAK_NAME="${APP_NAME}_${VERSION}_x86_64.flatpak"
RUNTIME_VER="24.08"

echo -e "${GREEN}Project Root:${NC}   $PROJECT_ROOT"
echo -e "${GREEN}App Name:${NC}       $APP_NAME"
echo -e "${GREEN}Version:${NC}        $VERSION"
echo -e "${GREEN}Summary:${NC}        $DESCRIPTION"
echo -e "${GREEN}Flatpak ID:${NC}     $FLATPAK_ID"
echo -e "${GREEN}Flatpak Config:${NC} $FLATPAK_DIR"
echo ""

# 2. Check Flutter Build
BUNDLE_DIR="build/linux/x64/release/bundle"

# If flutter is not in current PATH (e.g. running under sudo), search common user locations
if ! command -v flutter &> /dev/null; then
    if [ -n "$SUDO_USER" ] && [ -x "/home/$SUDO_USER/flutter/bin/flutter" ]; then
        export PATH="/home/$SUDO_USER/flutter/bin:$PATH"
    elif [ -x "$HOME/flutter/bin/flutter" ]; then
        export PATH="$HOME/flutter/bin:$PATH"
    elif [ -x "/opt/flutter/bin/flutter" ]; then
        export PATH="/opt/flutter/bin:$PATH"
    fi
fi

if [ ! -d "$BUNDLE_DIR" ]; then
    echo -e "${BLUE}==> Building Flutter Linux Release...${NC}"
    if ! command -v flutter &> /dev/null; then
        echo -e "${RED}Error: 'flutter' command not found in PATH.${NC}"
        exit 1
    fi
    flutter build linux
fi

if [ ! -d "$BUNDLE_DIR" ]; then
    echo -e "${RED}Error: Bundle directory $BUNDLE_DIR does not exist.${NC}"
    exit 1
fi

# 3. Create Output, Flatpak directory and Temp Directories
DIST_DIR="$(pwd)/dist"
mkdir -p "$DIST_DIR"

BUILD_TMP="/tmp/${APP_NAME}_flatpak_builder"
rm -rf "$BUILD_TMP"
STAGE_DIR="$BUILD_TMP/stage"
mkdir -p "$STAGE_DIR/files/bin"
mkdir -p "$STAGE_DIR/files/lib/$APP_NAME/lib"
mkdir -p "$STAGE_DIR/files/share/applications"
mkdir -p "$STAGE_DIR/files/share/metainfo"

# Icon directories
for res in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
    mkdir -p "$STAGE_DIR/files/share/icons/hicolor/$res/apps"
done

# 4. Copy Bundle & Include Plugin Shared Library Dependencies
echo -e "${BLUE}==> Staging Flatpak Files & Plugin Libraries...${NC}"
cp -r "$BUNDLE_DIR"/* "$STAGE_DIR/files/lib/$APP_NAME/"

# Bundle appindicator and dbusmenu shared libraries for system_tray plugin support
BUNDLE_LIB_DIR="$STAGE_DIR/files/lib/$APP_NAME/lib"
LIB_SEARCH_PATHS=(
    "/usr/lib"
    "/usr/lib64"
    "/usr/lib/x86_64-linux-gnu"
    "/lib"
    "/lib64"
    "/lib/x86_64-linux-gnu"
)
TARGET_LIBS=(
    "libappindicator3.so*"
    "libayatana-appindicator3.so*"
    "libdbusmenu-glib.so*"
    "libdbusmenu-gtk3.so*"
    "libindicator3.so*"
)

for lib_pattern in "${TARGET_LIBS[@]}"; do
    for search_dir in "${LIB_SEARCH_PATHS[@]}"; do
        if [ -d "$search_dir" ]; then
            find "$search_dir" -maxdepth 1 -name "$lib_pattern" 2>/dev/null | while read -r lib_file; do
                if [ -f "$lib_file" ] || [ -L "$lib_file" ]; then
                    cp -L "$lib_file" "$BUNDLE_LIB_DIR/" 2>/dev/null || true
                fi
            done
        fi
    done
done

# Binary launcher script with explicit LD_LIBRARY_PATH
cat << EOF > "$STAGE_DIR/files/bin/$APP_NAME"
#!/bin/sh
export LD_LIBRARY_PATH="/app/lib/$APP_NAME/lib:/app/lib/$APP_NAME:\$LD_LIBRARY_PATH"
exec /app/lib/$APP_NAME/$APP_NAME "\$@"
EOF
chmod +x "$STAGE_DIR/files/bin/$APP_NAME"

# Desktop entry
cat << EOF > "$STAGE_DIR/files/share/applications/$FLATPAK_ID.desktop"
[Desktop Entry]
Name=$APP_NAME
Comment=$DESCRIPTION
Exec=$APP_NAME
Icon=$FLATPAK_ID
Terminal=false
Type=Application
Categories=Graphics;Design;Development;Utility;
EOF

# Copy Icons matching expected resolution sizes
for res in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
    if [ -f "assets/icon/export_${res}.png" ]; then
        cp "assets/icon/export_${res}.png" "$STAGE_DIR/files/share/icons/hicolor/$res/apps/$FLATPAK_ID.png"
    elif [ -f "assets/icons/export_${res}.png" ]; then
        cp "assets/icons/export_${res}.png" "$STAGE_DIR/files/share/icons/hicolor/$res/apps/$FLATPAK_ID.png"
    fi
done

# Fallback 512 icon
ICON_SRC=""
if [ -f "assets/icon/export_512x512.png" ]; then
    ICON_SRC="assets/icon/export_512x512.png"
elif [ -f "assets/icons/export_512x512.png" ]; then
    ICON_SRC="assets/icons/export_512x512.png"
elif [ -f "assets/icon/app_icon.png" ]; then
    ICON_SRC="assets/icon/app_icon.png"
elif [ -f "assets/icons/app_icon.png" ]; then
    ICON_SRC="assets/icons/app_icon.png"
elif [ -f "assets/app_icon.png" ]; then
    ICON_SRC="assets/app_icon.png"
elif [ -f "linux/flutter/icon.png" ]; then
    ICON_SRC="linux/flutter/icon.png"
fi

if [ ! -f "$STAGE_DIR/files/share/icons/hicolor/512x512/apps/$FLATPAK_ID.png" ] && [ -n "$ICON_SRC" ]; then
    cp "$ICON_SRC" "$STAGE_DIR/files/share/icons/hicolor/512x512/apps/$FLATPAK_ID.png"
fi

# Ensure AppStream Metadata exists in flatpak/ directory
if [ -f "$FLATPAK_DIR/$FLATPAK_ID.metainfo.xml" ]; then
    cp "$FLATPAK_DIR/$FLATPAK_ID.metainfo.xml" "$STAGE_DIR/files/share/metainfo/$FLATPAK_ID.metainfo.xml"
elif [ -f "$FLATPAK_DIR/metainfo.xml" ]; then
    cp "$FLATPAK_DIR/metainfo.xml" "$STAGE_DIR/files/share/metainfo/$FLATPAK_ID.metainfo.xml"
else
    cat << EOF > "$FLATPAK_DIR/$FLATPAK_ID.metainfo.xml"
<?xml version="1.0" encoding="UTF-8"?>
<component type="desktop-application">
  <id>$FLATPAK_ID</id>
  <metadata_license>CC0-1.0</metadata_license>
  <project_license>MIT</project_license>
  <name>$APP_NAME</name>
  <summary>$DESCRIPTION</summary>
  <description>
    <p>$DESCRIPTION</p>
  </description>
  <launchable type="desktop-id">$FLATPAK_ID.desktop</launchable>
  <provides>
    <binary>$APP_NAME</binary>
  </provides>
</component>
EOF
    cp "$FLATPAK_DIR/$FLATPAK_ID.metainfo.xml" "$STAGE_DIR/files/share/metainfo/$FLATPAK_ID.metainfo.xml"
    cp "$FLATPAK_DIR/$FLATPAK_ID.metainfo.xml" "$FLATPAK_DIR/metainfo.xml"
fi

# Flatpak metadata
cat << EOF > "$STAGE_DIR/metadata"
[Application]
name=$FLATPAK_ID
runtime=org.freedesktop.Platform/x86_64/$RUNTIME_VER
sdk=org.freedesktop.Sdk/x86_64/$RUNTIME_VER
command=$APP_NAME
EOF

# Ensure Flatpak JSON Manifest exists in flatpak/ directory
if [ ! -f "$FLATPAK_DIR/$FLATPAK_ID.json" ] && [ ! -f "$FLATPAK_DIR/flatpak.json" ]; then
    cat << EOF > "$FLATPAK_DIR/$FLATPAK_ID.json"
{
  "app-id": "$FLATPAK_ID",
  "runtime": "org.freedesktop.Platform",
  "runtime-version": "$RUNTIME_VER",
  "sdk": "org.freedesktop.Sdk",
  "command": "$APP_NAME",
  "finish-args": [
    "--share=ipc",
    "--socket=fallback-x11",
    "--socket=wayland",
    "--socket=x11",
    "--socket=pulseaudio",
    "--device=dri",
    "--filesystem=host",
    "--filesystem=home"
  ],
  "modules": [
    {
      "name": "$APP_NAME",
      "buildsystem": "simple",
      "build-commands": [
        "mkdir -p /app/bin /app/lib/$APP_NAME /app/share/applications /app/share/icons/hicolor/512x512/apps /app/share/metainfo",
        "cp -r * /app/lib/$APP_NAME/",
        "ln -s /app/lib/$APP_NAME/$APP_NAME /app/bin/$APP_NAME",
        "install -D -m 644 $FLATPAK_ID.desktop /app/share/applications/$FLATPAK_ID.desktop",
        "install -D -m 644 $FLATPAK_ID.png /app/share/icons/hicolor/512x512/apps/$FLATPAK_ID.png",
        "install -D -m 644 $FLATPAK_ID.metainfo.xml /app/share/metainfo/$FLATPAK_ID.metainfo.xml"
      ]
    }
  ]
}
EOF
fi

# Copy manifest to dist
if [ -f "$FLATPAK_DIR/$FLATPAK_ID.json" ]; then
    cp "$FLATPAK_DIR/$FLATPAK_ID.json" "$DIST_DIR/$FLATPAK_ID.json"
fi

# 5. Build and Export Flatpak Bundle
echo -e "${BLUE}==> Building Flatpak Bundle...${NC}"
if command -v flatpak &> /dev/null; then
    flatpak build-finish "$STAGE_DIR" \
        --command="$APP_NAME" \
        --share=ipc \
        --socket=fallback-x11 \
        --socket=wayland \
        --socket=x11 \
        --socket=pulseaudio \
        --device=dri \
        --filesystem=host \
        --filesystem=home > /dev/null

    REPO_DIR="$BUILD_TMP/repo"
    flatpak build-export "$REPO_DIR" "$STAGE_DIR" > /dev/null
    flatpak build-bundle "$REPO_DIR" "$DIST_DIR/$FLATPAK_NAME" "$FLATPAK_ID" > /dev/null
    echo -e "${GREEN}✓ Created $DIST_DIR/$FLATPAK_NAME${NC}"
else
    echo -e "${YELLOW}Notice: 'flatpak' tool not found. Packaging standalone tarball for Flatpak...${NC}"
    tar czf "$DIST_DIR/$FLATPAK_NAME" -C "$STAGE_DIR" .
    echo -e "${GREEN}✓ Created $DIST_DIR/$FLATPAK_NAME${NC}"
fi

# Cleanup
rm -rf "$BUILD_TMP"

echo -e "\n${GREEN}====================================================${NC}"
echo -e "${GREEN}    Flatpak Build Complete:                        ${NC}"
echo -e "${GREEN}====================================================${NC}"
ls -lh "$DIST_DIR/$FLATPAK_NAME"
echo ""
echo -e "${CYAN}Flatpak Sources in flatpak/:${NC}"
ls -lh "$FLATPAK_DIR"
echo ""
