# Signed and notarized macOS releases

MacSpace releases are built as a universal macOS app (Apple silicon and Intel),
signed with a **Developer ID Application** certificate, notarized by Apple, and
published as a DMG and ZIP. Users can download the DMG, drag `MacSpace.app` to
Applications, then open it; they do not need Xcode or this repository.

The app runs from the menu bar. Select **Copy iPad URL** from its keyboard icon
to paste the address into Safari on the iPad. macOS Accessibility permission is
still required because MacSpace sends keyboard and mouse events.

## One-time Apple setup

1. Enrol in the [Apple Developer Program](https://developer.apple.com/programs/).
2. In Apple Developer Certificates, Identifiers & Profiles, create and download a
   **Developer ID Application** certificate. Export it from Keychain Access as a
   password-protected `.p12` file.
3. In App Store Connect, create a notarization API key under **Users and Access →
   Integrations → Keys**. Download its `.p8` file once and record its Key ID and
   Issuer ID. Keep both the `.p12` and `.p8` private.

## GitHub repository secrets

In **Settings → Secrets and variables → Actions**, add the following repository
secrets. Do not commit any of these files or values.

| Secret | Value |
|---|---|
| `APPLE_CERTIFICATE_BASE64` | Base64-encoded Developer ID `.p12` file |
| `APPLE_CERTIFICATE_PASSWORD` | Password used when exporting the `.p12` |
| `DEVELOPER_ID_APPLICATION` | Exact certificate name, for example `Developer ID Application: Your Name (TEAMID)` |
| `KEYCHAIN_PASSWORD` | A new long random password used only by the GitHub Actions temporary keychain |
| `APPLE_API_KEY_BASE64` | Base64-encoded notarization `.p8` key file |
| `APPLE_API_KEY_ID` | App Store Connect API Key ID |
| `APPLE_API_ISSUER_ID` | App Store Connect issuer ID |

On macOS, create a base64 value without printing it to the terminal using:

```bash
base64 -i developer-id.p12 | pbcopy
base64 -i AuthKey_ABC123.p8 | pbcopy
```

Paste each clipboard value directly into the matching GitHub secret.

## Publish a release

1. Update `VERSION` and the `VERSION` value in `src/main.swift` to the same
   version, for example `1.1.0`, then merge that change to `main`.
2. Create and push a matching tag:

   ```bash
   git tag v1.1.0
   git push origin v1.1.0
   ```

3. The **Signed macOS release** workflow builds a universal app, verifies the
   hardened signature, notarizes it, staples the Apple ticket to the app and
   DMG, creates checksums, and publishes the assets to the GitHub Release.
4. Before announcing it, download the DMG on a different Mac, install it, and
   confirm that the menu-bar item appears, the copied URL opens on the iPad, and
   the Accessibility switch works.

For a dry run that only uploads artifacts, use **Actions → Signed macOS release
→ Run workflow** and provide the version. A pushed `vX.Y.Z` tag is the only path
that publishes a public GitHub Release.

## Failure and rollback

If notarization fails, download the notary log from the workflow and fix the
reported signing issue; do not publish the unsigned asset. If a release has a
serious problem, mark the GitHub Release as a draft or delete the release assets
and publish a new, higher version. Never reuse an existing release tag.
