#!/bin/bash
set -e

# infinidream Build Script
# Builds both screensaver and app, embedding the screensaver in the app bundle

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
BUILD_STAGE=false
BUILD_DEBUG=false
NOTARIZE=false
BUILD_CONFIG="Release"
SCREENSAVER_SCHEME="ScreenSaver Prod"
APP_SCHEME="infinidream App Prod"
SCREENSAVER_NAME="infinidream.saver"
APP_NAME="infinidream.app"

# Parse command line arguments
while getopts "sdn" opt; do
    case ${opt} in
        s )
            BUILD_STAGE=true
            SCREENSAVER_SCHEME="ScreenSaver Stage"
            APP_SCHEME="infinidream App Stage"
            SCREENSAVER_NAME="infinidream-stage.saver"
            APP_NAME="infinidream stage.app"
            ;;
        d )
            BUILD_DEBUG=true
            BUILD_CONFIG="Debug"
            ;;
        n )
            NOTARIZE=true
            ;;
        \? )
            echo "Usage: $0 [-s] [-d] [-n]"
            echo "  -s : Build stage version (default: production)"
            echo "  -d : Build in Debug mode (default: Release)"
            echo "  -n : Enable notarization"
            exit 1
            ;;
    esac
done

# Configuration
PROJECT="infinidream.xcodeproj"
BUILD_DIR="build"
DERIVED_DATA="${BUILD_DIR}/DerivedData"

# Display build configuration
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}infinidream Build Configuration${NC}"
echo -e "${BLUE}========================================${NC}"
if [ "$BUILD_STAGE" = true ]; then
    echo -e "Environment: ${YELLOW}STAGE${NC}"
else
    echo -e "Environment: ${GREEN}PRODUCTION${NC}"
fi
echo -e "Configuration: ${BUILD_CONFIG}"
echo -e "Notarization: $([ "$NOTARIZE" = true ] && echo "Enabled" || echo "Disabled")"
echo -e "${BLUE}========================================${NC}"
echo ""

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
if [ -d "$BUILD_DIR" ]; then
    # Use explicit path to rm and add error handling
    /bin/rm -rf "$BUILD_DIR" 2>/dev/null || {
        echo -e "${YELLOW}Standard cleanup failed, trying alternative method...${NC}"
        # Alternative: remove .DS_Store files first, then directories
        find "$BUILD_DIR" -name ".DS_Store" -delete 2>/dev/null
        /bin/rm -rf "$BUILD_DIR"
    }
fi

# Step 1: Build screensaver
echo -e "${YELLOW}Building screensaver (${SCREENSAVER_SCHEME})...${NC}"

if [ "$BUILD_DEBUG" = true ]; then
    # Debug build without code signing
    xcodebuild -project "$PROJECT" \
               -scheme "$SCREENSAVER_SCHEME" \
               -configuration "$BUILD_CONFIG" \
               -derivedDataPath "$DERIVED_DATA" \
               CODE_SIGN_IDENTITY="" \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGNING_ALLOWED=NO
else
    # Release build with standard settings
    xcodebuild -project "$PROJECT" \
               -scheme "$SCREENSAVER_SCHEME" \
               -configuration "$BUILD_CONFIG" \
               -derivedDataPath "$DERIVED_DATA"
fi

# Find the actual build output directory
if [ "$BUILD_DEBUG" = true ]; then
    PRODUCTS_DIR="${DERIVED_DATA}/Build/Products/Debug"
else
    PRODUCTS_DIR="${DERIVED_DATA}/Build/Products/Release"
fi

# Verify screensaver build
if [ ! -d "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" ]; then
    echo -e "${RED}Failed to build ${SCREENSAVER_NAME}${NC}"
    echo -e "${RED}Expected at: ${PRODUCTS_DIR}/${SCREENSAVER_NAME}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${SCREENSAVER_NAME} built successfully${NC}"

# Step 2: Build app
echo -e "${YELLOW}Building app (${APP_SCHEME})...${NC}"

if [ "$BUILD_DEBUG" = true ]; then
    # Debug build without code signing
    xcodebuild -project "$PROJECT" \
               -scheme "$APP_SCHEME" \
               -configuration "$BUILD_CONFIG" \
               -derivedDataPath "$DERIVED_DATA" \
               CODE_SIGN_IDENTITY="" \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGNING_ALLOWED=NO
