# Push notifications (Firebase Cloud Messaging) — setup

The app and backend are fully wired for push. What's left is the **per-project
credentials**, which can't live in the repo — you generate them once in the
Firebase console and drop them in. Until you do, push is a silent no-op and the
in-app notification bell still works everywhere.

Android push via FCM is **free**. iOS push additionally needs a **paid Apple
Developer account** ($99/yr) to create an APNs key — but you need that account to
ship iOS at all.

## 1. Create a Firebase project

1. Go to <https://console.firebase.google.com> → **Add project**.
2. Add an **Android app** with package name `com.familytree.family_tree_mobile`
   and an **iOS app** with the matching bundle id (see `ios/Runner.xcodeproj`).

## 2. Android

1. Download **`google-services.json`** for the Android app.
2. Put it at **`mobile/android/app/google-services.json`**.
   The Gradle plugin is already wired (`android/settings.gradle.kts` and
   `android/app/build.gradle.kts`). That's it — `flutter run` now delivers push.

> To build Android **without** push, comment out the
> `id("com.google.gms.google-services")` line in `android/app/build.gradle.kts`.

## 3. iOS

1. Download **`GoogleService-Info.plist`** for the iOS app and add it to the
   Runner target in Xcode (`ios/Runner/`, "Copy items if needed").
2. In Xcode → Runner target → **Signing & Capabilities**, add **Push
   Notifications** and (already declared in `Info.plist`) Background Modes →
   *Remote notifications*.
3. In the Apple Developer portal create an **APNs auth key** (.p8) and upload it
   in Firebase → Project settings → **Cloud Messaging** → Apple app config.

## 4. Backend

Push is sent from Django via `firebase-admin`. Provide a service-account key:

1. Firebase console → Project settings → **Service accounts** → *Generate new
   private key* → download the JSON.
2. Set the env var the settings read (see `project/settings/base.py`):

   ```
   FIREBASE_CREDENTIALS_FILE=/abs/path/to/service-account.json
   ```

Leave it unset and the backend skips push entirely (no errors). `firebase-admin`
is already in `pyproject.toml`.

## How it flows

- On sign-in the app registers its FCM token via the `registerDeviceToken`
  mutation; on sign-out it calls `unregisterDeviceToken`.
- Whenever the backend creates a notification (a pending addition, a
  verification, a node change, or an admin broadcast) it calls
  `main.push.send_to_user`, which pushes to every registered device.
- Foreground messages are shown as a banner by `flutter_local_notifications`;
  tapping a notification deep-links to the related person's tree.
- Tokens FCM reports as stale are pruned automatically on the next send.
