# Sign-in / Sign-up setup

The app offers four sign-in methods — **email + password**, **Google**, **Apple**, and
**Facebook**. Every method is independently switchable and credentialed; nothing is
hard-coded. A method only ever appears in the app once it is **both**:

1. **Enabled + credentialed on the backend** (Django decides this and reports it through the
   GraphQL `authConfig` query), and
2. **Configured natively** on the platform you're building for (Google/Apple/Facebook only).

Email works out of the box. The three social providers need OAuth apps you create with each
provider, plus a little native config. Until you do that they stay hidden, so the app builds
and runs today with email-only.

---

## 1. Backend (Django)

All flags live in environment variables (see the repo root `.env`, read in
`familytree/project/settings/base.py`):

| Variable | Meaning |
| --- | --- |
| `AUTH_EMAIL_ENABLED` | Email + password sign-in/up (default `True`). |
| `AUTH_EMAIL_REQUIRE_ACTIVATION` | `True` = email an activation link on sign-up; `False` = sign in immediately. |
| `AUTH_GOOGLE_ENABLED` + `GOOGLE_CLIENT_IDS` | Comma-separated OAuth client ids accepted as the token audience (iOS, Android, web). |
| `AUTH_APPLE_ENABLED` + `APPLE_CLIENT_IDS` | Comma-separated bundle id / services id accepted as the token audience. |
| `AUTH_FACEBOOK_ENABLED` + `FACEBOOK_APP_ID` + `FACEBOOK_APP_SECRET` | Facebook app credentials used to validate the access token. |

A provider is "available" only when its `*_ENABLED` flag is on **and** its credentials are
present, so a half-configured provider never shows up.

---

## 2. Google

1. In the [Google Cloud Console](https://console.cloud.google.com/) create OAuth client ids for
   each platform you ship (iOS, Android, and a **Web** client used as the token audience).
2. Backend: set `AUTH_GOOGLE_ENABLED=True` and `GOOGLE_CLIENT_IDS` to the client ids that may
   sign in (include the Web client id — it's the audience of the ID token).
3. Mobile build: pass the Web/server client id so the ID token's audience matches the backend:

   ```
   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
   ```

4. **iOS:** add the reversed iOS client id as a URL scheme — see the commented `CFBundleURLTypes`
   block in `ios/Runner/Info.plist`.
5. **Android:** no manifest entry needed; the plugin reads the client id from
   `google-services.json` / the `serverClientId` above. (Add your app's SHA-1 to the Google
   console.)

## 3. Apple

1. In the [Apple Developer](https://developer.apple.com/) portal enable **Sign in with Apple**
   for your App ID, and (for non-Apple platforms) create a **Services ID**.
2. Backend: set `AUTH_APPLE_ENABLED=True` and `APPLE_CLIENT_IDS` to your bundle id (and Services
   id if used) — these are the token audiences.
3. **iOS:** in Xcode, Runner target → Signing & Capabilities → **+ Sign in with Apple**. That
   creates the `Runner.entitlements` entry. (No `Info.plist` change.)
4. Apple is hidden on non-Apple devices automatically (`socialProviderSupported`).

## 4. Facebook

1. In [Facebook for Developers](https://developers.facebook.com/) create an app and enable
   Facebook Login. Note the **App ID**, **App Secret**, and **Client Token**.
2. Backend: set `AUTH_FACEBOOK_ENABLED=True`, `FACEBOOK_APP_ID`, `FACEBOOK_APP_SECRET`.
3. **iOS:** fill in the `FacebookAppID` / `FacebookClientToken` / URL-scheme blocks in
   `ios/Runner/Info.plist` (commented templates are there).
4. **Android:** add to `android/app/src/main/res/values/strings.xml`:

   ```xml
   <string name="facebook_app_id">1234567890</string>
   <string name="facebook_client_token">YOUR_CLIENT_TOKEN</string>
   <string name="fb_login_protocol_scheme">fb1234567890</string>
   ```

   then uncomment the Facebook block in `android/app/src/main/AndroidManifest.xml`. (It's left
   commented because a placeholder app id would crash the Facebook SDK at startup.)

---

## How it fits together

- The client gets a token natively from the provider (`lib/auth/social_sign_in.dart`).
- It sends the token to the `socialLogin` GraphQL mutation.
- The backend **re-verifies** the token with the provider (`main/auth/verifiers.py`) — Google &
  Apple by checking the JWT signature/issuer/audience, Facebook via the Graph API — then
  finds-or-creates the user and starts an ordinary Django **session cookie**.
- Email sign-in/up and the session cookie work exactly as before; social just adds new ways to
  obtain that same session.
