# Fuel Logger — Flutter Native Android App
## Project Instructions, Roadmap & Test Reviews Log

---

## 1. Project Overview

**Fuel Logger** is a 100% native **Flutter** application for Android (specifically optimized for high-refresh-rate displays like the **Samsung Galaxy S24 Ultra** at 120 Hz). It provides seamless vehicle fuel logging, comprehensive 16-column real-world telemetry calculations (exact cycle math matching the original Python engine), local caching, and instant cloud sync with **Supabase PostgreSQL**.

### Tech Stack & Architecture
- **Framework**: Flutter (Channel Stable 3.50.0 / Dart 3.14.0)
- **Current Version**: `Version - 2.4.0 (Build 7)`
- **Design System**: AMOLED Dark Theme (`#14161C` background, `#1E222D` card surface, `#FF5252` primary accent, `#69F0AE` mileage green, `#40C4FF` distance blue)
- **State Management**: `Provider` (`GarageProvider` for active vehicle/logs/telemetry, `AuthProvider` for reactive sessions)
- **Backend / Database**: Supabase Cloud PostgreSQL (Dual Environment: Dev & Production) + Offline First Local Cache
- **Local Persistence**: `shared_preferences` for vehicle preferences, customization, and instant startup cache
- **Flavors**:
  - **Dev**: Package `com.fuellogger.app.dev`, App Name `"Fuel Logger (DEV)"`
  - **Prod**: Package `com.fuellogger.app`, App Name `"Fuel Logger"`
- **CI/CD Build Automation**: GitHub Actions (`.github/workflows/build_apk.yml`) building both flavor APKs on every push

---

## 2. Implemented Features & Architecture

### 1. Authentication (`lib/views/auth/login_view.dart`)
- **Native Google Account Sign-In**: Integrated `google_sign_in` using the Android Account Manager sheet.
- **Direct Password Sign-In & Registration**: Fast login directly against PostgreSQL with strict session validation.
- **Password Reset**: In-app password reset modal dialog.
- **Offline Guest Mode**: Instant access with local cache.
- **Sanitized Errors**: No raw PostgREST error codes (e.g. `PGRST303`); clear human-readable notices.

### 2. Home Dashboard (`lib/views/home/home_view.dart`)
- **Dynamic Vehicle Banner**: Renders active vehicle name, model, custom color gradient, and vehicle icon.
- **Top 2 Metric Tiles**: Total Average Mileage (`km/l`) and Total Driven Distance (`km`).
- **Quick Action Cards**: "Log New Fill-Up", "View Calculations", and "Manage Logs".
- **Vehicle Switcher**: Bottom sheet switcher with vehicle list and direct "+ Add New Vehicle" button.
- **Pull-To-Refresh**: Native pull-down gesture to refresh garage and logs.

### 3. Upload Fill-Up (`lib/views/upload/upload_view.dart`)
- **Automatic S.No / Run #**: Sequentially increments from the last logged run.
- **Full vs. Partial Fill Modes**: Toggle buttons for full tank vs. partial fill.
- **Strict Numeric Inputs**: Only numeric and decimal characters accepted.
- **Instant Telemetry Preview**: Calculates distance, mileage, and cost-per-km before submitting.
- **Foolproof Saving**: Cloud sync with instant offline local fallback.

### 4. Calculations & Breakdown (`lib/views/calculations/calculations_view.dart`)
- **Full 16-Column Telemetry**: Average mileage, total cost, total distance, total fuel consumed, average cost per km, and fuel efficiency.
- **Fuel Type Breakdown**: Aggregates usage, litres, and total spend by fuel grade.
- **Pull-To-Refresh**: Scroll-down gesture to reload telemetry.

### 5. Log History (`lib/views/logs/logs_view.dart`)
- Reverse chronological display of all fill-ups.
- Tap to edit any previous fill-up entry.
- Swipe or tap to delete with confirmation.
- **Pull-To-Refresh**: Gesture-based refresh on both empty and filled list states.

### 6. Settings & Garage Management (`lib/views/settings/settings_view.dart`)
- Vehicle customization: rename, change icon, choose theme color.
- Add new vehicle or delete vehicle.
- Password change and direct sign-out.
- Version display: Shows clean `Version - 2.3.0 (Build 6)`.

---

## 3. Environment & Configuration

| Environment | Package ID | Supabase Project URL | Purpose |
| :--- | :--- | :--- | :--- |
| **DEV** | `com.fuellogger.app.dev` | `https://qjwuajdcyrdlnjplvtsr.supabase.co` | Testing, experimentation, and staging |
| **PROD** | `com.fuellogger.app` | `https://hjprefmnofrqyjocihto.supabase.co` | Production database and daily personal logging |

---

Reviews and workflow updates:(refer screenshots, if it attached) *Don't erase this title, I'll update next reviews here*

