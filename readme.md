Copyright e-dream, inc

```
2025.05     renamed e-dream to infinidream
2023.07     forked to work with new server and repository, renamed from Electric Sheep to e-dream
2015.05     moved from code.google.com repo
2011.01.30  based on revision 1546 on sf.net
```

infinidream: visuals for your vibe.
a platform for generative visuals.
this repository has the native client.

# dev docs

this repository uses git LFS, be sure to run

    brew install git-lfs
    git lfs install

on Mac, open client_generic/MacBuild/infinidream.xcodeproj

Use the "File>Packages>Update to Latest" menu to load the
dependencies.

The C++ dependencies are handled by vcpkg...

There are four targets: app, screensaver, staging app, and staging
screensaver. The staging targets have their own directory
/Users/Shared/infinidream.ai-stage that can coexist with the normal one
/Users/Shared/infinidream.ai

## Build on macOS

### Prerequisites
- Xcode 14.0 or later
- macOS 12.4 or later

### Build Script
```bash
cd client_generic/MacBuild
./build.sh [options]
```

### Options
- `-r` : Build in Release mode (default: Debug)
- `-s` : Build stage version (default: production)
- `-n` : Enable notarization (requires `-r`)

### Code Signing
Auto-discovers Developer ID certificate and Team ID from keychain.

Override via environment variables:
```bash
DEVELOPER_ID_CERT="Developer ID Application: Your Name (TEAM123)" \
TEAM_ID="TEAM123" \
KEYCHAIN_PROFILE="your-profile" \
./build.sh -r
```

Default keychain profile: `infinidream-notarization`

### Examples 
```bash
# Debug build (default)
./build.sh

# Release build
./build.sh -r

# Stage debug build
./build.sh -s

# Release with notarization
./build.sh -r -n
```

### Output
- Screensaver: `build/DerivedData/Build/Products/{Debug|Release}/infinidream.saver`
- Application: `build/{Debug|Release}/AppExport/infinidream.app`

The app bundle contains the embedded screensaver at `infinidream.app/Contents/Resources/infinidream.saver`.

## to release (manually)

make a git tag with the version
```
git tag X.Y.Z
git push --tags
```

Then build to set the version strings in the plists:
```
./build.sh
```
Then build for release:
```
./build.sh -r -n
```
This creates build/Release/infinidream-$(DATE).zip

The release image is now complete.

* Make a release with the github button, write the notes, and upload
  the image. If this is a pre-release, click that box to mark that,
  and you are done. Otherwise, continue with linking as described
  below.

* Update the link to the current release in the *main branch* of the
  frontend repository by editing `APP_VERSION` in
  `src/components/pages/install/install.page.tsx`

* Push and that's it, Github and Cloudflare build automation should deploy
  the change in a few minutes.

Upload the symbols to bugsnag, on a terminal: 
- if first time install the upload tool `brew install bugsnag/tap/bugsnag-dsym-upload`
- Go to https://app.bugsnag.com/settings/e-dream-dot-ai/projects/client-macos/missing-dsyms and copy the first missing UUID corresponding to the tag
- run `mdfind YOUR_UUID_HERE`. This will output a path to the dsym `path/to/dsyms/MyApp.dSYM`
- run `bugsnag-dsym-upload path/to/dsyms` (note that it's the path TO the dsyms)

the screensaver is more complicated because Xcode can't automatically
manage the signing. So

1) Use Archive in Xcode and export in a folder

2) In that folder, go into the mess of subfolders until you find infinidream.saver. 
OR ALTERNATIVELY (replace {username} with the macOS account name that created the build)

```
mv Products/Users/{username}/Library/Screen\ Savers/infinidream.saver/ ./
```

3) Zip the saver so it can be submitted

```
/usr/bin/ditto -c -k --keepParent "infinidream.saver" "infinidream.zip"
```

4) Assuming  you have created a keychain profile called "infinidream", this will launch the notarization process and wait until it's done

```
xcrun notarytool submit infinidream.zip --keychain-profile "infinidream" --wait
```

5) if successful staple the receipt (this lets people install the screensaver without connecting to apple servers for verification of the notarization)

```
xcrun stapler staple infinidream.saver
```

6) Zip the final thing

```
/usr/bin/ditto -c -k --keepParent "infinidream.saver" "infinidream-master-notarized+stapled.zip"
```

see https://developer.apple.com/documentation/security/customizing-the-notarization-workflow
and https://support.apple.com/en-us/102654
