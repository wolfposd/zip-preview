#!/bin/sh
# Builds ZipPreview.app (Release) into build/.
# Usage: ./build.sh [--install]   --install copies it to ~/Applications and registers the extension.
set -eu

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
    echo "xcodegen not found. Install it with: brew install xcodegen" >&2
    exit 1
fi

xcodegen generate --quiet
xcodebuild -scheme ZipPreview -configuration Release -destination 'generic/platform=macOS' \
    -derivedDataPath build -quiet build

APP="build/Build/Products/Release/ZipPreview.app"
echo "Built $APP"

if [ "${1:-}" = "--install" ]; then
    DEST="$HOME/Applications/ZipPreview.app"
    LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    mkdir -p "$HOME/Applications"
    rm -rf "$DEST"
    cp -R "$APP" "$DEST"
    # Xcode's build outputs register themselves too; drop them so Quick Look uses the installed copy.
    for built in build/Build/Products/*/ZipPreview.app; do
        pluginkit -r "$built/Contents/PlugIns/ArchivePreviewExtension.appex" 2>/dev/null || true
        "$LSREGISTER" -u "$built" 2>/dev/null || true
    done
    pluginkit -a "$DEST/Contents/PlugIns/ArchivePreviewExtension.appex"
    qlmanage -r >/dev/null 2>&1
    echo "Installed to $DEST and reloaded Quick Look"
fi