<!--
  ====================================================================================
  HOW TO ADD YOUR REVIEWS & UPDATES:
  Write your test feedback, bug reports, UI adjustments, or new requests below.
  Example format:
  - [ ] 1. <Screen Name>: <Describe the issue or desired change>
  ====================================================================================
-->

### Completed in Version 2.3.0 (Build 6):

1. **Log-in page**:
   - [x] Only show "Version - #". Removed all mentions of Flutter, Supabase, and DB. Now displays `Version - 2.3.0 (Build 6)`.
   - [x] Added Google native account manager sign in (`google_sign_in` with Android account sheet).
   - [x] Fixed invisible text on sign-in and action buttons (`foregroundColor: Colors.white` added across theme and views).
   - [x] Resolved password account creation and sign-in session handling. Prevented fake session login on existing unconfirmed accounts and added "Forgot Password?" dialog.
   - [x] Removed OTP / email link sign-in completely as requested.

2. **Home page**:
   - [x] Removed top-right refresh icon button.
   - [x] Enabled pull-to-refresh (`RefreshIndicator` with `AlwaysScrollableScrollPhysics`).
   - [x] Fixed "Switch Vehicle" dialog: vehicles list is always populated, active vehicle is selected, and an inline `+ Add New Vehicle` option is included.

3. **Settings page**:
   - [x] Fixed renaming vehicle: updates active vehicle in memory, in local cache, and syncs to Supabase.
   - [x] Fixed "Add New Vehicle": handles both cloud-authenticated and offline/guest modes cleanly.
   - [x] Only show `Version - 2.3.0 (Build 6)`; stripped all DB/engine references.

4. **Upload page**:
   - [x] Fixed "Failed to save log": handles empty/local vehicle IDs and syncs with cloud or local cache without crashing.
   - [x] Fixed missing "Upload Fuel Log" text on submit button with explicit high-contrast white text.

5. **Logs page**:
   - [x] Fixed blank red button on empty logs screen; now properly displays "Log First Fill-Up" with icon and white text.
   - [x] Enabled pull-to-refresh.

6. **All pages**:
   - [x] Enabled pull-down / scroll-up refresh on Home, Calculations, and Logs pages.

7. **App Logo**:
   - [x] Designed and generated high-resolution modern AMOLED fuel pump app launcher icons across all mipmap resolutions (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`) and `assets/logo.png`.

### Completed in Version 2.4.0 (Build 7):

8. **App logo**:
   - [x] Restored authentic single-color app logo from `Fuelapp/assets/icon.png`. Generated high-resolution Android launcher mipmap icons (`ic_launcher.png` and `ic_launcher_round.png`) across all densities (`mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, `xxxhdpi`) and updated `assets/logo.png`.

9. **Log-in page**:
   - [x] Removed "G" logo from "Sign in with Google" button; now displays a clean, centered text button.
   - [x] Removed "Telemetry" from app slogan; updated to "Mileage Tracker".
   - [x] Handled Google Sign-In `ApiException: 10` gracefully with automatic fallback to Supabase browser OAuth and clear, friendly guidance on SHA-1 fingerprint registration.
   - [x] Resolved password sign-in / account already exists confusion: clarified that the email was originally registered via Google OAuth without a password hash.
   - [x] Resolved `localhost:3000` password reset: Implemented in-app 6-digit recovery code verification (`verifyOTP` + `updateUser`), enabling users to reset passwords directly inside the app on Android without needing a local desktop server.
   - [x] Added clean Android deep linking intent filters for `fuellogger://` and `com.fuellogger.app://` in `AndroidManifest.xml`.
   - [x] Preserved Guest (Offline) mode as an optional safeguard.

10. **Settings page**:
    - [x] Added **Manage Fuel Types**: Added interactive card displaying fuel grade chips with delete (✕) controls, and text input to add new custom grades with local persistence.
    - [x] Added **Export Vehicle Data**: Added card to export active vehicle fill-up logs to standard RFC-4180 CSV format with scrollable in-app preview and one-tap clipboard copy.

11. **Upload page & Telemetry Engine Calculations**:
    - [x] Removed `[Mandatory]` text across all form labels; replaced with clean `*` (e.g. `S.No / Run # *`, `Total Fuel Cost (₹) *`, `Litres Filled (L) *`, `Odometer Reading (km) *`).
    - [x] Fixed odometer reading bug: User-entered odometer reading is directly stored into `fromOdometer`. Allows both higher and lower values without reverting or rejecting.
    - [x] Fixed instant calculation sync: Integrated `TelemetryEngine.recalculateCycles` in `GarageProvider._loadLogsForActiveVehicle` so logs and telemetry calculations update immediately upon uploading or editing.
    - [x] Documented full live calculations and cycle telemetry math in the release summary report.
    - 