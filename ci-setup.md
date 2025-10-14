# Setting up keys for CI

## Signing keys 

Open https://github.com/e-dream-ai/client/settings/secrets/actions and get and create/edit secrets (press the pen on the right) :

- Open Keychain Access
- Find your "Developer ID Application: e-dream, inc (BNXH8TLP5D)" certificate
- Right-click → Export "Developer ID Application: e-dream, inc"
- Save as "Certificates.p12" with a strong password
- Convert to base64 for GitHub:

`base64 -i Certificates.p12 | pbcopy`

- copy from clipboard in github in `MACOS_CERTIFICATE`
- copy the password in `MACOS_CERTIFICATE_PWD`

APPLE_TEAM_ID should be filled accordingly (BNXH8TLP5D) 

## Notarization token 

Go to https://appstoreconnect.apple.com/ and select the appropriate account

- Navigate to Users and Access → Keys (under Integrations)
- Click Generate API Key and : 
  Name: "GitHub Actions Notarization"
  Access: App Manager
- Download the .p8 file
- Paste the Key ID in github in : `APPSTORECONNECT_API_KEY_ID`
- Paste the Issuer ID in github in : `APPSTORECONNECT_API_ISSUER_ID

- Convert .p8 to base64 and put it in clipboard: 
`base64 -i AuthKey_XXXXXXXXXX.p8 | pbcopy`

- Paste in github : `APPSTORECONNECT_API_KEY`
