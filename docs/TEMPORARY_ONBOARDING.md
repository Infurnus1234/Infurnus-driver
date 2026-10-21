# Temporary local onboarding

The existing login screen has one optional secondary action: **Onboarding Without Login**. It opens the existing Driver onboarding screens using a memory-only, restricted test session. Login, Sign-up and OTP remain available unchanged.

For isolated testing only:

```sh
flutter build apk --debug --dart-define=DRIVER_TEST_API_BASE_URL=http://127.0.0.1:3302 --dart-define=DRIVER_TEST_ONBOARDING_ENABLED=true
```

On a USB-connected physical phone, forward the local port with `adb reverse tcp:3302 tcp:3302`. The backend must independently enable `DRIVER_TEST_ONBOARDING_ENABLED=true` in development/test and use a disposable local database. Its default is disabled; staging and production reject this namespace regardless of the flag.

The button is hidden without the build flag, without backend availability, and in release mode. Temporary sessions cannot reach dashboards, rides, Admin or fleet functionality, and are not persisted or refreshed. Existing forms, document policy, upload validation and review requirements remain in force.

The test user stays a Driver. An authorized separate Admin creates its vehicle through the existing backend workflow; this button does not grant vehicle-creation permissions or approve a driver or vehicle.

To disable, set the backend flag to `false` and restart it. A temporary session is cleared on its next rejected request and returns to login. Rebuild without the define to remove the button. Existing test database records remain available for inspection until separately cleaned up.
