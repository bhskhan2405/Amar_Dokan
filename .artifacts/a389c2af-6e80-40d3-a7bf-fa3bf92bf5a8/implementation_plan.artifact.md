# Implementation Plan - Persistent Session & Data Stability

Fix the issue where logging out and re-logging via PIN/Fingerprint causes missing shop details and subscription status.

## User Review Required

> [!NOTE]
> We will modify the logout logic to preserve essential identifiers (Shop ID, Shop Name, etc.) in `SharedPreferences`. This ensures that a subsequent offline or quick login (PIN/Biometric) has enough context to restore the user's environment immediately.

## Proposed Changes

### [Component: Settings]

#### [MODIFY] [settings_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/settings_screen.dart)
- Update the logout function to *NOT* remove critical background data like `admin_uid` and cached shop details.
- Only clear sensitive data if `remember_phone` is false.

### [Component: Login]

#### [MODIFY] [login_register_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/login_register_screen.dart)
- Ensure that upon re-login, the app immediately re-validates the cached session data against Firestore.

## Verification Plan

### Manual Verification
1.  **Persistent Logout**:
    - Log in, verify premium status.
    - Go to Settings -> Logout.
    - Log back in using Fingerprint/PIN.
    - Verify that the Dashboard loads shop details and Premium status instantly without infinite loading.
2.  **Offline Verification**:
    - Repeat the logout/login process while offline. Verify that cached data is displayed.
