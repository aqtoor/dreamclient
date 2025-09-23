#!/bin/bash
set -e

# infinidream Screensaver Build Script (Step 1)
# Builds screensaver in Release mode without notarization
# Creates a zip ready for manual notarization submission

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT="infinidream.xcodeproj"
BUILD_CONFIG="Release"
SCREENSAVER_SCHEME="ScreenSaver Prod"
SCREENSAVER_NAME="infinidream.saver"
BUILD_DIR="build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"
PRODUCTS_DIR="${DERIVED_DATA}/Build/Products/${BUILD_CONFIG}"
OUTPUT_ZIP="${BUILD_DIR}/${BUILD_CONFIG}/screensaver.zip"

# Display build configuration
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}infinidream Screensaver Build (Step 1)${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "Configuration: ${BUILD_CONFIG}"
echo -e "Scheme: ${SCREENSAVER_SCHEME}"
echo -e "Output: ${OUTPUT_ZIP}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
if [ -d "$BUILD_DIR" ]; then
    /bin/rm -rf "$BUILD_DIR" 2>/dev/null || {
        echo -e "${YELLOW}Standard cleanup failed, trying alternative method...${NC}"
        find "$BUILD_DIR" -name ".DS_Store" -delete 2>/dev/null
        /bin/rm -rf "$BUILD_DIR"
    }
fi

# Create output directory
mkdir -p "${BUILD_DIR}/${BUILD_CONFIG}"

# Build screensaver
echo -e "${YELLOW}Building screensaver (${SCREENSAVER_SCHEME})...${NC}"

xcodebuild -project "$PROJECT" \
           -scheme "$SCREENSAVER_SCHEME" \
           -configuration "$BUILD_CONFIG" \
           -derivedDataPath "$DERIVED_DATA" \
           CODE_SIGN_STYLE="Manual" \
           CODE_SIGN_IDENTITY="Developer ID Application: Guillaume Louel (3L54M5L5KK)" \
           DEVELOPMENT_TEAM="3L54M5L5KK" \
           OTHER_CODE_SIGN_FLAGS="--timestamp" \
           | xcpretty --color || {
    # Fallback if xcpretty is not installed
    xcodebuild -project "$PROJECT" \
               -scheme "$SCREENSAVER_SCHEME" \
               -configuration "$BUILD_CONFIG" \
               -derivedDataPath "$DERIVED_DATA" \
               CODE_SIGN_STYLE="Manual" \
               CODE_SIGN_IDENTITY="Developer ID Application: Guillaume Louel (3L54M5L5KK)" \
               DEVELOPMENT_TEAM="3L54M5L5KK" \
               OTHER_CODE_SIGN_FLAGS="--timestamp"
}

# Verify screensaver build
if [ ! -d "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" ]; then
    echo -e "${RED}Failed to build ${SCREENSAVER_NAME}${NC}"
    echo -e "${RED}Expected at: ${PRODUCTS_DIR}/${SCREENSAVER_NAME}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${SCREENSAVER_NAME} built successfully${NC}"

# Verify code signing
echo -e "${YELLOW}Verifying code signature...${NC}"
if codesign --verify --deep --strict "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" 2>&1; then
    echo -e "${GREEN}✓ Code signature verified${NC}"

    # Check with spctl for more detailed info (non-fatal)
    echo -e "${YELLOW}Checking signature details with spctl...${NC}"
    SPCTL_OUTPUT=$(spctl -vvv --assess --type exec "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" 2>&1 || true)

    if [ -n "$SPCTL_OUTPUT" ]; then
        echo "Signature status: $SPCTL_OUTPUT"

        # Check if signed with Developer ID Application
        if echo "$SPCTL_OUTPUT" | grep -q "Developer ID Application"; then
            echo -e "${GREEN}✓ Signed with Developer ID Application certificate${NC}"
        else
            echo -e "${YELLOW}⚠ Warning: Not signed with Developer ID Application certificate${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Could not get detailed signature information${NC}"
    fi
else
    echo -e "${RED}✗ Code signature verification failed${NC}"
    echo "This may cause notarization to fail."
fi

# Copy screensaver to project Resources directory
echo -e "${YELLOW}Copying screensaver to project Resources directory...${NC}"
PROJECT_SCREENSAVER="Resources/${SCREENSAVER_NAME}"
OUTPUT_SAVER="${BUILD_DIR}/${BUILD_CONFIG}/${SCREENSAVER_NAME}"

# Copy to both locations for backwards compatibility and project integration
cp -R "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" "${OUTPUT_SAVER}"
cp -R "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" "${PROJECT_SCREENSAVER}"

if [ ! -d "${OUTPUT_SAVER}" ] || [ ! -d "${PROJECT_SCREENSAVER}" ]; then
    echo -e "${RED}Failed to copy screensaver${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Screensaver copied to project Resources${NC}"

# Create zip for notarization from the project version
echo -e "${YELLOW}Creating zip of screensaver for notarization...${NC}"
ditto -c -k --keepParent "${PROJECT_SCREENSAVER}" "${OUTPUT_ZIP}"

if [ ! -f "${OUTPUT_ZIP}" ]; then
    echo -e "${RED}Failed to create zip file${NC}"
    exit 1
fi

# Get file sizes for verification
SAVER_SIZE=$(du -sh "${PROJECT_SCREENSAVER}" | cut -f1)
ZIP_SIZE=$(du -h "${OUTPUT_ZIP}" | cut -f1)

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Screensaver Build Complete! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Build output: ${PRODUCTS_DIR}/${SCREENSAVER_NAME}"
echo "Project resource: ${PROJECT_SCREENSAVER} (${SAVER_SIZE})"
echo "Preserved at: ${OUTPUT_SAVER} (${SAVER_SIZE})"
echo "Zip for notarization: ${OUTPUT_ZIP} (${ZIP_SIZE})"
echo ""
echo "Next steps:"
echo "1. Run ./notarize_screensaver.sh to notarize the screensaver"
echo "2. After notarization, run ./build_app_with_screensaver.sh to build the app"
echo ""