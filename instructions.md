# Fuel Logger — Flutter Native Android App
## Project Instructions, Roadmap & Test Reviews Log

---

## 1. Project Overview

**Fuel Logger** is a 100% native **Flutter** application for Android (specifically optimized for high-refresh-rate displays like the **Samsung Galaxy S24 Ultra** at 120 Hz). It provides seamless vehicle fuel logging, comprehensive 16-column real-world telemetry calculations (exact cycle math matching the original Python engine), local caching, and instant cloud sync with **Supabase PostgreSQL**.

### Tech Stack & Architecture
- **Framework**: Flutter (Channel Stable 3.50.0 / Dart 3.14.0)
- **Current Version**: `Version - 2.17.2 (Build 23)`
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

### Completed in Version 2.5.0 (Build 8):

12. **Upload page & Telemetry Engine Calculations**:
    - [x] **Enforced strict odometer validation**: Odometer must strictly be greater than the previous fill-up's reading (`n > prevOdo`). Prevents input errors and displays clean inline validation message `Odometer must be greater than previous (X km) *`.
    - [x] **Fixed "get previously mentioned odometer value only" bug**: User-entered odometer is strictly preserved in `fromOdometer` during cycle recalculation so all cards, logs list, and edit dialogs display the actual odometer entered by the user rather than displacing with the previous cycle's odometer.

13. **Settings page**:
    - [x] **Custom Fuel Type Color Picker**: Each fuel type chip now displays an active color circle and border. Tapping any fuel chip opens a palette picker (matching the 8-color Python application palette) to change its color dynamically with instant local persistence.
    - [x] Connected fuel colors across Upload view dropdown items and Logs view badge indicators.

14. **Log-in page**:
    - [x] **DEV Google Sign-In handling**: In DEV, Supabase returns `Unsupported provider: provider is not enabled`. Instead of redirecting to a broken browser URL, the app now intercepts Google Sign-In in DEV and displays a clear DEV environment notice dialog guiding users to use Email/Password or Guest Mode on DEV, while noting Google Sign-In is active on PROD.
    - [x] **Password Sign-In clarification**: Clarified why "Incorrect email or password" occurs for accounts originally created with Google OAuth (no password hash in Supabase until a password is set/reset).
    - [x] **Password Reset with Link / Chrome URL Paste**: Supabase sends a recovery link (not a 6-digit code) that redirects to `localhost:3000` (`ERR_CONNECTION_REFUSED` on mobile). Implemented in-app link parsing with one-tap clipboard paste button: users copy/paste the email link or Chrome URL into the app, enter a new password, and the session is authenticated directly. Added quick toggle for users receiving 6-digit codes.

15. **Production & Guest Mode**:
    - [x] Completely removed Guest Mode on Production (`AppConfig.isDev == false`).
    - [x] Preserved Guest Mode on DEV (`AppConfig.isDev == true`).
    - [x] Production APK build withheld per user instructions (building DEV APK only until final confirmation).

### Completed in Version 2.6.0 (Build 9):

16. **Log-in page & Password Reset**:
    - [x] **Password Sign-In**: Confirmed working after updating user password hash in Supabase DB via query.
    - [x] **Handled `otp_expired` (403) Link Expiration**: Explained and handled single-use link consumption. When the email link is tapped, Chrome consumes the one-time token and redirects to `localhost:3000/#access_token=...`. If the user pastes the already-used email link, the app surfaces a clear, friendly explanation.
    - [x] **URL Normalization**: Enhanced `resetPasswordWithPastedLink` to parse and accept scheme-less browser URLs (`localhost:3000/#access_token=...`), URL fragments, or fresh direct email links.

17. **Production App & Database Connectivity**:
    - [x] **Database Verification**: Confirmed that the Production app (`EnvProd`) connects to the exact same old database (`https://hjprefmnofrqyjocihto.supabase.co`) used by the Python application (`Fuelapp/utils/supabase_client.py`), preserving all existing vehicle records, fill-up logs, and telemetry.
    - [x] **Built Production Release APK**: Compiled standalone `app-prod-release.apk` with Guest Mode disabled and native Google Sign-In active.
    - [x] **Built DEV Release APK**: Compiled updated `app-dev-release.apk` for testing.

### Completed in Version 2.7.0 (Build 10):

