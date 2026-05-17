# Postal Courier — Flutter Tracking Prototype

A courier parcel registration and tracking prototype with Firebase Firestore, real Android SMS, QR generation, and QR scanning.

## Features

- **Login** — Username/password validation (no backend)
- **Parcel registration** — Sender, receiver, and parcel details
- **Tracking ID** — `TRK` + timestamp (e.g. `TRK1734567890123`)
- **Firestore** — `parcels` collection, document ID = `trackingId`
- **SMS** — Real SMS via device SIM to sender and receiver (Android)
- **QR code** — Generated with `qr_flutter` (encodes `trackingId`)
- **QR scanner** — `mobile_scanner` loads parcel from Firestore

## Project structure

```
lib/
├── models/parcel.dart
├── screens/
│   ├── login_screen.dart
│   ├── parcel_form_screen.dart
│   ├── tracking_screen.dart
│   ├── scanner_screen.dart
│   └── parcel_details_screen.dart
├── services/
│   ├── firestore_service.dart
│   └── sms_service.dart
├── widgets/
│   ├── primary_button.dart
│   └── section_card.dart
├── utils/constants.dart
├── firebase_options.dart
└── main.dart
```

## Setup

### 1. Flutter

```bash
flutter pub get
```

### 2. Firebase

1. Create a project at [Firebase Console](https://console.firebase.google.com/).
2. Add an **Android** app with package name: `com.postalapp.postal_app`
3. Download `google-services.json` and place it in:

   `android/app/google-services.json`

4. Enable **Cloud Firestore** in test mode (or set security rules for your prototype).
5. Update credentials — either:

   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```

   This replaces `lib/firebase_options.dart` automatically.

   **Or** manually edit `lib/firebase_options.dart` with your API keys.

### 3. Firestore rules (prototype)

```text
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /parcels/{trackingId} {
      allow read, write: if true;
    }
  }
}
```

> Use stricter rules before production.

### 4. Run on Android (physical device recommended for SMS)

```bash
flutter run
```

SMS requires a **real Android phone** with a SIM card. Emulators often cannot send SMS.

Grant **SMS** and **Camera** permissions when prompted.

## Flow

1. Login → Parcel form
2. Fill form → **Generate Tracking ID**
3. App saves to Firestore → sends SMS → shows tracking screen with QR
4. Use scanner (app bar icon) → scan QR → parcel details from Firestore

## SMS messages

**Sender:**  
`Parcel Registered. Tracking ID: {id}. Track: {url}`

**Receiver:**  
`You will receive a parcel. Tracking ID: {id}. Track: {url}`

## Notes

- iOS: SMS via `telephony` is not supported; Firestore and QR still work.
- Tracking URL base: `https://yourapp.com/track/{trackingId}` (configurable in `lib/utils/constants.dart`).
- This is a learning prototype — not production-hardened auth or security.
