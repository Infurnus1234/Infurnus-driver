# INFURNUS — Comprehensive Research & Implementation Plan Report

## 1. CURRENT ARCHITECTURE
- **System Topology:** Monorepo/Multi-repo architecture consisting of (a) Customer/User App, (b) Driver App (`Infurnus-driver`), and (c) Shared INFURNUS Backend (Node.js/NestJS with TypeScript, PostgreSQL database, and Socket.IO real-time event gateway).
- **Communication Layer:** REST API endpoints for authentication, profile management, vehicle registration, and financial reconciliation; Socket.IO real-time events for ride dispatch, matching, status updates, and accept/reject notifications.
- **State Management:** Flutter `Provider` pattern (`AppState`) managing session state, active mode switching (Driver vs. Fleet Owner), online/offline status, vehicle catalog lookup, and live trip state.

## 2. EXISTING FARE FLOW
- **Pricing Engine:** Vehicle-wise pricing and fare calculation are pre-implemented on the backend (calculating base fare, distance rate, category multipliers, and surge pricing).
- **Frontend Presentation:** The Driver App and User App receive the generated fare (e.g., ₹106.00) from the backend response or ride payload.
- **Authoritative Source:** The server-generated final fare is authoritative. Frontend displays the fare but does not perform pricing calculations.

## 3. EXISTING RIDE LIFECYCLE
- **States:** `PENDING` (created) ➔ `MATCHING` ➔ `DISPATCHED` ➔ `ACCEPTED` (Driver assigned) ➔ `ARRIVED` ➔ `IN_PROGRESS` ➔ `COMPLETED` / `CANCELLED`.
- **State Transitions:** Managed authoritatively by the backend ride service and ride state machine, preventing invalid state jumps.

## 4. EXISTING DRIVER MATCHING/DISPATCH FLOW
- **Matching Service:** Backend matching service queries eligible online drivers within the service radius whose approved vehicle category matches the booking category (e.g., Bike ➔ Bike driver, Sedan ➔ Sedan driver, Logistics ➔ Truck/Container).
- **Dispatch:** Real-time Socket.IO event dispatched to candidate drivers.

## 5. EXISTING ACCEPT/REJECT IMPLEMENTATION
- **Driver Actions:** Incoming ride card displays Accept / Reject buttons.
- **Backend Validation:** Accept endpoint validates driver approval, online status, vehicle category, and active ride lock before updating assignment state.

## 6. EXISTING DATABASE STRUCTURE
- **Tables:** `users`, `drivers`, `vehicles`, `driver_applications`, `rides` (or `bookings`), `transactions`, `wallets`.
- **Monetary Storage:** Standardized on integer representation in **paise** (e.g., `10600` paise for ₹106.00) to avoid floating-point rounding inaccuracies.

## 7. EXISTING PAYMENT/DRIVER EARNING FLOW
- **Earnings & Payouts:** Wallet balance, transaction ledger, and payout history tables record provider earnings.

## 8. COMMISSION IMPLEMENTATION GAP
- **Gap:** 10% platform commission calculation needs explicit server-side persistence upon ride completion.
- **Rule:** Final Fare = ₹106.00 ➔ Commission (10%) = ₹10.60 (1060 paise) ➔ Driver Net Earning = ₹95.40 (9540 paise).
- **Rounding Rule:** Integer rounding on paise representation (`Math.round(finalFarePaise * 0.10)`), ensuring sum of commission + net earning equals exact final fare.

## 9. ACCEPT/REJECT IMPLEMENTATION GAP
- **Gap:** Race condition handling during concurrent driver acceptances requires atomic database transactions (`SELECT FOR UPDATE` or distributed locking) to ensure only the first accepting driver wins.

## 10. USER APP FILES INVOLVED
- Customer booking creation screen, live ride tracking status screen, Socket.IO ride status listener.

## 11. DRIVER APP FILES INVOLVED
- [`lib/screens/driver/driver_dashboard_screen.dart`](file:///C:/Users/abhis/AndroidStudioProjects/Infurnus-driver/lib/screens/driver/driver_dashboard_screen.dart) (Incoming ride request card, Accept/Reject buttons)
- [`lib/screens/driver/ride_details_screen.dart`](file:///C:/Users/abhis/AndroidStudioProjects/Infurnus-driver/lib/screens/driver/ride_details_screen.dart) (Trip lifecycle, status updates)
- [`lib/screens/driver/earnings_screen.dart`](file:///C:/Users/abhis/AndroidStudioProjects/Infurnus-driver/lib/screens/driver/earnings_screen.dart) (Net earnings and commission display)
- [`lib/providers/app_state.dart`](file:///C:/Users/abhis/AndroidStudioProjects/Infurnus-driver/lib/providers/app_state.dart) (Booking acceptance and eligible booking filter)
- [`lib/services/api_service.dart`](file:///C:/Users/abhis/AndroidStudioProjects/Infurnus-driver/lib/services/api_service.dart) (Accept/Reject REST endpoints)

## 12. BACKEND FILES INVOLVED
- `src/modules/rides/services/matching.service.ts`
- `src/modules/rides/services/ride.service.ts`
- `src/modules/rides/controllers/ride.controller.ts`
- `src/modules/rides/repositories/driver.repository.ts`

## 13. DATABASE MIGRATIONS INVOLVED
- `migrations/006_create_vehicles.sql`
- `migrations/026_expand_vehicles_and_create_ratings.sql`
- `migrations/029_provider_driver_fleet_enhancements.sql`

## 14. EXACT CHANGES REQUIRED
1. **Backend Commission & Net Earning Calculation:** On ride completion, compute `commissionPaise = Math.round(finalFarePaise * 0.10)` and `driverEarningPaise = finalFarePaise - commissionPaise`, persisting both in the ride ledger and updating driver wallet.
2. **Backend Atomic Accept/Reject:** In `ride.service.ts`, wrap acceptance logic in a database transaction with row-level locking (`FOR UPDATE`) to prevent double acceptance.
3. **Driver App UI Integration:** Bind Accept and Reject actions to call backend APIs and update local booking state via `AppState`.

## 15. TEST CASES REQUIRED
- Test 1: 10% commission calculation accuracy with paise integer representation (`10600` ➔ `1060` commission, `9540` earnings).
- Test 2: Concurrent ride acceptance race condition (only Driver A succeeds, Driver B receives conflict error).
- Test 3: Vehicle category matching (Bike booking reaches Bike driver only).

## 16. RISKS / EDGE CASES
- Floating point inaccuracies in currency (mitigated by using integer paise representation).
- Concurrent acceptance race conditions (mitigated by database row-level locking).
- Driver timeout on pending requests (mitigated by automatic re-dispatch timeout mechanism).