18. **Log-in page — Seamless Native Google Sign-In & User-Friendly Recovery**:
    - [x] **Seamless One-Tap Native Google Sign-In (PROD)**: Fixed missing `serverClientId` in `GoogleSignIn` initialization by binding `AppConfig.googleWebClientId` (`376743404421-kuj7117qutn4svh9lff4o3i97tom44br.apps.googleusercontent.com`). Selecting an account from the native Android sheet now directly issues an OpenID `idToken`, authenticating immediately via `client.auth.signInWithIdToken` without opening Chrome, without double account prompts, and without redirecting to `localhost:3000`.
    - [x] **6-Digit OTP Recovery Front-and-Center**: Set the 6-digit recovery code input as the primary default mode in the Reset Password dialog. Added clear instructions explaining that Supabase defaults to `{{ .ConfirmationURL }}` (link) and can be configured to send the 6-digit numeric OTP code (`{{ .Token }}`) directly in Supabase Dashboard $\rightarrow$ Authentication $\rightarrow$ Email Templates. Preserved optional link/URL paste mode as a secondary fallback.
    - [x] **Built & Verified Release APKs**: Rebuilt both `app-prod-release.apk` and `app-dev-release.apk`.

### Completed in Version 2.7.1 (Build 11):

19. **Log-in page — Google Sign-In Fallback & Keystore Fingerprint**:
    - [x] **Graceful OAuth Fallback on PROD**: When native Google Sign-In encounters `ApiException: 10` (from unregistered debug SHA-1 on Google Cloud Console), the app automatically falls back to Supabase Web OAuth. Because Option 1 was completed (`fuellogger://**` registered in Supabase), it redirects cleanly back into the app (`fuellogger://auth`) instead of showing an error.
    - [x] **Extracted Machine Signing Fingerprints**: Extracted exact SHA-1 (`A7:53:C5:F8:01:F0:BE:8D:68:B2:B3:0F:C2:EA:D5:54:6A:33:C1:E3`) and SHA-256 for one-step registration in Google Cloud Console.
    - [x] **Rebuilt Both APKs**: Compiled updated release APKs for Build 11.

### Completed in Version 2.8.0 (Build 12):

20. **Logs Page — Interactive Date Editing**:
    - [x] **Date Editing in Log Dialog**: Added interactive Date Picker (`showDatePicker`) with calendar indicator (`yyyy-MM-dd`) inside the Edit Log dialog on the Logs page.
    - [x] **Sync & Recalculate**: Updating a log's date now properly updates Supabase PostgreSQL and local cache, re-sorting runs chronologically and recalculating cycle telemetry automatically.

