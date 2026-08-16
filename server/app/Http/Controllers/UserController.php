<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\User;
use App\Notifications\AppPushNotification;
use App\Notifications\OtpCodeNotification;
use App\Support\PasswordPolicy;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\ValidationException;

class UserController extends Controller
{
    /**
     * Self-registration for companies and drivers (UC-2/UC-3). Anyone can
     * create their own account this way — the admin never creates a
     * company's or a driver's account. Every driver is an independent
     * operator who owns their own truck(s); there is no platform-owning
     * company anymore, so no "internal fleet" distinction exists.
     *
     * This does NOT log the user in yet: the account is created with
     * email_verified_at = null and a fresh OTP is sent (UC-4). The account
     * only becomes usable after verifyOtp() succeeds, and even then it
     * still needs Super Admin final approval (approval_status stays
     * 'pending' — see DriverController/CompanyController::approve()).
     *
     * The truck itself is NOT collected here on purpose: a truck is its
     * own record (see TruckController) that a driver can add or change at
     * any time, so it must not be tied to the driver's account at sign-up.
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

        $rules = [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', PasswordPolicy::rules()],
            'phone' => ['nullable', 'string', 'max:20'],
        ];

        if ($type === 'driver') {
            $rules['driver_license'] = ['required', 'string', 'unique:drivers,driver_license'];
        }

        if ($type === 'company') {
            $rules['address'] = ['nullable', 'string', 'max:255'];
            // Trade/commercial license file, required at self-registration
            // time — mirrors the truck license upload pattern (single file,
            // stored directly on the record) rather than the versioned
            // driver_documents table, since a company only ever has one
            // current license on file.
            $rules['license_file'] = ['required', 'file', 'max:10240'];
        }

        try {
            $validated = $request->validate($rules);
        } catch (ValidationException $e) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed.',
                'errors' => $e->errors(),
            ], 401);
        }

        $licenseFilePath = null;
        if ($type === 'company' && $request->hasFile('license_file')) {
            $licenseFilePath = $request->file('license_file')->store('company_licenses', 'public');
        }

        $otp = $this->generateOtp();

        [$user, $driver, $company] = DB::transaction(function () use ($validated, $type, $otp, $licenseFilePath) {
            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'type' => $type,
                'password' => Hash::make($validated['password']),
                'otp_code' => $otp,
                'otp_expires_at' => now()->addMinutes(10),
            ]);

            $driver = null;
            $company = null;

            if ($type === 'driver') {
                $driver = Driver::create([
                    'name' => $validated['name'],
                    'phone' => $validated['phone'] ?? null,
                    'driver_license' => $validated['driver_license'],
                    'status' => 'unavailable',
                    // Self-registered drivers always start out pending — an
                    // admin must review their documents and approve them
                    // before they can be matched with any shipment. Drivers
                    // created directly by an admin (DriverController::create)
                    // default to 'approved' instead, since the admin is
                    // already vouching for them at creation time.
                    'approval_status' => 'pending',
                    'user_id' => $user->id,
                ]);
            }

            if ($type === 'company') {
                $company = Company::create([
                    'name' => $validated['name'],
                    'email' => $validated['email'],
                    'phone' => $validated['phone'] ?? null,
                    'address' => $validated['address'] ?? null,
                    'approval_status' => 'pending',
                    'license_file_path' => $licenseFilePath,
                    'user_id' => $user->id,
                ]);
            }

            return [$user, $driver, $company];
        });

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

        $user = User::where('email', $validated['email'])->first();

        if (! $user) {
            return response()->json(['success' => false, 'message' => 'Account not found.'], 404);
        }

        if ($user->email_verified_at) {
            return response()->json(['success' => false, 'message' => 'Email already verified.'], 409);
        }

        if (! $user->otp_code || ! $user->otp_expires_at || $user->otp_expires_at->isPast()) {
            return response()->json(['success' => false, 'message' => 'This code has expired. Please request a new one.'], 422);
        }

        if (! hash_equals($user->otp_code, $validated['otp_code'])) {
            return response()->json(['success' => false, 'message' => 'Incorrect verification code.'], 422);
        }

        $user->update([
            'email_verified_at' => now(),
            'otp_code' => null,
            'otp_expires_at' => null,
        ]);

        // Only now — not at register() — because the account row already
        // existed as 'pending' before email verification, but notifying
        // admins about it then would mean alerting them about signups that
        // might never even finish this step. A verified email means a real
        // person is actually waiting on a decision.
        if (in_array($user->type, ['driver', 'company'], true)) {
            $this->notifyAdminsOfNewRegistration($user);
        }

        $token = $user->createToken('api-token')->plainTextToken;

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

        $user = User::where('email', $validated['email'])->first();

        if (! $user) {
            return response()->json(['success' => false, 'message' => 'Account not found.'], 404);
        }

        if ($user->email_verified_at) {
            return response()->json(['success' => false, 'message' => 'Email already verified.'], 409);
        }

        $otp = $this->generateOtp();
        $user->update(['otp_code' => $otp, 'otp_expires_at' => now()->addMinutes(10)]);
        $user->notify(new OtpCodeNotification($otp));

        return response()->json(['success' => true, 'message' => 'A new verification code has been sent.'], 200);
    }

    public function login(Request $request)
    {
        $user = User::where('email', $request['email'])->first();

        if (! $user || ! Hash::check($request['password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials.',
                'errors' => [
                    'email' => ['The provided credentials are incorrect.']
                ]
            ], 401);
        }

        // Self-registered accounts (driver/company) must verify their email
        // via OTP before they can log in at all. Admin-created accounts
        // (sub-admins) have email_verified_at set at creation time, so this
        // never blocks them.
        if (! $user->email_verified_at) {
            $otp = $this->generateOtp();
            $user->update(['otp_code' => $otp, 'otp_expires_at' => now()->addMinutes(10)]);
            $user->notify(new OtpCodeNotification($otp));

            return response()->json([
                'success' => false,
                'message' => 'Please verify your email first. A new verification code has been sent.',
                'requires_otp_verification' => true,
            ], 403);
        }

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
                ],
                'access_token' => $token,
                'token_type' => 'Bearer',
            ],
            'driver' => $driver,
            'company' => $company,
        ], 200);
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
    private function notifyAdminsOfNewRegistration(User $user): void
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
