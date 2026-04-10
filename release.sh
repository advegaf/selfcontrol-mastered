#!/bin/bash
#
# release.sh — single-command DMG release pipeline for SelfControl Mastered.
#
# What it does:
#   1. Pre-flight checks (codesign identity, notary profile, required files)
#   2. Clean release build via xcodebuild (forces Developer ID signing)
#   3. Notarize + staple the .app
#   4. Generate the Nothing-aesthetic dark DMG background image
#   5. Stage and build a styled DMG (icon view, custom background, positioned icons)
#   6. Notarize + staple + verify the .dmg
#   7. Print final artifact path and SHA-256
#
# Requires:
#   * Xcode 17+ (xcodebuild, codesign, stapler, notarytool)
#   * "Developer ID Application: Angel Vega Figueroa (DV483F72N3)" in your keychain
#   * `xcrun notarytool store-credentials selfcontrol-notary` already configured
#   * macOS host (drawing the background uses AppKit; mounting requires hdiutil)
#
# Usage:  ./release.sh
#

set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────

readonly VERSION="1.0.2"
readonly VOLNAME="SelfControl ${VERSION}"
readonly DMG_NAME="SelfControl-${VERSION}.dmg"
readonly NOTARY_PROFILE="selfcontrol-notary"
readonly SIGN_IDENTITY="Developer ID Application: Angel Vega Figueroa (DV483F72N3)"
readonly TEAM_ID="DV483F72N3"

readonly PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"
readonly DIST="${PROJECT_ROOT}/dist"
readonly BUILD_DIR="${DIST}/build"
readonly STAGE_DIR="${DIST}/dmg-stage"

readonly APP_NAME="SelfControl.app"
readonly BUILT_APP="${BUILD_DIR}/Build/Products/Release/${APP_NAME}"
readonly STAGED_APP="${STAGE_DIR}/${APP_NAME}"
readonly BACKGROUND_PNG="${DIST}/dmg-background.png"

# Python with ds_store importable. (`pip3 install --user ds-store mac-alias`
# puts the modules in ~/Library/Python/3.9/lib/python/site-packages.)
readonly DSSTORE_PY="python3"
readonly DSSTORE_SITE="${HOME}/Library/Python/3.9/lib/python/site-packages"

readonly RW_DMG="${DIST}/SelfControl-${VERSION}-rw.dmg"
readonly FINAL_DMG="${DIST}/${DMG_NAME}"

# ─── Pretty logging ────────────────────────────────────────────────────────────

c_dim="\033[2m"
c_bold="\033[1m"
c_green="\033[32m"
c_red="\033[31m"
c_blue="\033[34m"
c_off="\033[0m"

step() { echo -e "\n${c_bold}${c_blue}==>${c_off} ${c_bold}$1${c_off}"; }
info() { echo -e "    ${c_dim}$1${c_off}"; }
ok()   { echo -e "    ${c_green}✓${c_off} $1"; }
die()  { echo -e "\n${c_red}error:${c_off} $1\n" >&2; exit 1; }

# ─── Pre-flight ────────────────────────────────────────────────────────────────

step "PRE-FLIGHT CHECKS"

[[ -f "${PROJECT_ROOT}/SelfControl.xcworkspace/contents.xcworkspacedata" ]] \
    || die "must run from the project root (no SelfControl.xcworkspace found)"
ok "project root: ${PROJECT_ROOT}"

security find-identity -v -p codesigning 2>/dev/null \
    | grep -q "${SIGN_IDENTITY}" \
    || die "signing identity not found: ${SIGN_IDENTITY}"
ok "codesign identity present"

xcrun notarytool history --keychain-profile "${NOTARY_PROFILE}" >/dev/null 2>&1 \
    || die "notarytool profile '${NOTARY_PROFILE}' not configured. Run: xcrun notarytool store-credentials ${NOTARY_PROFILE} --apple-id <id> --team-id ${TEAM_ID}"
ok "notarytool profile '${NOTARY_PROFILE}' present"

[[ -f "${PROJECT_ROOT}/Scripts/generate-dmg-background.swift" ]] || die "missing background generator"
command -v npx >/dev/null 2>&1 || die "npx not installed (brew install node)"
PYTHONPATH="${DSSTORE_SITE}" "${DSSTORE_PY}" -c "import ds_store" >/dev/null 2>&1 \
    || die "Python ds_store not installed (pip3 install --user ds-store mac-alias)"
