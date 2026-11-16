# ZipPreview

A Quick Look extension for macOS: select an archive in Finder, press **Space**, and see its contents as a collapsible folder tree with sizes and modification dates.

Supports everything the system libarchive can read: zip/jar, tar, tar.gz/bz2/xz, 7z, rar, iso, cpio, xar, plus single compressed files (`.gz`, `.bz2`, `.xz`). Only entry headers are read; nothing is extracted.

## Build & install

```sh
brew install xcodegen      # once
./build.sh                 # build only → build/Build/Products/Release/ZipPreview.app
./build.sh --install       # build, copy to ~/Applications, register the extension, reload Quick Look
```

If Finder still shows the default preview, enable **Archive Preview** in System Settings ▸ General ▸ Login Items & Extensions ▸ Quick Look.

The build is ad-hoc signed ("Sign to Run Locally"). To share it with others, set `DEVELOPMENT_TEAM` in `project.yml`, sign with a Developer ID, and notarize.

## Layout

- `App/` – minimal host app (required to ship an extension)
- `Extension/` – the Quick Look preview extension (`PreviewProvider` returns HTML)
- `Core/` – `ArchiveReader` (libarchive wrapper), `EntryTree`, `HTMLRenderer`; `Core/CArchive` declares the libarchive functions used, because the macOS SDK ships the library without headers
- `Tests/` – unit tests; `scripts/make-fixtures.sh` regenerates `Tests/Fixtures`

```sh
xcodebuild -scheme ZipPreview -derivedDataPath build test
```
