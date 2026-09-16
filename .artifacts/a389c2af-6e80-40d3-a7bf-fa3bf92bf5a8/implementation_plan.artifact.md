# Implementation Plan - Dashboard Calculator Feature

Add a full-featured calculator accessible to all users (Admin and Staff) from the Dashboard.

## User Review Required

> [!NOTE]
> The calculator will be implemented as a Modal Bottom Sheet for easy access without leaving the current screen. It will be triggered from a new icon in the Dashboard's action bar or a floating button.

## Proposed Changes

### [Component: Dashboard UI]

#### [MODIFY] [dashboard_screen.dart](file:///C:/Users/bhskh/amardokan_new/lib/screens/dashboard_screen.dart)
- Add a calculator icon to the AppBar or a floating button to trigger the calculator.
- The calculator will be accessible to both Admin and Staff roles.

### [Component: Widgets]

#### [NEW] [calculator_widget.dart](file:///C:/Users/bhskh/amardokan_new/lib/widgets/calculator_widget.dart)
- Create a standalone `CalculatorWidget` that handles all calculation logic and UI.
- Features: Addition, Subtraction, Multiplication, Division, Clear, and Delete.

## Verification Plan

### Manual Verification
- Open the Dashboard as an Admin and verify the calculator icon is present and functional.
- Open the Dashboard as a Staff and verify the calculator icon is present and functional.
- Perform various calculations (e.g., 10 + 20, 50 * 2, 100 / 4) to ensure accuracy.
- Test the Clear and Delete buttons.