ok "all release assets present"

# ─── Detect cached notarized app ───────────────────────────────────────────────
# If a previous run already produced a stapled .app, reuse it. Saves ~5-10 min
# of rebuild + notarize on the second iteration when only the DMG step changed.
# Force a fresh build with: REBUILD=1 ./release.sh

CACHED_APP=0
if [[ "${REBUILD:-0}" != "1" ]] \
   && [[ -d "${BUILT_APP}" ]] \
   && xcrun stapler validate "${BUILT_APP}" >/dev/null 2>&1; then
    CACHED_APP=1
    info "reusing cached notarized app at ${BUILT_APP}"
    info "(set REBUILD=1 to force a fresh build)"
fi

# ─── Clean ─────────────────────────────────────────────────────────────────────

step "CLEAN"

if [[ "${CACHED_APP}" -eq 1 ]]; then
    rm -rf "${STAGE_DIR}" "${RW_DMG}" "${FINAL_DMG}"
    ok "cleaned dmg-stage + *.dmg (kept build/)"
else
    rm -rf "${BUILD_DIR}" "${STAGE_DIR}" "${RW_DMG}" "${FINAL_DMG}"
    mkdir -p "${DIST}"
    ok "cleaned ${DIST}/{build,dmg-stage,*.dmg}"
fi

# Make sure no SelfControl is running locally; otherwise codesigning the daemon
# binary in /Applications can fail with "resource fork, Finder information, ..."
pkill -x SelfControl 2>/dev/null || true
pkill -x org.eyebeam.selfcontrold 2>/dev/null || true

# ─── Build (Release, Developer ID signed) ──────────────────────────────────────

if [[ "${CACHED_APP}" -eq 1 ]]; then
    step "BUILD (SKIPPED — using cached notarized app)"
else

step "BUILD (RELEASE)"
info "this can take a few minutes..."

xcodebuild \
    -workspace "${PROJECT_ROOT}/SelfControl.xcworkspace" \
    -scheme SelfControl \
    -configuration Release \
    -derivedDataPath "${BUILD_DIR}" \
    -destination 'generic/platform=macOS' \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGN_IDENTITY="Developer ID Application" \
    DEVELOPMENT_TEAM="${TEAM_ID}" \
    OTHER_CODE_SIGN_FLAGS="-o library,hard,kill,runtime --timestamp" \
    clean build 2>&1 \
    | tail -50

[[ -d "${BUILT_APP}" ]] || die "build did not produce ${BUILT_APP}"
ok "built ${BUILT_APP}"

# ─── Re-sign everything (strip get-task-allow, sign Sparkle, hardened runtime) ─

step "RE-SIGN ALL BINARIES"

# Xcode auto-injects com.apple.security.get-task-allow for non-archive builds
# even with Release config — that entitlement is invalid for notarization.
# Sparkle.framework also ships with binaries signed by a different team / no
# timestamp. The fix for both: re-sign every Mach-O binary inside the .app
# from inside-out using OUR Developer ID + hardened runtime + timestamp +
# our local entitlements file (which has no get-task-allow).

readonly ENTITLEMENTS="${PROJECT_ROOT}/SelfControl.entitlements"
readonly SPARKLE="${BUILT_APP}/Contents/Frameworks/Sparkle.framework"
readonly AUTOUPDATE="${SPARKLE}/Versions/A/Resources/Autoupdate.app"

sign_binary() {
    local bin="$1"
    local extra="${2:-}"
    [[ -e "$bin" ]] || { info "skip (not present): $bin"; return; }
    # shellcheck disable=SC2086
    codesign --force \
        --options runtime \
        --timestamp \
        --sign "${SIGN_IDENTITY}" \
        $extra \
        "$bin"
}

info "signing Sparkle nested binaries..."
sign_binary "${AUTOUPDATE}/Contents/MacOS/fileop"
sign_binary "${AUTOUPDATE}/Contents/MacOS/Autoupdate"
sign_binary "${AUTOUPDATE}"
# Sparkle XPC services (if any)
if [[ -d "${SPARKLE}/Versions/A/XPCServices" ]]; then
    while IFS= read -r -d '' xpc; do
        sign_binary "$xpc"
    done < <(find "${SPARKLE}/Versions/A/XPCServices" -name "*.xpc" -maxdepth 2 -print0)
fi
# The framework's primary binary
sign_binary "${SPARKLE}/Versions/A/Sparkle"
sign_binary "${SPARKLE}"

