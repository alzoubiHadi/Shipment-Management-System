# Workflow Audit — `new-design` branch
2026-08-22 · against Mohammed's 18-point spec, item 17 (audit before coding)

No code changed in this pass. File:line references are as of the current `new-design` branch.

---

## 1–3. Registration + OTP + session-expired message

**Already fixed this session:** backend split so `register()` creates only the `User` row + OTP; two new authenticated endpoints (`DriverController::completeRegistration`, `CompanyController::completeRegistration`) create the actual Driver/Company/Truck/documents; `verifyOtp()`/`login()` return `registration_complete`; Flutter's `OtpVerificationScreen`/`LoggingInScreen` route into new `CompleteDriverRegistrationScreen`/`CompleteCompanyRegistrationScreen` when it's false; admin notification moved to the completeRegistration endpoints.

**Still open, found during this audit:**

- **`LoggingInScreen.dart` never checks `email_verified`.** `login()` already returns `email_verified` in the response and never blocks on it (`UserController::login`, unchanged), but the Flutter screen goes straight into the `registration_complete`/`approval_status` branching without checking `emailVerified` first. Net effect: a user who registered, got an OTP, and closed the app before verifying can log in and land somewhere other than the OTP screen — contradicts item 2 directly. **Fix:** in `LoggingInScreen._run()`, check `!response.emailVerified` before the `registrationComplete` check and route to `OtpVerificationScreen(email: ...)` in that case.
- **Re-registering with an unverified email is a permanent dead end.** `UserController::register()` validates `'email' => [..., 'unique:users,email']` unconditionally — an abandoned unverified signup blocks that email forever; the user gets a "the email has already been taken" error with no path forward except a manual DB fix. **Fix:** when the email belongs to an existing user with `email_verified_at === null`, update that row (name/password/otp) and resend OTP instead of failing uniqueness, rather than creating a second row.
- **`register()`'s validation-failure status code is 401, not 422.** `UserController.php` (register method) — `catch (ValidationException $e) { ... }, 401);`. Every other validation catch block in the codebase (`DriverController::completeRegistration`, `CompanyController::completeRegistration`, `DriverController::create`) already uses 422. This is what makes `error_messages.dart` need a special-cased "register/otp" 401 branch to avoid a false "session expired" — the real fix is the status code, not the client-side workaround. **Fix:** change that one `401` to `422`. The Flutter `apiErrorMessage()` 401-special-case for `register`/`otp` can stay as a defensive fallback but won't normally trigger once this is fixed.

## 4. Phone number

Done this session — shared `PhoneNumberField` widget + `combinePhoneNumber`/`splitPhoneNumber` in `utils/countries.dart`, applied to both registration wizards and all three phone-edit screens (`DriverPersonalInfoPage`, `CompanyProfileScreen`, `ChangesRequiredEditScreen`).

## 5. Driver ↔ Truck 1:1

**Enforced at the application layer only, not the schema.** `TruckController::addMyTruck()` (the only endpoint the Flutter app calls to register a truck) already blocks a second truck: `if (Truck::where('default_driver_id', $driver->id)->exists()) return 422 "You already have a registered truck..."`. `DriverController::completeRegistration()` creates exactly one `Truck` row per registration inside a DB transaction. Flutter has no multi-truck UI (`AddTruckPage` only calls `addMyTruck()`).

**Contradiction found (worth flagging per item 17):** the `create_trucks_table` migration's own docblock says *"a truck can be used by more than one driver... and a driver can drive more than one truck"* — directly contradicting the later `Driver.php` docblock that says 1:1 "is enforced at truck-registration time." The `Driver` model also defines **both** `trucks()` (`hasMany`) and `truck()` (`hasOne`) on the same `default_driver_id` column, and there's no DB-level `unique()` constraint. There's also one latent gap: `TruckController::create()` (the generic/admin-facing endpoint) has no existing-truck guard at all — it's not called from Flutter today, but it's a hole if it ever is.

**Recommendation (no migration needed):** add the same existing-truck guard to `TruckController::create()`, and either remove `Driver::trucks()` or clearly re-document it as "admin listing only, never assume >1 in app logic." A DB-level `unique('default_driver_id')` constraint would be a genuine defense-in-depth improvement but is optional — flagging it as a decision point rather than doing it unasked, since it's a migration touching `trucks`.

## 6. Admin must not directly edit driver/company data

**Already true in practice.** No live navigation path reaches an edit form: `ChangesRequiredEditScreen` (self-service) is the only screen that edits this data, reached only from `DriverApprovalStatusPage` when `approval_status == 'changes_required'`. `AddDriverPage`/`AddCompanyPage` do have a dormant "update mode" branch (triggered by passing a `driver:`/`company:` param), but the three places that navigate to them (`Companiespage.dart`, `Deletedcompanies.dart`, `DeletedDrivers.dart`) all call the const/no-arg constructor — that branch is dead code today. `Driverspage.dart`/`Companiespage.dart`/`DriverDetails.dart`/`CompanyDetailsPage.dart` already have their Edit buttons removed (with comments documenting why).

Backend `PUT /update/drivers/{driver}` and `PUT /update/companies/{company}` (permission:`crm`-gated) still exist and the Flutter service methods that call them (`DriverService.updateDriver()`, `CompanyService.updateCompany()`) still compile in, but nothing currently invokes them. **Per instructions, not removing these — flagging as legacy/unused**, reachable only if someone re-wires the dead branch in `AddDriverPage`/`AddCompanyPage` later.

