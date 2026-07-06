<?php

namespace App\Http\Controllers;

use App\Models\Driver;
use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class UserController extends Controller
{
    //
    /**
     * Self-registration. Anyone can create their own account this way —
     * this is how the app reaches drivers in the open market instead of
     * the admin having to add every driver by hand.
     *
     * When registering as a driver, a matching Driver profile is created
     * automatically. The only thing that distinguishes an "internal"
     * driver (own fleet, i.e. Albatrans) from an "external" one (an
     * independent driver who joined through the app) is the
     * `is_albatrans_fleet` checkbox on the sign-up form — everything else
     * about the registration flow is identical for both.
     *
     * The truck itself is NOT collected here on purpose: a truck is its
     * own record (see TruckController) that a driver can add or change at
     * any time, so it must not be tied to the driver's account at sign-up.
     */
    public function register(Request $request)
    {
        $type = $request->type ?? 'driver';

        $rules = [
            'name' => ['required', 'string', 'max:255'],
            'email' => ['required', 'email', 'max:255', 'unique:users,email'],
            'password' => ['required', 'string', 'min:8'],
            'phone' => ['nullable', 'string', 'max:20'],
        ];

        if ($type === 'driver') {
            $rules['driver_license'] = ['required', 'string', 'unique:drivers,driver_license'];
            $rules['is_albatrans_fleet'] = ['nullable', 'boolean'];
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

        [$user, $driver] = DB::transaction(function () use ($validated, $type, $request) {
            $user = User::create([
                'name' => $validated['name'],
                'email' => $validated['email'],
                'type' => $type,
                'password' => Hash::make($validated['password']),
            ]);

            $driver = null;

            if ($type === 'driver') {
                $driver = Driver::create([
                    'name' => $validated['name'],
                    'phone' => $validated['phone'] ?? null,
                    'driver_license' => $validated['driver_license'],
                    // the checkbox is the ONLY thing that decides this:
                    'employment_type' => $request->boolean('is_albatrans_fleet')
                        ? 'internal'
                        : 'external',
                    'status' => 'available',
                    'user_id' => $user->id,
                ]);
            }

            return [$user, $driver];
        });

        $token = $user->createToken('api-token')->plainTextToken;

        // Same response shape as login(), so the app's AuthResponse.fromJson
        // (shared by both login and register) can read it the same way.
        return response()->json([
            'success' => true,
            'message' => 'Registered successfully',
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
            'driver' => $driver,
        ], 201);
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

        // Optional: revoke old tokens
        // $user->tokens()->delete();

        $token = $user->createToken('api-token')->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful.',
            'data' => [
                'user' => [
                    'id' => $user->id,
                    'name' => $user->name,
                    'email' => $user->email,
                    'type' => $user->type,
                ],
                'access_token' => $token,
                'token_type' => 'Bearer',
            ]
        ], 200);
    }
}