info "signing Pods framework..."
sign_binary "${BUILT_APP}/Contents/Frameworks/Pods_SelfControl.framework"

info "signing embedded helpers..."
sign_binary "${BUILT_APP}/Contents/MacOS/selfcontrol-cli"
sign_binary "${BUILT_APP}/Contents/MacOS/org.eyebeam.selfcontrold"
sign_binary "${BUILT_APP}/Contents/MacOS/SCKillerHelper"

info "signing main app (with entitlements)..."
sign_binary "${BUILT_APP}" "--entitlements ${ENTITLEMENTS}"

ok "re-signed all binaries with hardened runtime + timestamp"

# ─── Verify codesign ───────────────────────────────────────────────────────────

step "VERIFY CODESIGN"

codesign --verify --deep --strict --verbose=2 "${BUILT_APP}" 2>&1 | tail -10
ok "deep codesign verification passed"

codesign -dvv "${BUILT_APP}" 2>&1 | grep -E "Authority|TeamIdentifier|Identifier=" | sed 's/^/    /'

# Sanity check: ensure get-task-allow is NOT present on the main binary
if codesign -d --entitlements - "${BUILT_APP}" 2>/dev/null | grep -q "get-task-allow"; then
    die "main binary still has get-task-allow entitlement; notarization will fail"
fi
ok "no debug entitlements present"

# ─── Notarize + staple .app ────────────────────────────────────────────────────

step "NOTARIZE APP"

readonly NOTARY_ZIP="${DIST}/SelfControl-${VERSION}-notarize.zip"
rm -f "${NOTARY_ZIP}"
ditto -c -k --keepParent "${BUILT_APP}" "${NOTARY_ZIP}"
info "submitting ${NOTARY_ZIP} (~3-10 minutes)..."

