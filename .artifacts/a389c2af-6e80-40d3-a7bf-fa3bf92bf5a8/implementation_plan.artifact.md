# Implementation Plan - Robust Offline Support & Data Visibility

Fix offline data loading issues where shop details are missing on the dashboard and staff management screen shows "Not logged in".

## User Review Required

> [!NOTE]
> We will implement a multi-layered fallback system using `SharedPreferences` to ensure that critical shop information (Name, Owner, ID) is always available, even when Firebase Auth is slow to respond or offline.

## Proposed Changes

### [Component: Utilities]

#### [MODIFY] [shop_utils.dart](file:///C:/Users/bhskh/amardokan_new/lib/utils/shop_utils.dart)
- Add static methods to save and retrieve shop details (name, owner, email) to/from `SharedPreferences`.
- Enhance `getShopId` to be more resilient offline.

### [Component: Dashboard]

#### [MODIFY] [dashboard_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/dashboard_screen.dart)
- Load shop details from `SharedPreferences` immediately in `initState`.
- Update local storage whenever data is successfully fetched from Firestore.
- Wrap the main content in a `RefreshIndicator` for manual data sync.

### [Component: Staff Management]

#### [MODIFY] [manage_staffs_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/manage_staffs_screen.dart)
- Remove hard dependency on `FirebaseAuth.instance.currentUser` for building the UI. Use `ShopUtils.getShopId()` instead.

### [Component: Customer Management]

#### [MODIFY] [customers_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/customers_screen.dart)
- Ensure the summary box (Today's Baki/Jama) is robust offline.
- Add `RefreshIndicator` support.

## Verification Plan

### Manual Verification
1.  **Dashboard Persistence**:
    - Open app online, verify shop details.
    - Close app, turn off internet, open app. Verify shop details are still visible.
2.  **Fingerprint/Quick Login**:
    - Ensure dashboard details load instantly after biometric authentication.
3.  **Offline Staff List**:
    - Access Staff Management screen while offline. Verify it loads the list instead of "Not logged in".
4.  **Offline Transaction Sync**:
    - Add a transaction offline, turn on internet, and verify it appears on the admin panel/other devices.
