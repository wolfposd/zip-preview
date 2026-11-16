#!/bin/sh
# Regenerates the archives in Tests/Fixtures using the system bsdtar and zip.
set -eu

cd "$(dirname "$0")/../Tests/Fixtures"
rm -f sample.zip sample.tar.gz sample.7z single.txt.gz corrupt.zip

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/project/src/deep/er" "$work/project/docs"
printf 'hello\n' > "$work/project/README.md"
printf 'print("hi")\n' > "$work/project/src/main.py"
head -c 4096 /dev/zero > "$work/project/src/deep/er/zeros.bin"
printf 'notes\n' > "$work/project/docs/notes.txt"
printf 'x\n' > "$work/project/docs/<b> & quote.txt"
mkdir -p "$work/__MACOSX/project"
printf 'junk' > "$work/__MACOSX/project/._README.md"

export COPYFILE_DISABLE=1
(cd "$work" && zip -qrX - project __MACOSX) > sample.zip
(cd "$work" && tar -czf - project) > sample.tar.gz
(cd "$work" && tar --format 7zip -cf - project) > sample.7z
printf 'just one file\n' | gzip -c > single.txt.gz
printf 'this is not an archive at all, just some text\n' > corrupt.zip

ls -l