else
    # Release build with standard settings
    xcodebuild -project "$PROJECT" \
               -scheme "$APP_SCHEME" \
               -configuration "$BUILD_CONFIG" \
               -derivedDataPath "$DERIVED_DATA"
fi

# Verify app build
if [ ! -d "${PRODUCTS_DIR}/${APP_NAME}" ]; then
    echo -e "${RED}Failed to build ${APP_NAME}${NC}"
    exit 1
fi

echo -e "${GREEN}✓ ${APP_NAME} built successfully${NC}"

# Step 3: Embed screensaver into app bundle
echo -e "${YELLOW}Embedding screensaver into app bundle...${NC}"
SAVER_PATH="${PRODUCTS_DIR}/${SCREENSAVER_NAME}"
APP_RESOURCES="${PRODUCTS_DIR}/${APP_NAME}/Contents/Resources"

if [ -d "$SAVER_PATH" ]; then
    mkdir -p "$APP_RESOURCES"
    # Use the basename to ensure it's always named infinidream.saver in the app bundle
    cp -R "$SAVER_PATH" "$APP_RESOURCES/infinidream.saver"
    echo -e "${GREEN}✓ ${SCREENSAVER_NAME} successfully embedded as infinidream.saver${NC}"
else
    echo -e "${RED}Error: ${SCREENSAVER_NAME} not found for embedding${NC}"
    exit 1
fi

# Verify embedded screensaver
if [ -d "${APP_RESOURCES}/infinidream.saver" ]; then
    echo -e "${GREEN}✓ Embedded screensaver verified${NC}"
else
    echo -e "${RED}Error: infinidream.saver not found in app bundle${NC}"
    exit 1
fi

# Step 4: Notarization (if requested)
if [ "$NOTARIZE" = true ]; then
    echo -e "${YELLOW}Starting notarization process...${NC}"
    
    # Check if we have a Developer ID
    if [ -z "$DEVELOPER_ID" ]; then
        echo -e "${YELLOW}DEVELOPER_ID environment variable not set${NC}"
        echo "Please set DEVELOPER_ID to your 'Developer ID Application' certificate name"
        echo "Example: export DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)'"
        exit 1
    fi
    
    # Re-sign the app with Developer ID for notarization
    echo -e "${YELLOW}Signing app with Developer ID...${NC}"
    codesign --deep --force --verify --verbose \
             --sign "$DEVELOPER_ID" \
             --options runtime \
             --entitlements ../Client/infinidream.entitlements \
             "${PRODUCTS_DIR}/${APP_NAME}"
    
    # Create a zip for notarization
    echo -e "${YELLOW}Creating zip for notarization...${NC}"
    ditto -c -k --keepParent "${PRODUCTS_DIR}/${APP_NAME}" "${PRODUCTS_DIR}/infinidream.zip"
    
    # Submit for notarization
    echo -e "${YELLOW}Submitting to Apple for notarization...${NC}"
    xcrun notarytool submit "${PRODUCTS_DIR}/infinidream.zip" \
                     --apple-id "$APPLE_ID" \
                     --password "$NOTARIZATION_PASSWORD" \
                     --team-id "$TEAM_ID" \
                     --wait
    
    # Staple the notarization ticket
    echo -e "${YELLOW}Stapling notarization ticket...${NC}"
    xcrun stapler staple "${PRODUCTS_DIR}/${APP_NAME}"
    
    # Clean up zip
    rm "${PRODUCTS_DIR}/infinidream.zip"
    
    echo -e "${GREEN}✓ Notarization complete${NC}"
fi

# Summary
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Build Complete! 🎉${NC}"
echo -e "${GREEN}========================================${NC}"
echo "Screensaver: ${PRODUCTS_DIR}/${SCREENSAVER_NAME}"
echo "Application: ${PRODUCTS_DIR}/${APP_NAME}"
echo "  └── Embedded: ${PRODUCTS_DIR}/${APP_NAME}/Contents/Resources/infinidream.saver"
if [ "$BUILD_STAGE" = true ]; then
    echo "Environment: STAGE"
else
    echo "Environment: PRODUCTION"
fi
echo "Configuration: ${BUILD_CONFIG}"
if [ "$NOTARIZE" = true ]; then
    echo "Notarization: ✓ Complete"
fi
echo ""
echo "To test the app, run:"
echo "  open '${PRODUCTS_DIR}/${APP_NAME}'"