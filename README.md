# Fuel Logger (Flutter Edition) ⛽📱

A native **Flutter** mobile fuel and vehicle telemetry tracking application built with a high-performance **AMOLED dark theme** and backed by **Supabase Cloud Database**.

---

## 🌟 Key Features

- **100% Native Flutter Performance**: 60–120 Hz smooth scrolling, responsive touch interactions, sub-200ms cold startup.
- **Dual Environments (Dev & Prod)**:
  - **Dev**: Connects to `https://qjwuajdcyrdlnjplvtsr.supabase.co` with package ID `com.fuellogger.app.dev`
  - **Prod**: Connects to `https://hjprefmnofrqyjocihto.supabase.co` with package ID `com.fuellogger.app`
  - Both Dev and Prod APKs can be installed simultaneously on your Android device!
- **AMOLED Dark Theme**: Deep black (`#14161C`) background, vibrant emerald green mileage metrics (`#69F0AE`), distance blue (`#40C4FF`), and customizable vehicle gradient banners.
- **Multi-Vehicle Garage**: Manage multiple vehicles (bikes, cars, trucks), rename them, and customize icon and theme colors.
- **16-Column Telemetry Cycle Engine**: Real-world distance calculations, rolling partial fill aggregation, fuel cost, and cost per kilometer.
- **Automated Cloud CI/CD**: GitHub Actions workflow builds native APKs on every push without requiring local Android Studio.

---

## 🚀 Building & Running

### Build with GitHub Actions (Zero Local Setup)
Every push to `master` automatically triggers `.github/workflows/build_apk.yml` to compile both `fuel-logger-dev-apk` and `fuel-logger-prod-apk` downloadable directly from GitHub Actions Artifacts.

### Local Development (If Flutter is installed)
```bash
# Run DEV
flutter run --flavor dev -t lib/main_dev.dart

# Run PROD
flutter run --flavor prod -t lib/main_prod.dart

# Build APKs locally
flutter build apk --flavor dev -t lib/main_dev.dart --release
flutter build apk --flavor prod -t lib/main_prod.dart --release
```
