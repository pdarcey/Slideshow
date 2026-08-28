#!/bin/bash
set -e

############################################################
# NOTE: IMPORTANT
#
# If this script fails to run successfully, and gives an
# error that "No git repository found at SRCROOT", it means
# User Script Sandboxing is blocking git access.
#
# Go to Build Settings and set User Script Sandboxing to NO.
############################################################

GIT="git -C \"$SRCROOT\""

# Verify git repo exists
if ! eval $GIT rev-parse --git-dir >/dev/null 2>&1; then
    echo "Error: No git repository found at SRCROOT: $SRCROOT"
    exit 1
fi

echo "Git repo detected at: $SRCROOT"

############################################################
# BUILD NUMBER = commit count on main (no fallback - fail
# clearly if main isn't available locally)
############################################################
if ! eval $GIT rev-parse --verify main >/dev/null 2>&1; then
    echo "Error: 'main' branch not found locally. Fetch/check out main before building."
    exit 1
fi

BUILD_NUMBER=$(eval $GIT rev-list --count main)

echo "Build number = $BUILD_NUMBER"

############################################################
# Update CFBundleVersion in the active platform's Info.plist
# (MARKETING_VERSION / CFBundleShortVersionString is left
# untouched - that stays manually managed)
#
# GENERATE_INFOPLIST_FILE=YES for this target, so this must
# patch the already-generated Info.plist in the built
# product, not the source template at
# $SRCROOT/$INFOPLIST_FILE - build settings are fully
# resolved before any script phase runs, so a script can't
# influence generation itself regardless of phase ordering.
############################################################
PLIST_PATH="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"

if [ ! -f "$PLIST_PATH" ]; then
    echo "Error: Info.plist not found at: $PLIST_PATH"
    exit 1
fi

echo "Updating Info.plist at: $PLIST_PATH"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD_NUMBER" "$PLIST_PATH"

echo "Done."
