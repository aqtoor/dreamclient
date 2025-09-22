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

# Step 2: Notarize screensaver (if requested)
if [ "$NOTARIZE" = true ]; then
    echo -e "${YELLOW}Notarizing screensaver...${NC}"
    
    # Create a zip for screensaver notarization
    echo -e "${YELLOW}Creating zip of screensaver for notarization...${NC}"
    ditto -c -k --keepParent "${PRODUCTS_DIR}/${SCREENSAVER_NAME}" "${PRODUCTS_DIR}/screensaver.zip"
    
    # Submit screensaver for notarization
    echo -e "${YELLOW}Submitting screensaver to Apple for notarization...${NC}"
    if ! xcrun notarytool submit "${PRODUCTS_DIR}/screensaver.zip" \
                     --keychain-profile "infinidream-notarization" \
                     --wait; then
        echo -e "${RED}✗ Screensaver notarization failed${NC}"
        rm "${PRODUCTS_DIR}/screensaver.zip"
        exit 1
    fi
    
    # Staple the notarization ticket to screensaver
    echo -e "${YELLOW}Stapling notarization ticket to screensaver...${NC}"
    if ! xcrun stapler staple "${PRODUCTS_DIR}/${SCREENSAVER_NAME}"; then
        echo -e "${RED}✗ Failed to staple notarization ticket to screensaver${NC}"
        rm "${PRODUCTS_DIR}/screensaver.zip"
        exit 1
    fi
    
    # Clean up screensaver zip
    rm "${PRODUCTS_DIR}/screensaver.zip"
    
    echo -e "${GREEN}✓ Screensaver notarization complete${NC}"
fi

# Step 3: Build app
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

# Step 4: Embed screensaver into app bundle
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

# Step 5: Notarize app (if requested)
if [ "$NOTARIZE" = true ]; then
    echo -e "${YELLOW}Notarizing app...${NC}"
    
    # Note: Notarization requires keychain profile 'infinidream-notarization'
    # Set up with: xcrun notarytool store-credentials 'infinidream-notarization' \
    #              --apple-id YOUR_APPLE_ID --team-id BNXH8TLP5D
    
    # Create a zip for app notarization
    echo -e "${YELLOW}Creating zip of app for notarization...${NC}"
    ditto -c -k --keepParent "${PRODUCTS_DIR}/${APP_NAME}" "${PRODUCTS_DIR}/app.zip"
    
    # Submit app for notarization
    echo -e "${YELLOW}Submitting app to Apple for notarization...${NC}"
    if ! xcrun notarytool submit "${PRODUCTS_DIR}/app.zip" \
                     --keychain-profile "infinidream-notarization" \
                     --wait; then
        echo -e "${RED}✗ App notarization failed${NC}"
        rm "${PRODUCTS_DIR}/app.zip"
        exit 1
    fi
    
    # Staple the notarization ticket to app
    echo -e "${YELLOW}Stapling notarization ticket to app...${NC}"
    if ! xcrun stapler staple "${PRODUCTS_DIR}/${APP_NAME}"; then
        echo -e "${RED}✗ Failed to staple notarization ticket to app${NC}"
        rm "${PRODUCTS_DIR}/app.zip"
        exit 1
    fi
    
    # Clean up app zip
    rm "${PRODUCTS_DIR}/app.zip"
    
    echo -e "${GREEN}✓ App notarization complete${NC}"
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