# notarytool exits 0 on submission success even when Apple rejects the binary
# (status: Invalid). We capture the output, surface it, and require an
# "Accepted" status before proceeding.
notary_out=$(xcrun notarytool submit "${NOTARY_ZIP}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait 2>&1)
echo "${notary_out}" | sed 's/^/    /'

if ! echo "${notary_out}" | grep -q "status: Accepted"; then
    submission_id=$(echo "${notary_out}" | awk '/id:/ {print $2; exit}')
    if [[ -n "${submission_id}" ]]; then
        echo
        echo "    fetching rejection log for ${submission_id}..."
        xcrun notarytool log "${submission_id}" \
            --keychain-profile "${NOTARY_PROFILE}" 2>&1 | sed 's/^/    /'
    fi
    die "app notarization rejected by Apple"
fi

ok "app notarized (Accepted)"
rm -f "${NOTARY_ZIP}"

step "STAPLE APP"
xcrun stapler staple "${BUILT_APP}"
xcrun stapler validate "${BUILT_APP}"
ok "app stapled and validated"

fi  # end of cached-app gate

# ─── Generate background image ─────────────────────────────────────────────────

step "GENERATE DMG BACKGROUND"
# Render at 1320×800 raw pixels = 660×400 logical at @2x retina. The 144 DPI
# metadata is critical: without it, Finder treats the image as 1320×800 logical
# (way bigger than the 660×400 window) and crops the visible area.
swift "${PROJECT_ROOT}/Scripts/generate-dmg-background.swift" \
    "${PROJECT_ROOT}" \
    "${BACKGROUND_PNG}"
sips -s dpiHeight 144 -s dpiWidth 144 "${BACKGROUND_PNG}" >/dev/null
sips -s format tiff "${BACKGROUND_PNG}" --out "${DIST}/dmg-background.tiff" >/dev/null
sips -s dpiHeight 144 -s dpiWidth 144 "${DIST}/dmg-background.tiff" >/dev/null
ok "background: ${BACKGROUND_PNG} + dmg-background.tiff (660×400 @2x)"

# ─── Build the styled DMG ──────────────────────────────────────────────────────
# Two-phase approach:
#   1. sindresorhus/create-dmg via npx — produces a base DMG with a working
#      background image alias in the .DS_Store. This is the ONLY tool I found
#      whose backgrounds reliably render on macOS 26 Tahoe Finder. dmgbuild's
#      backgrounds are silently ignored, andreyvit/create-dmg uses the legacy
#      HFS-colon path syntax that no longer works.
#   2. Post-process: convert to R/W, mount, swap the background TIFF for our
#      custom Nothing-aesthetic image, rewrite the .DS_Store with our smaller
#      icon size and centered icon positions (preserving the working alias bytes
#      from the original .DS_Store), hide all dot-prefix files, unmount, and
#      compress back to UDZO.

step "BUILD DMG (sindresorhus/create-dmg + post-process)"

# Detach any leftover volume from a previous failed run
for vol in /Volumes/SelfControl /Volumes/SelfControl?*; do
    [[ -d "$vol" ]] && hdiutil detach "$vol" -force >/dev/null 2>&1 || true
done

# Phase 1: sindresorhus base DMG
readonly SINDRE_DMG="${DIST}/SelfControl ${VERSION}.dmg"
rm -f "${SINDRE_DMG}"
info "phase 1: sindresorhus/create-dmg via npx (downloads first run)..."
npx --yes create-dmg@latest \
    --no-code-sign \
    --overwrite \
    "${BUILT_APP}" \
    "${DIST}/" 2>&1 | sed 's/^/    /'

[[ -f "${SINDRE_DMG}" ]] || die "sindresorhus/create-dmg did not produce ${SINDRE_DMG}"
ok "sindresorhus base DMG built"

# Phase 2: post-process — swap background + rewrite .DS_Store
info "phase 2: post-process (swap background + rewrite .DS_Store)..."
hdiutil convert "${SINDRE_DMG}" -format UDRW -o "${RW_DMG}" >/dev/null
rm -f "${SINDRE_DMG}"
hdiutil attach -readwrite -noverify "${RW_DMG}" >/dev/null
readonly MOUNT_DIR="/Volumes/SelfControl"
[[ -d "${MOUNT_DIR}" ]] || die "expected mount at ${MOUNT_DIR} but it's missing"

# Swap the background TIFF with ours, and move it OUT of the .background/
# folder so the folder doesn't show up to Show-All-Files users. The Python
# block below regenerates the alias bytes for the new file location via
# `mac_alias.Alias.for_file()`.
cp "${DIST}/dmg-background.tiff" "${MOUNT_DIR}/.background/dmg-background.tiff"

# Rewrite .DS_Store: relocate the background to a single dot-prefix file at
# the volume root, regenerate the alias for the new path, recreate the
# .DS_Store from scratch (the ds_store library has a tree-traversal bug when
# updating existing entries on sindresorhus's layout, so write a fresh file).
PYTHONPATH="${DSSTORE_SITE}" "${DSSTORE_PY}" - "${MOUNT_DIR}" <<'PY'
import sys, os, shutil
from ds_store import DSStore
from mac_alias import Alias

mount = sys.argv[1]
ds_path = os.path.join(mount, '.DS_Store')
old_bg  = os.path.join(mount, '.background', 'dmg-background.tiff')
new_bg  = os.path.join(mount, '.bg.tiff')

# Move background to a flat dot-prefix file at the volume root, then drop
# the empty .background/ directory.
shutil.move(old_bg, new_bg)
try:
    os.rmdir(os.path.join(mount, '.background'))
except OSError as e:
    print(f"warning: could not rmdir .background: {e}", file=sys.stderr)

# Build a fresh alias bytes blob pointing at the new location.
new_alias = Alias.for_file(new_bg).to_bytes()
print(f"new alias: {len(new_alias)} bytes for {new_bg}")

# Write a fresh .DS_Store with our centered icon layout + the new alias.
os.remove(ds_path)
with DSStore.open(ds_path, 'w+') as ds:
    ds['.']['icvp'] = {
        'arrangeBy':           'none',
        'backgroundColorBlue':  0.0,
        'backgroundColorGreen': 0.0,
        'backgroundColorRed':   0.0,
        'backgroundImageAlias': new_alias,
        'backgroundType':       2,
        'gridOffsetX':          0.0,
        'gridOffsetY':          0.0,
        'gridSpacing':          100.0,
        'iconSize':             96.0,
        'labelOnBottom':        True,
        'scrollPositionX':      0.0,
        'scrollPositionY':      0.0,
        'showIconPreview':      False,
        'showItemInfo':         False,
        'textSize':             11.0,
        'viewOptionsVersion':   1,
    }
    ds['.']['bwsp'] = {
        'ContainerShowSidebar':  False,
        'PreviewPaneVisibility': False,
        'ShowPathbar':           False,
        'ShowSidebar':           False,
        'ShowStatusBar':         False,
        'ShowTabView':           False,
        'ShowToolbar':           False,
        'SidebarWidth':          0,
        'WindowBounds':          '{{200, 200}, {660, 422}}',
    }
    ds['.']['icvl'] = (b'type', b'icnv')
    # Centered two-icon row in the lower half of a 660×400 window.
    # cx = 330; icons 220px center-to-center, baseline y = 270.
    ds['SelfControl.app']['Iloc'] = (220, 270)
    ds['Applications']['Iloc']    = (440, 270)
print("rewrote .DS_Store with iconSize=96, positions={(220,270),(440,270)}")
PY

# Delete sindresorhus's custom volume icon (one fewer hidden file in the root)
rm -f "${MOUNT_DIR}/.VolumeIcon.icns"

# Hide remaining dot-prefix files for non-Show-All-Files users
for f in "${MOUNT_DIR}/.bg.tiff" "${MOUNT_DIR}/.DS_Store"; do
    [[ -e "$f" ]] && chflags hidden "$f" 2>/dev/null || true
done

# Last write before sync: nuke .fseventsd. macOS auto-creates this on every
# filesystem event, so we have to do it as the very last operation, then
# sync and detach immediately. The detach makes the volume read-only, which
# prevents any further fsevents from materializing.
rm -rf "${MOUNT_DIR}/.fseventsd"

sync; sync
hdiutil detach "${MOUNT_DIR}" >/dev/null \
    || hdiutil detach "${MOUNT_DIR}" -force >/dev/null

# Compress back to UDZO read-only
hdiutil convert "${RW_DMG}" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "${FINAL_DMG}" >/dev/null
rm -f "${RW_DMG}"
[[ -f "${FINAL_DMG}" ]] || die "hdiutil convert did not produce ${FINAL_DMG}"
ok "built ${FINAL_DMG}"

# ─── Sign the DMG ──────────────────────────────────────────────────────────────

step "SIGN DMG"

codesign --force --sign "${SIGN_IDENTITY}" \
    --options runtime \
    --timestamp \
    "${FINAL_DMG}"
codesign --verify --verbose=2 "${FINAL_DMG}" 2>&1 | tail -3
ok "DMG signed"

# ─── Notarize + staple DMG ─────────────────────────────────────────────────────

step "NOTARIZE DMG"
info "submitting ${FINAL_DMG} (~3-10 minutes)..."

dmg_notary_out=$(xcrun notarytool submit "${FINAL_DMG}" \
    --keychain-profile "${NOTARY_PROFILE}" \
    --wait 2>&1)
echo "${dmg_notary_out}" | sed 's/^/    /'

if ! echo "${dmg_notary_out}" | grep -q "status: Accepted"; then
    dmg_submission_id=$(echo "${dmg_notary_out}" | awk '/id:/ {print $2; exit}')
    if [[ -n "${dmg_submission_id}" ]]; then
        echo
        echo "    fetching rejection log for ${dmg_submission_id}..."
        xcrun notarytool log "${dmg_submission_id}" \
            --keychain-profile "${NOTARY_PROFILE}" 2>&1 | sed 's/^/    /'
    fi
    die "DMG notarization rejected by Apple"
fi
ok "DMG notarized (Accepted)"

step "STAPLE DMG"
xcrun stapler staple "${FINAL_DMG}"
xcrun stapler validate "${FINAL_DMG}"
ok "DMG stapled and validated"

# ─── Final verification ────────────────────────────────────────────────────────

step "GATEKEEPER ASSESSMENT"

spctl -a -vv -t install "${FINAL_DMG}" 2>&1 | sed 's/^/    /'

# ─── Summary ───────────────────────────────────────────────────────────────────

step "SUMMARY"

readonly FINAL_SIZE=$(ls -lh "${FINAL_DMG}" | awk '{print $5}')
readonly FINAL_SHA=$(shasum -a 256 "${FINAL_DMG}" | awk '{print $1}')

echo
echo -e "    ${c_bold}artifact${c_off}     ${FINAL_DMG}"
echo -e "    ${c_bold}version${c_off}      ${VERSION}"
echo -e "    ${c_bold}size${c_off}         ${FINAL_SIZE}"
echo -e "    ${c_bold}sha-256${c_off}      ${FINAL_SHA}"
echo
echo -e "${c_green}${c_bold}    ✓ READY FOR DISTRIBUTION${c_off}"
echo
