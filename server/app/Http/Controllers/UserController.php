<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\User;
use App\Notifications\AppPushNotification;
use App\Notifications\OtpCodeNotification;
use App\Support\PasswordPolicy;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class UserController extends Controller
{
    /**
     * 2026-08-28 (security): max wrong-code guesses allowed against a
     * single OTP before verifyOtp() locks it out — see that method and
     * the otp_attempts migration/column for the full rationale.
     */
    private const MAX_OTP_ATTEMPTS = 5;

    /**
     * Self-registration for companies and drivers (UC-2/UC-3). Anyone can
     * create their own account this way — the admin never creates a
     * company's or a driver's account. Every driver is an independent
     * operator who owns their own truck(s); there is no platform-owning
     * company, so no "internal fleet" distinction exists.
     *
     * 2026-08-29 (real backend split, not a Flutter-only workaround): this
     * now creates ONLY the User row and sends the OTP. It used to also
     * create Driver/Company + documents + Truck in the same transaction,
     * which meant OTP verification could only happen at the very end of a
     * long multi-step form. The driver/company profile (documents, truck,
     * license, etc.) is now submitted separately, AFTER OTP success, via
     * DriverController::completeRegistration() / CompanyController::
     * completeRegistration() — both authenticated endpoints, since by then
     * the user already has a token. See those two methods for the rest of
     * what register() used to do.
     *
     * This does NOT log the user in: the account is created with
     * email_verified_at = null and a fresh OTP is sent (UC-4). The account
     * only becomes usable after verifyOtp() succeeds, and even then a
     * driver/company still needs to complete their profile (see above) and
     * then get Super Admin final approval.
     */
    public function register(Request $request)
    {
        $type = $request->type ?? 'driver';

        if (! in_array($type, ['driver', 'company'], true)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid registration type.',
            ], 422);
        }

        // Normalize BEFORE validate() runs, since the 'unique:users,email'
        // rule below does an exact string match against the DB — without
        // this, "New@Example.com" would sail past the uniqueness check
        // against an existing "new@example.com" row (Postgres compares
        // case-sensitively), only to then collide with users.email's real
        // unique constraint when User::create() below inserts it already
        // lowercased by the model mutator.
        if ($request->filled('email')) {
            $request->merge(['email' => User::normalizeEmail($request->input('email'))]);
        }

        // 2026-08-29 (audit item 2): email uniqueness is deliberately NOT a
        // validate() rule anymore — it's checked manually right below, so an
        // abandoned unverified signup (registered, OTP sent, app closed
        // before entering it) can be resumed instead of permanently
        // blocking that email address with an unconditional "already
        // taken" error and no way forward.
        $rules = [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255'],
            'password' => ['required', 'confirmed', PasswordPolicy::rules()],
        ];

        try {
            $validated = $request->validate($rules);
        } catch (ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => $e->errors(),
            ], 422);
        }

        $existing = User::where('email', $validated['email'])->first();

        if ($existing && $existing->email_verified_at) {
            // A real, already-verified account owns this email — this is a
            // genuine duplicate, same wording 'unique:users,email' used to
            // produce, kept as a validation-shaped error so the Flutter
            // side's existing per-field error rendering still applies.
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => ['email' => ['The email has already been taken.']],
            ], 422);
        }

        $otp = $this->generateOtp();

        if ($existing) {
            // Unverified leftover from an abandoned signup — reuse the row
            // instead of failing uniqueness: update it to the freshly
            // submitted name/type/password and send a new OTP. Anything
            // that depended on the OLD name/password (nothing does yet,
            // since no Driver/Company row exists until completeRegistration)
            // is safely overwritten.
            $existing->update([
                'name' => $validated['name'],
                'type' => $type,
                'password' => Hash::make($validated['password']),
                'otp_code' => $otp,
                'otp_expires_at' => now()->addMinutes(10),
                'otp_attempts' => 0,
            ]);
            $user = $existing;
        } else {
            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'type' => $type,
                'password' => Hash::make($validated['password']),
                'otp_code' => $otp,
                'otp_expires_at' => now()->addMinutes(10),
                'otp_attempts' => 0,
            ]);
        }

        $user->notify(new OtpCodeNotification($otp));

        return response()->json([
            'success' => true,
            'message' => 'Registered successfully. Please verify your email with the code we just sent.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'type' => $user->type,
                ],
                'requires_otp_verification' => true,
            ],
        ], 201);
    }

    /**
     * UC-4: verify the OTP code emailed at registration time. Only after
     * this succeeds does the account become usable and receive an API
     * token — approval_status is a separate, later step handled by Super
     * Admin.
     */
    public function verifyOtp(Request $request)
    {
        $validated = $request->validate([
            'email' => ['required', 'email'],
            'otp_code' => ['required', 'string'],
        ]);

        // Stored emails are always lowercase (see User::setEmailAttribute());
        // normalize the lookup value the same way so a different
        // capitalization at verify-otp time still matches.
        $user = User::where('email', User::normalizeEmail($validated['email']))->first();

        if (! $user) {
            return response()->json(['success' => false, 'message' => 'Account not found.'], 404);
        }

        if ($user->email_verified_at) {
            return response()->json(['success' => false, 'message' => 'Email already verified.'], 409);
        }

        if (! $user->otp_code || ! $user->otp_expires_at || $user->otp_expires_at->isPast()) {
            return response()->json(['success' => false, 'message' => 'This code has expired. Please request a new one.'], 422);
        }

        // 2026-08-28 (security): per-account guess limit, independent of
        // the IP-based /verify-otp throttle in routes/api.php — this is
        // what stops someone from guessing a single known account's
        // 6-digit code across many IPs. Once tripped, the stored code is
        // cleared so even the correct code no longer works; resendOtp()
        // is the only way forward, and it resets otp_attempts back to 0.
        if ($user->otp_attempts >= self::MAX_OTP_ATTEMPTS) {
            $user->update(['otp_code' => null, 'otp_expires_at' => null]);
            return response()->json([
                'success' => false,
                'message' => 'Too many incorrect attempts. Please request a new code.',
            ], 429);
        }

        if (! hash_equals($user->otp_code, $validated['otp_code'])) {
            $user->increment('otp_attempts');
            return response()->json(['success' => false, 'message' => 'Incorrect verification code.'], 422);
        }

        $user->update([
            'email_verified_at' => now(),
            'otp_code' => null,
            'otp_expires_at' => null,
            'otp_attempts' => 0,
        ]);

        // 2026-08-29: the "notify admins" moment moved to DriverController::
        // completeRegistration() / CompanyController::completeRegistration()
        // — at THIS point (right after email verification) a driver/company
        // no longer has a Driver/Company row at all yet (register() only
        // creates the User row now), so there's nothing yet for an admin to
        // review. Notifying here would be alerting them about an empty
        // shell that might never even finish the profile step.

        $token = $user->createToken('api-token')->plainTextToken;

        // The app needs to know, right after OTP success, whether a
        // driver/company still has to fill in their profile (documents,
        // truck/license, etc.) before it's safe to show them the normal
        // approval-status/home screens — see DriverController::
        // completeRegistration() / CompanyController::completeRegistration().
        // Always true for non driver/company roles (admin/sub_admin), which
        // never have a separate profile step.
        $registrationComplete = match ($user->type) {
            'driver' => Driver::where('user_id', $user->id)->exists(),
            'company' => Company::where('user_id', $user->id)->exists(),
            default => true,
        };

        return response()->json([
            'success' => true,
            'message' => 'Email verified successfully.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'type' => $user->type,
                ],
                'access_token' => $token,
                'token_type' => 'Bearer',
                'registration_complete' => $registrationComplete,
            ],
        ], 200);
    }

    /**
     * UC-4: resend a fresh OTP code (e.g. the first one expired, or the
     * email never arrived).
     */
    public function resendOtp(Request $request)
    {
        $validated = $request->validate(['email' => ['required', 'email']]);

        // Normalize the lookup the same way as verifyOtp() above.
        $user = User::where('email', User::normalizeEmail($validated['email']))->first();

        if (! $user) {
            return response()->json(['success' => false, 'message' => 'Account not found.'], 404);
        }

        if ($user->email_verified_at) {
            return response()->json(['success' => false, 'message' => 'Email already verified.'], 409);
        }

        $otp = $this->generateOtp();
        $user->update([
            'otp_code' => $otp,
            'otp_expires_at' => now()->addMinutes(10),
            'otp_attempts' => 0,
        ]);
        $user->notify(new OtpCodeNotification($otp));

        return response()->json(['success' => true, 'message' => 'A new verification code has been sent.'], 200);
    }

    public function login(Request $request)
    {
        // Normalize the email before lookup so a different capitalization
        // than what was used at registration still resolves correctly —
        // Postgres compares text case-sensitively by default.
        $user = User::where('email', User::normalizeEmail($request['email']))->first();

        if (! $user || ! Hash::check($request['password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Incorrect email or password.',
                'errors' => [
                    'email' => ['Incorrect email or password. Please try again.']
                ]
            ], 401);
        }

        // Super Admin can temporarily suspend a sub-admin account (see
        // AdminController::suspend()) without deleting it — blocked here,
        // before the OTP/approval checks below.
        if ($user->is_suspended) {
            return response()->json([
                'success' => false,
                'message' => 'This account has been suspended. Contact the Super Admin.',
            ], 403);
        }

        // OTP belongs only to the sign-up flow — generated and emailed once,
        // right after registration (see register() above). Login does not
        // block on it and does not generate or send another OTP; it only
        // reports the status. An unverified account still logs in normally
        // (token issued below), and the app uses 'email_verified' => false
        // to show the OTP-entry screen instead of the home screen, the same
        // way an unapproved driver/company gets DriverApprovalStatusPage.
        // resendOtp() is how an expired code gets replaced.
        $token = $user->createToken('api-token')->plainTextToken;

        // Drivers/companies carry an admin-approval status; the app needs
        // this at login time (not just at registration time) to keep
        // showing the "awaiting approval" screen on every subsequent login
        // until an admin approves them.
        $driver = $user->type === 'driver'
            ? Driver::where('user_id', $user->id)->first()
            : null;

        $company = $user->type === 'company'
            ? Company::where('user_id', $user->id)->first()
            : null;

        // Same signal as verifyOtp() — a driver/company can close the app
        // between OTP success and finishing their profile, then come back
        // later via a normal login; this is what routes them back into the
        // profile-completion screen instead of a broken/empty home screen.
        $registrationComplete = match ($user->type) {
            'driver' => $driver !== null,
            'company' => $company !== null,
            default => true,
        };

        return response()->json([
            'success' => true,
            'message' => 'Login successful.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'type' => $user->type,
                    'must_change_password' => (bool) $user->must_change_password,
                    'email_verified' => (bool) $user->email_verified_at,
                    // Needed at login time (not just on a later /me/profile
                    // fetch) so AdminDrawer can filter its menu on the very
                    // first screen after sign-in — see ProfileController::
                    // show() for the same logic reused there.
                    'permissions' => $user->isSuperAdmin()
                        ? \App\Models\Permission::pluck('key')
                        : ($user->isSubAdmin() ? $user->permissions()->pluck('key') : []),
                ],
                'access_token' => $token,
                'token_type' => 'Bearer',
                'registration_complete' => $registrationComplete,
            ],
            'driver' => $driver,
            'company' => $company,
        ], 200);
    }

    /**
     * 2026-08-29 (audit item 9): revokes the Sanctum token this request was
     * authenticated with, so it can no longer be used after this call —
     * previously there was no server-side logout at all; Flutter only
     * cleared its own local SharedPreferences, leaving the token live
     * indefinitely. Only deletes THIS token (not every token the account
     * has), so logging out on one device doesn't affect a session on
     * another.
     */
    public function logout(Request $request)
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['success' => true, 'message' => 'Logged out.'], 200);
    }

    /**
     * UC-7: forced password change on first login for sub-admin accounts
     * created with a one-time temporary password, and also usable at any
     * time by any logged-in user to change their own password.
     */
    public function changePassword(Request $request)
    {
        $user = $request->user();

        $validated = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'confirmed', PasswordPolicy::rules()],
        ]);

        if (! Hash::check($validated['current_password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Current password is incorrect.',
            ], 422);
        }

        $user->update([
            'password' => Hash::make($validated['password']),
            'must_change_password' => false,
        ]);

        return response()->json([
            'success' => true,
            'message' => 'Password changed successfully.',
        ], 200);
    }

    private function generateOtp(): string
    {
        return (string) random_int(100000, 999999);
    }

    /**
     * UC-2/UC-3: alert every admin the moment a self-registered driver or
     * company finishes email verification and is sitting in 'pending'
     * approval. There's no dedicated permission key for driver/company
     * approval yet (see routes/api.php — those endpoints aren't gated by
     * permission:<key> like finance/crm are), so this goes to every admin
     * who can currently act on it: Super Admin, the legacy 'admin' seed
     * account, and every sub-admin regardless of which permission groups
     * they hold.
     */
    /**
     * 2026-08-29: made public+static (was private instance) so
     * DriverController::completeRegistration() and CompanyController::
     * completeRegistration() can call it directly — the "new registration
     * pending" moment moved from verifyOtp() to those two methods now that
     * the Driver/Company row itself isn't created until after OTP.
     */
    public static function notifyAdminsOfNewRegistration(User $user): void
    {
        $admins = User::whereIn('type', ['super_admin', 'admin', 'sub_admin'])->get();

        $label = $user->type === 'driver' ? 'driver' : 'company';

        foreach ($admins as $admin) {
            $admin->notify(new AppPushNotification(
                'new_registration_pending',
                'New ' . ucfirst($label) . ' awaiting approval',
                sprintf('%s (%s) just verified their email and is waiting for approval.', $user->name, $user->email),
                ['user_id' => $user->id, 'type' => $user->type],
            ));
        }
    }
}