The changes-required loop itself (request changes → self-edit → resubmit → pending) is confirmed intact end-to-end.

## 7. Remember Me — decision needed

Purely cosmetic. `LoginScreen.dart` has `bool _rememberMe = true;` and a checkbox that only calls `setState()` — nothing else in the file or in `_handleLogin()` reads it. Session persistence (`SharedPreferences['token'/'loggedIn']`, read on every launch in `main.dart`) is unconditional regardless of the checkbox. This is exactly the "visible control with no effect" the spec says not to leave.

**Two ways to close this — see question below.**

## 8. Forgot Password — decision needed

Tapping it only shows a snackbar ("Contact your admin to reset your password") — no navigation, no API call. No self-service password-reset route exists on the backend at all (only an *admin-initiated* sub-admin reset, unrelated). So today's behavior already doesn't "pretend to work" — it's honest, just via a snackbar instead of a disabled/hidden control.

**Two ways to close this — see question below.**

## 9. Logout / token invalidation

**No `POST /logout` route exists in `routes/api.php` at all.** Flutter's `logout_helper.dart` only does `SharedPreferences.clear()` then navigates to `SplashPage` — the Sanctum token is never revoked server-side; it stays valid until natural expiry (if any is configured) or forever. **Fix:** add `POST /logout` → `$request->user()->currentAccessToken()->delete()`, call it from `confirmAndLogout()` before clearing local prefs, and per the spec's own instruction, don't let a failed network call trap the user — clear local state regardless and just don't claim server-side revocation succeeded.

## 10. Active-trip logout protection

Works, but the check at the moment of logout is not fresh: it reads `DriverLocationReporter.hasActiveTrip` (a `ValueNotifier` updated only by a 45-second background poll against the existing lightweight `GET /driver/{id}/current-trip` endpoint). On a network hiccup the poller deliberately leaves the value unchanged (stale-but-not-wrong is the existing design), but right after a fresh app launch — before the first poll tick completes — the value is unset/default rather than server-verified, which could let a driver with an active trip log out in that narrow window. **Fix:** at the moment `confirmAndLogout()` runs, do one fresh `fetchCurrentTrip()` call (the same lightweight endpoint already used by the poller — not the full shipment list) and gate on that result instead of trusting the cached notifier.

## 11. Approval workflow states

Correct as designed (Pending/Changes-Required/Rejected all blocked from Home, all can reach their status/edit screens) — the only real gap is the item-2 login routing issue above: an unverified account currently skips past this entirely instead of being sent to OTP first.

## 12. Compliance vs approval vs availability

**Already correctly separated — no issue found.** `drivers` has three genuinely independent columns: `status` (available/busy/unavailable — operational), `approval_status` (pending/approved/rejected/changes_required — admin workflow), `compliance_status` (active/warning/suspended/banned/action_required/expiring_soon/pending_review — safety axis). `DriverController::suspend()`/`reactivate()` and the immediate-freeze compliance-report path all write only `compliance_status`; nothing in `Controllers/` or `Services/` was found writing suspend/ban states into `approval_status` or `status`. No change needed here.

## 13. Truck documents

Required at registration: `truck_number`, `truck_type`, `truck_license_file`. Optional at registration: `truck_license_expiry`, `permit_type`, `truck_insurance_file`/`expiry`, `truck_inspection_file`/`expiry`. Matching eligibility (`MatchingService::eligibleDriversQuery`) is permissive on missing data — a null expiry passes, only an actually-*expired* date blocks — plus a separate compliance grace-window check (`ComplianceService`, 3 days internal / 3 months external) that does eventually require license/insurance/technical-inspection presence for `expiring_soon` drivers. This is internally consistent, not contradictory — flagging it as documented behavior rather than a bug; no code change proposed unless the business rule itself should be stricter.

## 14. Error handling

Duplicate email/license/truck-number already return clean per-field validation messages (not raw Laravel/SQL text) through the existing `errors` envelope, which `apiErrorMessage()` on the Flutter side already formats reasonably. The one real defect is the register() 401-vs-422 status code covered in section 3 above. No SQL error / stack trace leakage found anywhere in the controllers reviewed.

---

## Summary: what needs code changes

| # | Item | Migration needed? | Risk |
|---|---|---|---|
| 2/3 | Login doesn't check `email_verified`; register() re-registration lockout; register() 401→422 | No | Low — isolated, well-understood |
| 5 | Guard `TruckController::create()`; tidy `Driver::trucks()` vs `truck()` | No (optional unique constraint if you want it) | Low |
| 6 | None required — already correct; optionally strip dead edit-branch code in `AddDriverPage`/`AddCompanyPage` | No | None |
| 7 | Remember Me | No | Low — pending your decision below |
| 8 | Forgot Password | Only if implementing (Laravel's password_reset_tokens table may already exist — need to check) | Low if hiding; medium if implementing (email delivery, new screens) |
| 9 | Add real `/logout` + Sanctum revoke | No | Low |
| 10 | Fresh active-trip check at logout instead of cached notifier | No | Low |
| 11–14 | No code changes — verification/documentation only | — | — |

No item requires a schema migration to satisfy the stated business rules; the only optional migration is a defense-in-depth unique constraint on `trucks.default_driver_id` if you want it (item 5).
