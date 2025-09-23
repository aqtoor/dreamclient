#!/bin/bash
set -e

# infinidream App Build Script (Step 3)
# Takes the notarized screensaver from Step 2, embeds it in the app,
# builds the app, and notarizes it using Xcode credentials

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT="infinidream.xcodeproj"
BUILD_CONFIG="Release"
APP_SCHEME="infinidream App Prod"
APP_NAME="infinidream.app"
SCREENSAVER_NAME="infinidream.saver"
BUILD_DIR="build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
PRODUCTS_DIR="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}"
KEYCHAIN_PROFILE="infinidream-notarization"

# Parse command line arguments
SKIP_NOTARIZATION=false
while getopts "sp:" opt; do
    case ${opt} in
        s )
            SKIP_NOTARIZATION=true
            ;;
        p )
            KEYCHAIN_PROFILE="$OPTARG"
            ;;
        \? )
            echo "Usage: $0 [-s] [-p keychain_profile]"
            echo "  -s : Skip app notarization (for testing)"
            echo "  -p : Keychain profile name (default: infinidream-notarization)"
            exit 1
            ;;
    esac
done

# Display configuration
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}infinidream App Build with Screensaver (Step 3)${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Configuration: ${BUILD_CONFIG}"
echo -e "Scheme: ${APP_SCHEME}"
echo -e "Notarization: $([ "$SKIP_NOTARIZATION" = false ] && echo "Enabled" || echo "Skipped")"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if notarized screensaver exists
if [ ! -d "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" ]; then
    echo -e "${RED}Error: Notarized screensaver not found at ${PRODUCTS_DIR}/${SCREENSAVER_NAME}${NC}"
    echo -e "${RED}Please run ./build_screensaver.sh and ./notarize_screensaver.sh first${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Found notarized screensaver${NC}"

# Save the screensaver to a temporary location before cleaning
TEMP_SAVER_DIR="${BUILD_DIR}/temp_saver"
mkdir -p "$TEMP_SAVER_DIR"
echo -e "${YELLOW}Preserving notarized screensaver...${NC}"
cp -R "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" "${TEMP_SAVER_DIR}/${SCREENSAVER_NAME}"

# Build app
echo -e "${YELLOW}Building app (${APP_SCHEME})...${NC}"

xcodebuild -project "$PROJECT" \
           -scheme "$APP_SCHEME" \
           -configuration "$BUILD_CONFIG" \
           -derivedDataPath "$DERIVED_DATA" \
           OTHER_CODE_SIGN_FLAGS="--timestamp" \
           clean build \
           | xcpretty --color || {
    # Fallback if xcpretty is not installed
    xcodebuild -project "$PROJECT" \
               -scheme "$APP_SCHEME" \
               -configuration "$BUILD_CONFIG" \
               -derivedDataPath "$DERIVED_DATA" \
               OTHER_CODE_SIGN_FLAGS="--timestamp" \
               clean build
}

# Verify app build
if [ ! -d "${PRODUCTS_DIR}/${APP_NAME}" ]; then
    echo -e "${RED}Failed to build ${APP_NAME}${NC}"
    rm -rf "$TEMP_SAVER_DIR"
    exit 1
fi

echo -e "${GREEN}✓ ${APP_NAME} built successfully${NC}"

# Embed notarized screensaver into app bundle
echo -e "${YELLOW}Embedding notarized screensaver into app bundle...${NC}"
APP_RESOURCES="${PRODUCTS_DIR}/${APP_NAME}/Contents/Resources"

mkdir -p "$APP_RESOURCES"
cp -R "${TEMP_SAVER_DIR}/${SCREENSAVER_NAME}" "$APP_RESOURCES/${SCREENSAVER_NAME}"

# Clean up temporary directory
rm -rf "$TEMP_SAVER_DIR"

# Verify embedded screensaver
if [ -d "${APP_RESOURCES}/${SCREENSAVER_NAME}" ]; then
    echo -e "${GREEN}✓ Notarized screensaver successfully embedded${NC}"
else
    echo -e "${RED}Error: Failed to embed screensaver in app bundle${NC}"
    exit 1
fi

# Re-sign the app after embedding the screensaver
echo -e "${YELLOW}Re-signing app bundle with embedded screensaver...${NC}"
codesign --force --deep --timestamp --sign - "${PRODUCTS_DIR}/${APP_NAME}"

# Notarize app (unless skipped)
if [ "$SKIP_NOTARIZATION" = false ]; then
    echo -e "${YELLOW}Notarizing app...${NC}"

    # Create a zip for app notarization
    echo -e "${YELLOW}Creating zip of app for notarization...${NC}"
    APP_ZIP="${BUILD_DIR}/${BUILD_CONFIG}/app.zip"
    ditto -c -k --keepParent "${PRODUCTS_DIR}/${APP_NAME}" "${APP_ZIP}"

    # Submit app for notarization
    echo -e "${YELLOW}Submitting app to Apple for notarization...${NC}"
    echo -e "${YELLOW}This may take several minutes...${NC}"

    # Capture notarization output
    NOTARY_OUTPUT=$(xcrun notarytool submit "${APP_ZIP}" \
                     --keychain-profile "${KEYCHAIN_PROFILE}" \
                     --wait 2>&1)

    # Display the output
    echo "$NOTARY_OUTPUT"

    # Extract submission ID
    SUBMISSION_ID=$(echo "$NOTARY_OUTPUT" | grep -E "id: [a-f0-9-]+" | head -1 | awk '{print $2}')

    # Check for invalid or rejected status
    if echo "$NOTARY_OUTPUT" | grep -q "status: Invalid\|status: Rejected"; then
        echo ""
        echo -e "${RED}✗ App notarization failed - Status: Invalid/Rejected${NC}"
        echo ""
        if [ -n "$SUBMISSION_ID" ]; then
            echo "Submission ID: ${SUBMISSION_ID}"
            echo ""
            echo "To see why notarization failed, run:"
            echo "  xcrun notarytool log ${SUBMISSION_ID} --keychain-profile '${KEYCHAIN_PROFILE}'"
            echo ""
        fi
        echo "Common issues:"
        echo "- Missing code signature"
        echo "- Invalid or expired certificate"
        echo "- Unsigned binaries in the bundle"
        echo "- Missing entitlements"
        echo "- Embedded screensaver not properly signed"
        echo ""
        echo "The app has been built at: ${PRODUCTS_DIR}/${APP_NAME}"
        echo "To retry notarization after fixing issues:"
        echo "1. ditto -c -k --keepParent '${PRODUCTS_DIR}/${APP_NAME}' '${APP_ZIP}'"
        echo "2. xcrun notarytool submit '${APP_ZIP}' --keychain-profile '${KEYCHAIN_PROFILE}' --wait"
        echo "3. xcrun stapler staple '${PRODUCTS_DIR}/${APP_NAME}'"
        rm "${APP_ZIP}"
        exit 1
    fi

    # Check if submission failed entirely
    if ! echo "$NOTARY_OUTPUT" | grep -q "status: Accepted"; then
        echo ""
        echo -e "${RED}✗ App notarization failed${NC}"
        echo ""
        echo "The app has been built but notarization failed."
        echo "You can try notarizing manually or check your credentials."
        echo ""
        echo "To notarize manually:"
        echo "1. xcrun notarytool submit '${APP_ZIP}' --keychain-profile '${KEYCHAIN_PROFILE}' --wait"
        echo "2. xcrun stapler staple '${PRODUCTS_DIR}/${APP_NAME}'"
        rm "${APP_ZIP}"
        exit 1
    fi

    echo -e "${GREEN}✓ App notarization successful${NC}"

    # Staple the notarization ticket to app
    echo -e "${YELLOW}Stapling notarization ticket to app...${NC}"
    if ! xcrun stapler staple "${PRODUCTS_DIR}/${APP_NAME}"; then
        echo -e "${RED}✗ Failed to staple notarization ticket to app${NC}"
        echo "The app was notarized but stapling failed."
        echo "Users will need internet access to verify the app on first launch."
    else
        echo -e "${GREEN}✓ Notarization ticket stapled successfully${NC}"
    fi

    # Clean up app zip
    rm "${APP_ZIP}"

    # Verify notarization
    echo -e "${YELLOW}Verifying app notarization...${NC}"
    if spctl --assess --type execute -vvv "${PRODUCTS_DIR}/${APP_NAME}" 2>&1 | grep -q "accepted"; then
        echo -e "${GREEN}✓ App notarization verification passed${NC}"
    else
        echo -e "${YELLOW}⚠ Could not fully verify notarization (app may still be valid)${NC}"
    fi
fi

# Create distribution ZIP if everything succeeded
FINAL_ZIP="${BUILD_DIR}/${BUILD_CONFIG}/infinidream-$(date +%Y%m%d).zip"
echo -e "${YELLOW}Creating final distribution package...${NC}"
ditto -c -k --keepParent "${PRODUCTS_DIR}/${APP_NAME}" "${FINAL_ZIP}"

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Application: ${PRODUCTS_DIR}/${APP_NAME}"
echo "  └── Embedded: ${APP_RESOURCES}/${SCREENSAVER_NAME}"
if [ "$SKIP_NOTARIZATION" = false ]; then
    echo "Notarization: ✓ Complete"
fi
echo ""
echo "Distribution package: ${FINAL_ZIP}"
echo ""
echo "To test the app, run:"
echo "  open '${PRODUCTS_DIR}/${APP_NAME}'"
echo ""