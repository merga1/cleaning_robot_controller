/// Frontend-only demo startup behaviour.
///
/// While mock data is active the app opens straight on the dashboard with the
/// demo operator instead of showing onboarding and a sign-in form. Set this to
/// false at build/run time to exercise the normal first-launch flow:
///
/// ```bash
/// flutter run --dart-define=CLEANBOT_DEMO_AUTO_SIGN_IN=false
/// ```
const bool kDemoAutoSignIn = bool.fromEnvironment(
  'CLEANBOT_DEMO_AUTO_SIGN_IN',
  defaultValue: true,
);
