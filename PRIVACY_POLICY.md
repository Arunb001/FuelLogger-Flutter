# Privacy Policy for Fuel Logger

**Last Updated:** November 26, 2026  
**Effective Date:** November 23, 2026

Welcome to **Fuel Logger** ("we", "our", or "us"). This Privacy Policy explains how we collect, use, store, and protect your information when you use our mobile application ("App"), developed by Arun Baalaji.

By installing and using Fuel Logger, you agree to the collection and use of information in accordance with this Privacy Policy.

---

## 1. Information We Collect

### A. Information You Provide Directly
* **Account Information:** When you sign up or log in using Email/Password or Google Sign-In, we collect your email address and authentication identifier to authenticate your account and synchronize your data across devices.
* **Vehicle & Telemetry Data:** Vehicle nicknames, fuel fill-up logs (odometer readings, fuel volume in liters, fuel price/cost, fuel type, fuel density, optional fuel station name, optional personal remarks, and timestamps), vehicle service & maintenance records (service date, odometer, service type, cost, workshop name, next service target, and notes), and custom fuel type preferences.

### B. Automatically Stored Local Data
* **Local Offline Cache:** To provide fast, offline-first performance, vehicle preferences, recent telemetry calculations, notification inbox history, reminder settings, and fuel types are cached locally on your device using Android private storage (`SharedPreferences`).
* **Local Notification Permission (`POST_NOTIFICATIONS`):** With your permission on Android 13+, Fuel Logger schedules local on-device reminders for upcoming maintenance due dates/km, fill-up check-ins, mileage milestones, and occasional in-app announcements/wishes. Notifications can be turned off anytime in the App's Settings or Android System Settings.

### C. Information We DO NOT Collect
* **No Real-Time GPS / Location Data:** We do not track, collect, or monitor your geographic location or GPS coordinates.
* **No Financial Information:** We do not process payments, store credit card numbers, or collect banking details.
* **No Device Sensors or Media:** We do not access your contacts, camera, microphone, SMS, or call logs.
* **No Third-Party Advertising Trackers:** Fuel Logger contains zero third-party advertising SDKs or tracking networks.

---

## 2. How We Use Your Information

We use the collected information exclusively to:
* Provide, calculate, and display fuel economy, average mileage, cost per kilometer, maintenance schedules, and distance telemetry.
* Deliver local vehicle maintenance reminders, fill-up nudges, and milestone notifications on your device.
* Synchronize your garage, fill-up records, and service history securely with cloud storage (Supabase PostgreSQL).
* Authenticate your identity and protect against unauthorized access.
* Allow seamless data export and backup (CSV transfer).

---

## 3. Data Storage & Security

* **Encryption in Transit:** All communication between the Fuel Logger application and our cloud database is strictly encrypted using HTTPS / TLS (Transport Layer Security).
* **Database Isolation:** User data in Supabase PostgreSQL is strictly isolated using PostgreSQL **Row Level Security (RLS)** policies. No user can access or view another user's garage, logs, or telemetry.
* **Local Security:** Local device cache is private to the application sandbox on Android and inaccessible to other apps.

---

## 4. Third-Party Services

Fuel Logger utilizes the following third-party infrastructure to deliver core functionality:
* **Supabase (Backend as a Service):** Used for cloud database hosting (PostgreSQL) and user authentication. Supabase complies with SOC 2 Type II and GDPR standards.
* **Google Play Services (Google Sign-In):** Used solely for optional, native one-tap authentication if you choose to sign in with your Google Account.

---

## 5. Data Retention & Deletion

* **In-App Deletion:** You can delete individual fuel logs, vehicle profiles, or custom fuel types directly from within the app at any time. Deletion reflects immediately on your device and in the cloud database.
* **Complete Account & Data Deletion:** You have the right to request permanent deletion of your account and all associated data stored in our database.
  * To request account deletion, send an email to **arunbaalajiabs@gmail.com** with the subject line **"Fuel Logger - Account Deletion Request"** from the email associated with your account.
  * We will permanently purge your profile, vehicles, fuel logs, and telemetry from all active databases and backups within 30 days.

---

## 6. Children's Privacy

Fuel Logger is not intended for use by children under the age of 13. We do not knowingly collect personal identifiable information from children. If you become aware that a child has provided us with personal data, please contact us immediately so we can remove it.

---

## 7. Changes to This Privacy Policy

We may update our Privacy Policy periodically to reflect new features or legal requirements. Any changes will be posted within this document with an updated "Last Updated" date.

---

## 8. Contact Us

If you have any questions, feedback, or concerns regarding this Privacy Policy or your data, please contact:

* **Developer:** Arun Baalaji
* **Email:** [arunbaalajiabs@gmail.com](mailto:arunbaalajiabs@gmail.com)
* **Application:** Fuel Logger (Android)
