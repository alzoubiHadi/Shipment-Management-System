<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\DriverDocument;
use App\Models\Truck;
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
     * company, so no "internal fleet" distinction exists.
     *
     * This does NOT log the user in yet: the account is created with
     * email_verified_at = null and a fresh OTP is sent (UC-4). The account
     * only becomes usable after verifyOtp() succeeds, and even then it
     * still needs Super Admin final approval (approval_status stays
     * 'pending' — see DriverController/CompanyController::approve()).
     *
     * For drivers, the truck is collected in the same form: one submission,
     * two sections — driver info then truck info. TruckController::addMyTruck
     * remains available for adding further or replacement trucks later.
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

        $rules = [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'confirmed', PasswordPolicy::rules()],
            'phone' => ['nullable', 'string', 'max:20'],
        ];

        if ($type === 'driver') {
            $rules['phone'] = ['required', 'string', 'max:20'];
            $rules['driver_license'] = ['required', 'string', 'unique:drivers,driver_license'];
            $rules['age'] = ['required', 'integer', 'min:18', 'max:65'];
            $rules['nationality'] = ['required', 'string', 'max:100'];

            // Driver documents — all three collected up front at sign-up,
            // rather than deferred to UC-8.
            $rules['license_file'] = ['required', 'file', 'max:10240'];
            $rules['license_expiry'] = ['required', 'date'];
            $rules['passport_file'] = ['required', 'file', 'max:10240'];
            $rules['passport_expiry'] = ['required', 'date'];
            $rules['residency_file'] = ['required', 'file', 'max:10240'];
            $rules['residency_expiry'] = ['required', 'date'];
            // License back side and a driver photo, both optional so older
            // app builds that don't send them still work.
            $rules['license_back_file'] = ['nullable', 'file', 'max:10240'];
            $rules['driver_photo_file'] = ['nullable', 'file', 'max:10240'];

            $rules['blood_type'] = ['required', 'string', 'in:A+,A-,B+,B-,O+,O-,AB+,AB-'];
            $rules['health_conditions'] = ['nullable', 'string', 'max:1000'];

            $rules['destinations'] = ['required', 'array', 'min:1'];
            $rules['destinations.*'] = ['string', 'in:' . implode(',', array_keys(DriverDestination::DESTINATIONS))];

            // Truck (section 2 of the sign-up form).
            $rules['truck_number'] = ['required', 'string', 'unique:trucks,truck_number'];
            $rules['truck_type'] = ['required', 'string', 'in:' . implode(',', Truck::TRUCK_TYPES)];
            $rules['truck_license_file'] = ['required', 'file', 'max:10240'];
            $rules['truck_license_expiry'] = ['nullable', 'date'];
            $rules['permit_type'] = ['nullable', 'string', 'max:255'];
            // Insurance + technical inspection, both optional at
            // registration (can still be added later via the driver's own
            // truck-edit path).
            $rules['truck_insurance_file'] = ['nullable', 'file', 'max:10240'];
            $rules['truck_insurance_expiry'] = ['nullable', 'date'];
            $rules['truck_inspection_file'] = ['nullable', 'file', 'max:10240'];
            $rules['truck_inspection_expiry'] = ['nullable', 'date'];
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
        $driverLicenseFilePath = null;
        $passportFilePath = null;
        $residencyFilePath = null;
        $truckLicenseFilePath = null;
        $licenseBackFilePath = null;
        $driverPhotoFilePath = null;
        $truckInsuranceFilePath = null;
        $truckInspectionFilePath = null;

        if ($type === 'company' && $request->hasFile('license_file')) {
            $licenseFilePath = $request->file('license_file')->store('company_licenses', 'local');
        }

        if ($type === 'driver') {
            if ($request->hasFile('license_file')) {
                $driverLicenseFilePath = $request->file('license_file')->store('driver_documents', 'local');
            }
            if ($request->hasFile('passport_file')) {
                $passportFilePath = $request->file('passport_file')->store('driver_documents', 'local');
            }
            if ($request->hasFile('residency_file')) {
                $residencyFilePath = $request->file('residency_file')->store('driver_documents', 'local');
            }
            if ($request->hasFile('license_back_file')) {
                $licenseBackFilePath = $request->file('license_back_file')->store('driver_documents', 'local');
            }
            if ($request->hasFile('driver_photo_file')) {
                $driverPhotoFilePath = $request->file('driver_photo_file')->store('driver_documents', 'local');
            }
            if ($request->hasFile('truck_license_file')) {
                $truckLicenseFilePath = $request->file('truck_license_file')->store('truck_licenses', 'local');
            }
            if ($request->hasFile('truck_insurance_file')) {
                $truckInsuranceFilePath = $request->file('truck_insurance_file')->store('truck_insurance', 'local');
            }
            if ($request->hasFile('truck_inspection_file')) {
                $truckInspectionFilePath = $request->file('truck_inspection_file')->store('truck_inspections', 'local');
            }
        }

        $otp = $this->generateOtp();

        [$user, $driver, $company] = DB::transaction(function () use (
            $validated, $type, $otp, $licenseFilePath,
            $driverLicenseFilePath, $passportFilePath, $residencyFilePath, $truckLicenseFilePath,
            $licenseBackFilePath, $driverPhotoFilePath, $truckInsuranceFilePath, $truckInspectionFilePath
        ) {
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
                    'phone' => $validated['phone'],
                    'driver_license' => $validated['driver_license'],
                    'age' => $validated['age'],
                    'nationality' => $validated['nationality'],
                    'status' => 'unavailable',
                    // Self-registered drivers always start out pending — an
                    // admin must review their documents and approve them
                    // before they can be matched with any shipment. Drivers
                    // created directly by an admin (DriverController::create)
                    // default to 'approved' instead, since the admin is
                    // already vouching for them at creation time.
                    'approval_status' => 'pending',
                    'license_expiry' => $validated['license_expiry'],
                    'passport_expiry' => $validated['passport_expiry'],
                    'residency_expiry' => $validated['residency_expiry'],
                    'blood_type' => $validated['blood_type'],
                    'health_conditions' => $validated['health_conditions'] ?? null,
                    'user_id' => $user->id,
                ]);

                // Append-only document history (UC-8) — seeded from the
                // three files uploaded at sign-up itself, so the driver's
                // "My Documents" screen already shows them as on file, and
                // the admin's document-issue check has something to review.
                $documents = [
                    ['type' => 'license', 'path' => $driverLicenseFilePath, 'expiry' => $validated['license_expiry']],
                    ['type' => 'passport', 'path' => $passportFilePath, 'expiry' => $validated['passport_expiry']],
                    ['type' => 'residency', 'path' => $residencyFilePath, 'expiry' => $validated['residency_expiry']],
                    // Optional — new-registration-design batch. No separate
                    // expiry field: the back side shares the front's expiry.
                    ['type' => 'license_back', 'path' => $licenseBackFilePath, 'expiry' => $validated['license_expiry']],
                    ['type' => 'driver_photo', 'path' => $driverPhotoFilePath, 'expiry' => null],
                ];
                foreach ($documents as $doc) {
                    if (! $doc['path']) {
                        continue;
                    }
                    DriverDocument::create([
                        'driver_id' => $driver->id,
                        'type' => $doc['type'],
                        'file_path' => $doc['path'],
                        'expiry_date' => $doc['expiry'],
                        'is_current' => true,
                        'uploaded_by_user_id' => $user->id,
                    ]);
                }

                foreach (array_unique($validated['destinations']) as $destination) {
                    DriverDestination::create([
                        'driver_id' => $driver->id,
                        'destination' => $destination,
                    ]);
                }

                Truck::create([
                    'truck_number' => $validated['truck_number'],
                    'truck_type' => $validated['truck_type'],
                    'license_file_path' => $truckLicenseFilePath,
                    'license_expiry' => $validated['truck_license_expiry'] ?? null,
                    'permit_type' => $validated['permit_type'] ?? null,
                    'insurance_file_path' => $truckInsuranceFilePath,
                    'insurance_expiry' => $validated['truck_insurance_expiry'] ?? null,
                    'technical_inspection_file_path' => $truckInspectionFilePath,
                    'technical_inspection_expiry' => $validated['truck_inspection_expiry'] ?? null,
                    'default_driver_id' => $driver->id,
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

        // Normalize the lookup the same way as verifyOtp() above.
        $user = User::where('email', User::normalizeEmail($validated['email']))->first();

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
        // Normalize the email before lookup so a different capitalization
        // than what was used at registration still resolves correctly —
        // Postgres compares text case-sensitively by default.
        $user = User::where('email', User::normalizeEmail($request['email']))->first();

        if (! $user || ! Hash::check($request['password'], $user->password)) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials.',
                'errors' => [
                    'email' => ['The provided credentials are incorrect.']
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
