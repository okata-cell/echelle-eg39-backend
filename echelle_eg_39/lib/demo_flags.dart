// © 2026 ÉCHELLE EG39 — Tous droits réservés — EG39-20261106-E5EF

// Compile-time feature flags for demo/testing
// Enable with: flutter run --dart-define=DEMO_PAYMENTS=true
// In production builds, omit the define so the demo remains disabled by default.

const bool kDemoPaymentsEnabled = bool.fromEnvironment('DEMO_PAYMENTS', defaultValue: false);