21. **Automated Data Entry — Bulk CSV Import (Method 2)**:
    - [x] **In-App CSV Import Engine**: Added `CsvService` and `CsvImportSheet` supporting `.csv` and `.txt` file selection via Android Storage Access Framework (`file_picker`), as well as direct text pasting.
    - [x] **Smart Header Detection**: Auto-detects custom column layouts (run #, date, fuel type, odometer, cost, liters, density, fill flag) and parses comma, semicolon, or tab delimited formats.
    - [x] **One-Tap Actions**: Included "Pick .CSV File", "Load Sample Data" (5-row instant preview), and "Copy Template" buttons.
    - [x] **Flexible Append vs. Replace**: Users can choose to append imported rows to the existing vehicle logbook or replace existing records.
    - [x] **Sample Template File**: Generated [`sample_fuel_data.csv`](file:///C:/Users/arunb/PycharmProjects/FuelLogger-Flutter/sample_fuel_data.csv) in the project workspace with realistic vehicle fuel telemetry data.
    - [x] **Accessible Everywhere**: Added quick-access CSV import buttons in Logs View (AppBar and empty state), Settings View (under Backup & Transfer), and Upload View.

22. **Upload Fill-Up — Half Tank Cycle Logic & Optional Odometer**:
    - [x] **Run # Progression Fixed for Partial Fills**:
      - If the last fill was Full Tank (e.g. Run #11), selecting 1st half tank now stays at Run #12.
      - If 2nd half tank is logged, it stays at Run #12.
      - Run #12 remains the same across all partial fills until closed by a Full Tank fill.
      - Mode toggle between Full and Half no longer decrements or alters the active cycle run number.
    - [x] **Odometer Optional for Half Tank Fills**:
      - Odometer reading is strictly optional on half tank / partial fills (defaults to `0 km`), avoiding false validation blockers.
      - Full tank fills continue to require the closing odometer reading to compute distance and mileage.
    - [x] **Cycle-in-Progress Visual Banner**: Displays a notice when a cycle is currently open with partial fill(s) so users immediately know which run number is being added to.

### Completed in Version 2.9.0 (Build 13):

23. **Settings page — Native CSV File Download & 4-Option Import**:
    - [x] **Direct .csv File Download**: Tapping "Download CSV" directly triggers native file saving (`FilePicker.saveFile`), saving the actual `.csv` file to the device without opening copy-paste text dialogs.
    - [x] **Streamlined 4-Option Import Modal**: Removed copy-paste text fields on mobile. Simplified import sheet to provide strictly 4 clean options:
      1. `Upload .csv`: Selects a local `.csv` file via native storage picker.
      2. `Download sample.csv`: Downloads a minimal template with only header and 1 sample row.
      3. `Append Data`: Keeps current logs and adds imported entries.
      4. `Full Replace Data`: Wipes current vehicle logs and replaces with file data.

24. **Logs page — Chronological Display & UI Cleanup**:
    - [x] **Correct Ordering by Run # and Timestamp**: Sorted logs with primary key on `runId` descending, secondary key on `createdAt` timestamp descending, and tertiary key on Full Tank (`F`) before Partial (`P`). When logging a half tank followed by a full tank under the same Run #, the full tank fill now cleanly sits on top (row 1), and earlier partial fills sit below it (row 2).
    - [x] **Removed Bulk Upload**: Cleaned up the Logs page by removing the bulk upload AppBar button and empty-state import button.

25. **Upload page — UI Focus**:
    - [x] **Removed Bulk Upload Shortcut**: Removed the bottom bulk upload link, keeping the screen 100% focused on single fill-up entries.

### Completed in Version 2.10.0 (Build 14):

26. **Settings Page — Dedicated "User Guide & FAQs" Bottom Sheet**:
    - [x] **Settings Card Entry**: Added an interactive "User Guide & FAQs" AMOLED card with navigation chevron in `SettingsView`.
    - [x] **Comprehensive Interactive Bottom Sheet** (`UserGuideSheet`): Covers 5 core topics:
      1. *Full Tank vs. Half Tank (Partial Fill)*: Explains cycle closure vs. open cycles, odometer requirements, and how mileage math accumulates.
      2. *Run Number Progression*: Details how cycles advance and how partial fills stay locked to the active Run #.
      3. *Editing & Correcting Logs*: Details calendar date picking, odometer/liters edits, and auto-recalculation.
      4. *Data Backup & CSV Transfer*: Explains Download CSV, Upload .csv, sample template, and Append vs. Replace options.
      5. *Account & Cloud Sync*: Details 150ms instant password login, native Google sign-in fallback, and offline-first cache syncing with Supabase PostgreSQL.
    - [x] **Zero Interruption for Existing Users**: Kept on-demand in Settings without annoying startup popups, keeping the app fast and clutter-free.

### Completed in Version 2.11.0 (Build 15):

27. **Calculation Engine & Supabase DB Sync — Forward-Linking Cycle Math & to_odometer Fix**:
    - [x] **Forward-Linking Cycle Architecture** (`TelemetryEngine.recalculateCycles`):
      - Fixed `to_odometer`: Each completed run's `to_odometer` is now populated with the next closing full fill's `from_odometer`.
      - Fixed `distance_traveled`: Strictly calculated as `to_odometer - from_odometer`.
      - Fixed `fuel_consumed`: Populated with the next run's `liters_to_fill` (plus any intermediate partial fills), representing the exact volume burned to drive that distance.
      - Fixed `calculated_mileage`: Computed as `distance_traveled / fuel_consumed`.
      - Fixed `cost_per_km`: Computed as `cost_per_ltr / calculated_mileage`.
      - Active Run: The latest fill has `to_odometer = 0`, `fuel_consumed = 0.0`, `distance_traveled = 0.0`, and `calculated_mileage = 0.0` while its fuel is currently in the tank.
    - [x] **Automatic Cloud DB Sync** (`SupabaseService.syncRecalculatedTelemetry`):
      - Recalculated values (`to_odometer`, `distance_traveled`, `fuel_consumed`, `calculated_mileage`, `cost_per_km`) are now synced/patched back to the Supabase PostgreSQL `fuel_logs` table automatically on load, add, edit, delete, and CSV import.
      - Resolves the issue where database rows previously remained at `to_odometer = 0`.
    - [x] **Logs UI Enhancements** (`LogsView`):
      - Odometer column now renders `from_odometer → to_odometer` (e.g. `1929 → 2229 km`) for closed cycles, and `1929 km` for open cycles.
      - Added `fuel_consumed` chip (e.g. `8.50 L used`) and `Active Run (Fuel currently in tank)` indicator on the latest fill.
      - Exported CSV includes both `from_odometer` and `to_odometer`.

### Completed in Version 2.12.0 (Build 16):

28. **Instant Cold-Start Cache, Single Default Fuel ("Standard petrol"), & Calculations UI Matching Old App**:
    - [x] **0ms Instant Cache-First Startup** (`GarageProvider`):
      - Synchronously initializes `_vehicles`, `_activeVehicle`, `_fuelLogs`, and `_summary` directly from `CacheService` on constructor initialization before the first frame is painted.
      - Completely eliminates the cold-start glitch where the app previously flashed "My Vehicle" and `-- km/l` for 1-2 seconds on startup.
      - Instant 0ms vehicle switching with background revalidation.
      - Safeguarded `SupabaseService.getVehicles()` to never auto-provision "My Vehicle" when local cached vehicles exist.
    - [x] **Standard Petrol & Single Default Fuel** (`CacheService`, `UploadView`):
      - Changed "Standard / Unleaded" to "Standard petrol" to clearly inform users it is petrol.
      - New users start with strictly ONE default fuel type: `['Standard petrol']` (removed multiple initial fuel types).
      - Automatically migrates existing caches containing "Standard / Unleaded" to "Standard petrol".
    - [x] **Calculations Page — Old App Styled Fuel Type Cards** (`CalculationsView`):
      - Each fuel type card box now features an accent border (`width: 1.5`) and indicator dot dynamically matching the user-defined fuel color (retrieved via `CacheService.getFuelColorHex(ftName)`).
      - Replaced hardcoded grey borders and red dots with user-defined theme colors, restoring the old app's visual style.

### Completed in Version 2.13.0 (Build 17):

29. **Multi-Account Cache Isolation & Strictly Single Default Fuel ("Standard petrol")**:
    - [x] **Multi-Account User Cache Clear & Reset** (`CacheService.clearUserCache`, `GarageProvider.resetOnSignOut`, `AuthProvider.signOut`):
      - When signing out or switching email accounts, `CacheService.clearUserCache()` resets cached vehicles, active vehicle, cached fuel logs, home summary metrics, and custom fuel colors.
      - `GarageProvider.resetOnSignOut()` wipes in-memory garage and fuel types so a new login starts with a 100% clean slate.
      - Automatic user account detection in `GarageProvider.loadGarage()` checks `currentUid != _loadedUserId` and triggers reset if an account switch occurs without restart.
    - [x] **Strictly Single Default Fuel Type ("Standard petrol")** (`CacheService.getCachedFuelTypes`):
      - Added migration check `_keyFuelTypesMigratedV2` in `CacheService` that detects and cleans legacy multi-default arrays (`XP95`, `XP100`, etc.) left behind on existing installs.
      - Any new user or freshly signed-in account is guaranteed to start with strictly ONE fuel type: `['Standard petrol']` (with its designated `#FF5252` red accent).
      - Fuel types dropdown in `UploadView` and chips in `SettingsView` now cleanly show only `Standard petrol` with the `➕ Add Custom Fuel Type...` option.
    - [x] **Fixed Cross-Account Vehicle Leaking** (`SupabaseService.getVehicles`):
      - When an authenticated user has zero vehicles in the Supabase cloud database, the app now auto-provisions a fresh `My Vehicle` for this user directly in Supabase.
      - Prevented brand new accounts from inheriting another user's locally cached vehicle.

30. **Interactive Developer Support Card with Direct Email Redirection** (`SettingsView`, `AndroidManifest.xml`):
    - [x] **Clickable AMOLED Support Card**:
      - Replaced the static support text in `SettingsView` with an interactive, AMOLED-styled Card featuring an amber mail icon, bold "Developer Support" title, and `arunbaalajiabs@gmail.com` subtitle.
    - [x] **Sleek "Email" Button**:
      - Added a clean `ElevatedButton.icon` with a send icon (`Icons.send_rounded`) and subtle red accent border that harmonizes with the AMOLED dark theme.
    - [x] **Direct Native Email Redirection** (`url_launcher`):
      - Tapping anywhere on the Card or tapping the "Email" button opens the device's native email client (Gmail, Outlook, etc.) with pre-filled `mailto:arunbaalajiabs@gmail.com?subject=Fuel%20Logger%20Support%20%26%20Feedback`.
      - Added the `<queries>` intent filter for `mailto:` to `android/app/src/main/AndroidManifest.xml` to comply with Android 11+ (API 30+) package visibility requirements.

### Completed in Version 2.14.0 (Build 18):

31. **Cloud Fuel Types & Custom Colors Persistence (`fuel_types` table) + Self-Healing Sync**:
    - [x] **Supabase Cloud Database Persistence** (`SupabaseService`):
      - Implemented full CRUD for fuel types and custom colors: `getCloudFuelTypes()`, `addCloudFuelType()`, `updateCloudFuelTypeColor()`, and `deleteCloudFuelType()` interacting directly with the Supabase `fuel_types` table scoped by `user_id`.
      - When any user adds a new fuel type, deletes a fuel type, or picks a custom color, the changes are stored permanently in the cloud database.
    - [x] **Self-Healing Fuel Types From Logs** (`GarageProvider.syncFuelTypesWithCloudAndLogs`):
      - When an existing user signs in, the engine checks their cloud `fuel_types` and their actual `fuel_logs`.
      - Any fuel types already present in their fill-up records (e.g. `XP95`, `XP100`, `Standard petrol`) are automatically populated into their active fuel types list, matching the Calculations breakdown 100%.
      - Fixes the bug where an existing user saw 3 fuel types in Calculations but only 1 in the Upload dropdown and Settings.
    - [x] **Strictly Single Default for New Users**:
      - When a brand new user signs in (0 cloud entries, 0 logs), their garage starts with strictly ONE fuel type: `Standard petrol` (with `#FF5252` accent).
      - If that user adds another fuel type or customizes a color, it is saved in the database under their `user_id`.
    - [x] **User-Scoped Local Cache** (`CacheService`):
      - Scoped cached fuel types and custom colors by `userId` (`cached_fuel_types_<userId>`, `cached_fuel_colors_<userId>`).
      - Preserves user customizations when signing in and out, preventing cross-account contamination while ensuring 0ms instant offline startup.

### Completed in Version 2.15.0 (Build 19):

32. **Backend Database Trigger Cleanup & Strict Single "Standard petrol" Default**:
    - [x] **Legacy Database Trigger Cleanup** (`GarageProvider.syncFuelTypesWithCloudAndLogs`):
      - Discovered that Supabase backend trigger `on_auth_user_created` calls `handle_new_user()`, which automatically populated new accounts with 4 legacy fuel types (`XP95`, `XP100`, `Unleaded`, `Power`).
      - Added automatic legacy trigger detection: when a user has zero fill-up logs and their cloud types match the 4 legacy trigger defaults, the client silently purges those 4 rows from the Supabase `fuel_types` table.
      - Resets their garage strictly to ONE default: `Standard petrol` (with `#FF5252` accent), matching user requirements.
    - [x] **Naming Standardization**:
      - Automatically renames any lingering `Standard / Unleaded` references from cloud database or cache into `Standard petrol`.
    - [x] **Supabase Trigger Schema Update** (`supabase_schema.sql`):
      - Updated `handle_new_user()` in SQL schema to insert only `('Standard petrol', '#FF5252')` for newly registered users.
    - [x] **Total Local Cache Isolation** (`CacheService`):
      - Removed global fallback keys (`cached_fuel_types`, `cached_fuel_colors`) when a user ID is available, ensuring zero cache crosstalk across different accounts tested on the same physical device.

### Completed in Version 2.16.0 (Build 20):

33. **Support Email Subject URI Encoding & Google Play Production Release Assets**:
    - [x] **Fixed Mailto Subject Plus Sign Bug** (`SettingsView._launchSupportEmail`):
      - Resolved issue where Dart's default `Uri(queryParameters: ...)` encoded spaces as `+`, causing email apps (like Gmail) to display `Fuel+Logger+Support+&+Feedback`.
      - Migrated to RFC 6068 standard URI percent-encoding (`%20`), formatting the subject cleanly as `Fuel Logger: Support & Feedback`.
    - [x] **Google Play Release Signing & Keystore Automation**:
      - Generated production upload keystore (`upload-keystore.jks`) using RSA 2048-bit key valid for 10,000 days.
      - Configured Gradle signing in `android/app/build.gradle.kts` with `key.properties` protection in `.gitignore`.
    - [x] **Production App Bundle (.aab)**:
      - Compiled signed Android App Bundle ready for Google Play Store upload.
    - [x] **Verified One-Tap Native Google Sign-In with Release Keystore**:
      - Registered production release keystore SHA-1 (`18:FF:D5:C5:1F:E6:4A:B7:30:D6:3A:0B:75:0C:D7:51:D9:37:C8:C6`) under Android OAuth 2.0 Client IDs in Google Cloud Console.
      - Confirmed 1-tap in-app native Google authentication without browser popups or passkey verification.

### Completed in Version 2.17.0 (Build 21):

34. **Strategic Log Privacy Disguise & Full Production AOT Code Obfuscation**:
    - [x] **Complete Log Privacy & Disguise** (`LogsView`):
      - Removed all derived calculation chips (Mileage, distance run, fuel consumed, cost/km) from each log card in Manage Logs.
      - Log cards strictly display only the user-entered raw fill-up values: Run #, Date, Fuel Cost (₹), Volume (L), User Odometer (km), and Fuel Type.
      - Prevents testers, competitors, software engineers, or BAs from reverse-engineering per-run intermediate calculations.
      - All comprehensive analytics remain aggregated and viewable in the "View Calculations" dashboard.
    - [x] **Production AOT Binary Obfuscation**:
      - Compiled release packages with `--obfuscate --split-debug-info=symbols/`.
      - Scrambles all Dart class names, functions, and internal calculation symbols into randomized identifiers inside the ARM64 `libapp.so` binary, protecting intellectual property from decompilation.

### Completed in Version 2.17.1 (Build 22):

35. **Decimal Odometer Precision & R8 DEX Optimization**:
    - [x] **Float/Decimal Odometer Support** (`FuelLog`, `TelemetrySummary`, `TelemetryEngine`, `CsvService`, `GarageProvider`, `UploadView`, `LogsView`):
      - Upgraded `fromOdometer`, `toOdometer`, and `latestOdometer` from `int` to `double` so vehicles recording fractional trip/odometer readings import and calculate accurately.
    - [x] **R8 Code Shrinking & Resource Minification** (`android/app/build.gradle.kts`, `proguard-rules.pro`):
      - Enabled `isMinifyEnabled = true` and `isShrinkResources = true` for release builds alongside Play Core / Google Sign-In keep rules to reduce bundle download size and improve DEX optimization.

### Completed in Version 2.17.2 (Build 23):

36. **Bulk CSV Upload Telemetry & Sequence Ordering Fix**:
    - [x] **Physical Sequence Ordering Over Date Tie-Breaks** (`TelemetryEngine`, `GarageProvider`, `SupabaseService`):
      - Added canonical `TelemetryEngine.sortAscending` and `TelemetryEngine.sortDescending` helpers ordering strictly by `runId` -> `fromOdometer` -> `date` -> partial/full flag -> `createdAt`, unifying ascending calculation and reverse-chronological UI display across cache load, vehicle switch, and cloud fetch.
      - Updated `SupabaseService.getFuelLogs` query order from `date DESC` to `run_id DESC, from_odometer DESC`.
      - Fixes bulk-import calculation corruption where a single out-of-order or mistyped CSV date caused subsequent runs to be skipped or linked backward to earlier odometer readings.
    - [x] **Resilient CSV Header Mapping, Date Scaling & Append Protection** (`CsvService`):
      - Prevented derived columns (`to_odometer`, `fuel_consumed`) and volume headers (`fuel_volume`, `fuel_qty`) from overwriting `from_odometer` or `fuel_type` during re-imports or custom CSV layouts, and isolated `fill_type` to `colFlag`.
      - Scoped positional fallback column reading exclusively to headerless CSVs (`!hasHeader`) so omitting optional columns (such as `date`) does not bleed adjacent values across fields.
      - Scaled blank-date fallback staggering dynamically by total CSV row count (eliminating the 30-row cap) and added `yyyy/MM/dd`, `MM/dd/yyyy`, and UTF-8 BOM handling.
      - Added `run_id` collision offset when appending CSVs numbered `1..N` onto vehicles with existing logs, and changed omitted fuel-type fallback to `'Standard petrol'`.
    - [x] **Production Release Build**:
      - Verified 0 analyzer errors/warnings (`dart analyze lib`) and passed CSV validation suite against real bulk upload datasets.
      - Built signed, obfuscated `app-prod-release.aab` (`Version - 2.17.2 (Build 23)`).




