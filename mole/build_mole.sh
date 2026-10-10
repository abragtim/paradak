#!/bin/bash
# Builds the copy of Mole that ships inside Paradak.app (Contents/Resources/mole),
# so users need neither Homebrew nor a separately installed `mo`.
#
#   scripts/build_mole.sh            -> build/mole/ and build/mole-source/mole-<version>-source.tar.gz
#
# Needs Go (brew install go) on the build machine only. The Mole release is pinned
# below and checked against its SHA-256 (same values as the Homebrew formula).
# After changing the version, update MoClient.testedVersion and the fixtures.
set -euo pipefail

MOLE_VERSION="1.57.0"
MOLE_SHA256="d5bc2b79c985cd539cbe8b78fd19fec7f8da2083eeaaffdb8d8f52b8565113b4"
MOLE_URL="https://github.com/tw93/Mole/archive/refs/tags/V${MOLE_VERSION}.tar.gz"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="$ROOT/build/mole-src"
OUT="$ROOT/build/mole"
TARBALL="$WORK/V${MOLE_VERSION}.tar.gz"
SRC="$WORK/Mole-${MOLE_VERSION}"

command -v go > /dev/null || { echo "Go is required: brew install go" >&2; exit 1; }

mkdir -p "$WORK"
if [[ ! -f "$TARBALL" ]]; then
    echo "Downloading Mole ${MOLE_VERSION}"
    curl -fsSL -o "$TARBALL.part" "$MOLE_URL"
    mv "$TARBALL.part" "$TARBALL"
fi
echo "${MOLE_SHA256}  ${TARBALL}" | shasum -a 256 -c - > /dev/null \
    || { echo "SHA-256 mismatch for $TARBALL" >&2; rm -f "$TARBALL"; exit 1; }

rm -rf "$SRC"
tar -xzf "$TARBALL" -C "$WORK"

# Only `mo analyze` needs a compiled helper (bin/analyze-go). It is pure Go, so one
# universal binary covers Apple Silicon and Intel. `mo status` is not used by Paradak.
echo "Building analyze-go (arm64 + x86_64)"
LDFLAGS="-s -w -X main.Version=${MOLE_VERSION}"
for arch in arm64 amd64; do
    (cd "$SRC" && CGO_ENABLED=0 GOOS=darwin GOARCH="$arch" GOTOOLCHAIN=local \
        go build -trimpath -ldflags "$LDFLAGS" -o "$WORK/analyze-go-$arch" ./cmd/analyze)
done

rm -rf "$OUT"
mkdir -p "$OUT/bin"
cp "$SRC/mole" "$OUT/mole"
cp -R "$SRC/lib" "$OUT/lib"
cp "$SRC"/bin/*.sh "$OUT/bin/"
cp "$SRC/LICENSE" "$OUT/LICENSE"
lipo -create -output "$OUT/bin/analyze-go" "$WORK/analyze-go-arm64" "$WORK/analyze-go-amd64"
chmod +x "$OUT/mole" "$OUT"/bin/*.sh "$OUT/bin/analyze-go"
# Apple Silicon refuses unsigned binaries; an ad-hoc signature is enough.
codesign --force --sign - "$OUT/bin/analyze-go"

# Licence notices of the Go libraries compiled into analyze-go (MIT/BSD require them in binary copies).
{
    echo "Third-party software in bin/analyze-go (built from Mole ${MOLE_VERSION}, cmd/analyze)."
    echo "Mole itself is GPL-3.0-or-later, see LICENSE."
    (cd "$SRC" && GOTOOLCHAIN=local go list -deps -f '{{if and .Module (not .Standard)}}{{.Module.Path}}@{{.Module.Version}} {{.Module.Dir}}{{end}}' ./cmd/analyze) \
        | sort -u | while read -r module dir; do
            [[ "$module" == github.com/tw93/mole@* ]] && continue
            license="$(ls "$dir" 2> /dev/null | grep -iE '^(licen[cs]e|copying)' | head -1 || true)"
            printf '\n==============================================================================\n%s\n\n' "$module"
            if [[ -n "$license" ]]; then cat "$dir/$license"; else echo "(no licence file found in module)"; fi
        done
} > "$OUT/THIRD_PARTY_NOTICES.txt"
grep -q "no licence file found" "$OUT/THIRD_PARTY_NOTICES.txt" && { echo "Missing licence for a Go module" >&2; exit 1; }

cat > "$OUT/SOURCE.txt" << EOF
Mole ${MOLE_VERSION} by tw93, GPL-3.0-or-later (see LICENSE).
Source: https://github.com/tw93/Mole/tree/V${MOLE_VERSION}
Built from ${MOLE_URL} (sha256 ${MOLE_SHA256}); bin/analyze-go built from cmd/analyze.
EOF

# Corresponding Source for the GPL: the Mole release plus every Go module compiled into
# analyze-go (vendored), and this script, which shows how it was built. Attached to each release.
SOURCE_OUT="$ROOT/build/mole-source"
rm -rf "$SOURCE_OUT" && mkdir -p "$SOURCE_OUT/Mole-${MOLE_VERSION}"
cp -R "$SRC/." "$SOURCE_OUT/Mole-${MOLE_VERSION}/"
(cd "$SOURCE_OUT/Mole-${MOLE_VERSION}" && GOTOOLCHAIN=local go mod vendor)
cp "$0" "$SOURCE_OUT/Mole-${MOLE_VERSION}/PARADAK_BUILD_MOLE.sh"
tar -czf "$SOURCE_OUT/mole-${MOLE_VERSION}-source.tar.gz" -C "$SOURCE_OUT" "Mole-${MOLE_VERSION}"
rm -rf "$SOURCE_OUT/Mole-${MOLE_VERSION}"

"$OUT/mole" --version | head -1
lipo -archs "$OUT/bin/analyze-go"
echo "-> $OUT ($(du -sh "$OUT" | cut -f1))"
