# Releasing FunRadioBar

Listeners install from GitHub Releases. The app reads the signed feed at `https://github.com/robo-sk/FunRadioBar/releases/latest/download/appcast.xml`. Each feed points to its own tag’s ZIP. GitHub makes the new feed available to listeners when you publish a stable release and mark it latest.

## One-time signing setup

In **GitHub → Settings → Secrets and variables → Actions**, configure the following repository secrets. Enter credentials directly in GitHub or pipe them into `gh secret set` on a trusted Mac. Keep an encrypted backup of each private key. Never put a private key, certificate export or password in a commit, issue or release asset.

| Secret | Value |
| --- | --- |
| `DEVELOPER_ID_P12_BASE64` | Base64-encoded PKCS#12 export of your **Developer ID Application** certificate **and private key**. In Keychain Access, export the identity from **My Certificates**. |
| `DEVELOPER_ID_P12_PASSWORD` | Password chosen when exporting the PKCS#12 file. |
| `APPLE_ID` | Apple Account email used for notarization. |
| `APPLE_TEAM_ID` | Your Apple Developer team’s ten-character ID. |
| `APPLE_APP_PASSWORD` | App-specific password for that Apple Account. |
| `SPARKLE_ED_PRIVATE_KEY` | The Sparkle Ed25519 private key corresponding to the public key embedded in the app. The initial key is in the release owner's login Keychain under the Sparkle account `robo-sk.FunRadioBar`. Keep using that key for subsequent releases. |

For example, from the directory containing your certificate export, this command stores it directly in Actions:

```sh
base64 < DeveloperID.p12 | gh secret set DEVELOPER_ID_P12_BASE64 -R robo-sk/FunRadioBar
```

Apple signs the identity certificate and checks the submitted app for distribution. Sparkle verifies the signatures on the feed and ZIP whenever it updates an installation. Replacing the Sparkle key without a migration plan will strand existing installations. [Apple Developer ID](https://developer.apple.com/developer-id/) · [Sparkle signing and key rotation](https://sparkle-project.org/documentation/#3-seal-your-updates-for-security)

## Cut a release

1. Open the **public checkout** of `robo-sk/FunRadioBar`. Confirm the commit is on `main`. Choose a stable, higher version such as `1.0.0` and then `1.0.1`. Both the visible version and Sparkle’s build number come from this tag.
2. Tag the chosen commit and push only that tag. For example, for the first release:

   ```sh
   git tag v1.0.0
   git push origin v1.0.0
   ```

3. Watch **Actions → Mac release**. It runs the tests, builds both Mac architectures, signs with Developer ID, submits to Apple for notarization, attaches Apple’s ticket, then packs the final app and signs and verifies the ZIP and XML. A successful tag run creates a **draft** with **FunRadioBar.zip** and **appcast.xml**.
4. Open the draft, edit the listener-facing release notes, and download the ZIP to test a clean install from Applications. For later releases, also test an update from the previous published version on a separate Mac or test account with a staging feed. Editing the GitHub description is fine. Regenerate the signatures if any asset bytes change.
5. Publish the draft as the **latest** stable release. Confirm the latest appcast opens while signed out, and check for the update from the previous version. Earlier copies built before Sparkle was added need one manual installation.

To test compilation and universal packaging without creating a tag, use **Actions → Mac release → Run workflow**. The manual run uses a local-style signature without release credentials. If a tag run fails before creating a draft, correct the credentials and rerun it. If GitHub already has a partial draft for the tag, inspect and remove that draft before retrying. Never reuse a published version number.

## Before opening a release to the public

- Review the candidate files, commit author and committer emails, screenshots, Actions logs and ZIP. A secret scan of current files and Git history complements manual inspection for names, private paths, URLs and personal data. Rotate any exposed credential at its issuer.
- Restrict who can push release tags and edit workflows. Enable two-factor authentication, GitHub push protection and dependency alerts. Review updates to Sparkle and pinned Actions.
- Keep broadcaster imagery, names and streams within their permitted uses. The screenshots here show the app’s station tiles. Public GitHub visibility alone does not grant reuse rights to third-party content.

[GitHub secret scanning](https://docs.github.com/en/code-security/secret-scanning/introduction/about-secret-scanning) · [Sparkle publication guide](https://sparkle-project.org/documentation/publishing/) · [Apple notarization guide](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
