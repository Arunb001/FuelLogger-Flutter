# Fuel Logger — Flutter Native Android App
## Project Instructions, Roadmap & Test Reviews Log

---

## 1. Project Overview

**Fuel Logger** is a 100% native **Flutter** application for Android (specifically optimized for high-refresh-rate displays like the **Samsung Galaxy S24 Ultra** at 120 Hz). It provides seamless vehicle fuel logging, comprehensive 16-column real-world telemetry calculations (exact cycle math matching the original Python engine), local caching, and instant cloud sync with **Supabase PostgreSQL**.

### Tech Stack & Architecture
- **Framework**: Flutter (Channel Stable 3.50.0 / Dart 3.14.0)
- **Design System**: AMOLED Dark Theme (`#14161C` background, `#1E222D` card surface, `#FF5252` primary accent, `#69F0AE` mileage green, `#40C4FF` distance blue)
- **State Management**: `Provider` (`GarageProvider` for active vehicle/logs/telemetry, `AuthProvider` for reactive sessions)
- **Backend / Database**: Supabase Cloud PostgreSQL (Dual Environment: Dev & Production)
- **Local Persistence**: `shared_preferences` for vehicle preferences, customization, and instant startup cache
- **Flavors**:
  - **Dev**: Package `com.fuellogger.app.dev`, App Name `"Fuel Logger (DEV)"`
  - **Prod**: Package `com.fuellogger.app`, App Name `"Fuel Logger"`
- **CI/CD Build Automation**: GitHub Actions (`.github/workflows/build_apk.yml`) building both flavor APKs on every push

---

## 2. Implemented Features & Architecture

### 1. Authentication (`lib/views/auth/login_view.dart`)
- **Direct Password Sign-In & Registration**: Fast 150ms login directly against PostgreSQL, avoiding free-tier email rate limits.
- **OTP / Magic Link Verification**: 6-digit verification code input with automatic deep linking (`fuellogger://auth`).
- **Sanitized Errors**: No raw PostgREST error codes (e.g. `PGRST303`); clear human-readable notices.

### 2. Home Dashboard (`lib/views/home/home_view.dart`)
- **Dynamic Vehicle Banner**: Renders active vehicle name, model, plate, custom color gradient, and vehicle icon (`directions_car`, `two_wheeler`, etc.).
- **Top 2 Metric Tiles**: Total Average Mileage (`km/l`) and Total Driven Distance (`km`).
- **Quick Action Cards**: "Log New Fill-Up" and "Calculations & Analytics".
- **Vehicle Switcher**: Instant bottom sheet switcher to switch between multiple vehicles.

### 3. Upload Fill-Up (`lib/views/upload/upload_view.dart`)
- **Automatic S.No / Run #**: Sequentially increments from the last logged run.
- **Full vs. Partial Fill Modes**: Toggle buttons for full tank vs. partial fill.
- **Strict Numeric Inputs**: Only numeric and decimal characters accepted.
- **Instant Telemetry Preview**: Calculates distance, mileage, and cost-per-km before submitting.

### 4. Calculations & Breakdown (`lib/views/calculations/calculations_view.dart`)
- **Full 16-Column Telemetry**: Average mileage, total cost, total distance, total fuel consumed, average cost per km, and fuel efficiency.
- **Fuel Type Breakdown**: Aggregates usage, litres, and total spend by fuel grade (e.g., Petrol, XP95, Shell V-Power, Diesel).

### 5. Log History (`lib/views/logs/logs_view.dart`)
- Reverse chronological display of all fill-ups.
- Tap to edit any previous fill-up entry.
- Swipe to delete with confirmation.

### 6. Settings & Garage Management (`lib/views/settings/settings_view.dart`)
- Vehicle customization: rename, change icon, choose theme color.
- Add new vehicle or delete vehicle.
- Password change and direct sign-out.

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

