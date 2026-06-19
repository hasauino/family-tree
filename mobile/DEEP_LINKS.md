# Shareable links & deep linking

The app builds public links to a person's tree and to a "from → to" path, and
opens those links straight into the tree — on the **web** (browser address
bar), and on **Android / iOS** as native App Links / Universal Links.

## Link shapes

| Target              | URL                                   |
| ------------------- | ------------------------------------- |
| A person's tree     | `https://omaritree.com/person/<id>`   |
| A from→to path view | `https://omaritree.com/path/<from>/<to>` |

The same URLs are also accepted in query form (`?person=<id>`,
`?from=<x>&to=<y>`) so they work even where path routing isn't available.
Parsing/building lives in [`lib/deep_link.dart`](lib/deep_link.dart); the host
comes from `AppConfig.shareBaseUrl` (defaults to the current origin on web, and
`https://omaritree.com` on mobile — override with
`--dart-define=SHARE_BASE_URL=...`).

## Sharing

A **Share** button sits in the tree's floating action bar (shares the current
person, or the active path) and in the path-result sheet. Both use `share_plus`
(native share sheet on mobile, the Web Share API / clipboard on web).

## What you must finish for **native** deep links

Web links work as soon as this is deployed. Native App/Universal Links also
need the domain to vouch for the app, via two files served from the web app at
`https://omaritree.com/.well-known/` (already wired into
[`Dockerfile`](Dockerfile) + [`nginx.conf`](nginx.conf)):

### Android — `web/.well-known/assetlinks.json`

Replace `REPLACE_WITH_YOUR_APP_SIGNING_SHA256_FINGERPRINT` with your release
signing certificate's SHA-256 fingerprint. For a Play-signed app, copy it from
**Play Console → Setup → App integrity**. For a local keystore:

```sh
keytool -list -v -keystore <your.keystore> -alias <alias> | grep SHA256
```

You can list several fingerprints (e.g. upload + Play app-signing, or a debug
cert for testing). Verify after deploy:

```sh
adb shell pm verify-app-links --re-verify com.familytree.family_tree_mobile
adb shell pm get-app-links com.familytree.family_tree_mobile   # expect "verified"
```

### iOS — `web/.well-known/apple-app-site-association`

Already filled in with the app's Team ID (`LCQ66ZY7P4`) and bundle id
(`com.familytree.familyTreeMobile`). The associated-domain entitlement
(`applinks:omaritree.com`) is in
[`ios/Runner/Runner.entitlements`](ios/Runner/Runner.entitlements) and wired
into the Xcode target. In the Apple Developer portal, enable the **Associated
Domains** capability for the App ID. The file must be served over HTTPS as JSON
with no redirect (handled by `nginx.conf`).

> Keep the host consistent across `AppConfig.shareBaseUrl`,
> `AndroidManifest.xml`, `Runner.entitlements`, and both `.well-known` files if
> you ever change the production domain.
