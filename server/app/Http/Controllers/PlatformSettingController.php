<?php

namespace App\Http\Controllers;

use App\Models\PlatformSetting;
use Illuminate\Http\Request;

/**
 * Admin-configurable values called out across the spec (profit margin,
 * matching timeout/weights, working-hours alert threshold, rest-reset
 * duration) — see the seed list in the Phase 1 platform_settings migration.
 * Only a fixed whitelist of keys is editable through this endpoint so it
 * can't be used to inject arbitrary settings rows.
 */
class PlatformSettingController extends Controller
{
    const EDITABLE_KEYS = [
        'profit_margin_percent',
        'matching_response_timeout_minutes',
        'working_hours_alert_threshold_minutes',
        'rest_reset_minutes',
        'default_driver_rating',
        'matching_weight_proximity',
        'matching_weight_rating',
        'matching_weight_acceptance',
        'matching_weight_fairness',
        'matching_weight_route_experience',
        'matching_batch_size',
    ];

    const WEIGHT_KEYS = [
        'matching_weight_proximity',
        'matching_weight_rating',
        'matching_weight_acceptance',
        'matching_weight_fairness',
        'matching_weight_route_experience',
    ];

    /**
     * 2026-08-27 (security review): the report's stated design is "Platform
     * Settings = Super Admin only", but the route was gated by
     * 'permission:finance' (any finance sub-admin could reach it) and this
     * controller never re-checked. Route middleware is removed for these two
     * endpoints in favor of this single, explicit Super-Admin-only check.
     */
    private function requireSuperAdmin(Request $request): void
    {
        $user = $request->user();
        if (! $user || ! $user->isSuperAdmin()) {
            abort(403, 'Only a Super Admin can view or change platform settings.');
        }
    }

    public function index(Request $request)
    {
        $this->requireSuperAdmin($request);

        return response()->json([
            'message' => 'Platform settings retrieved successfully',
            'settings' => PlatformSetting::whereIn('key', self::EDITABLE_KEYS)->orderBy('key')->get(),
        ], 200);
    }

    public function update(Request $request, string $key)
    {
        $this->requireSuperAdmin($request);

        if (! in_array($key, self::EDITABLE_KEYS, true)) {
            return response()->json(['message' => 'This setting cannot be edited'], 422);
        }

        $validated = $request->validate([
            'value' => ['required', 'string'],
        ]);

        // 2026-08-27 (security review): update() previously only checked
        // value = required|string, so any caller who reached it could store
        // nonsensical values (negative batch size, a weight of 8, a 900%
        // margin) — Flutter only warns in the UI, it never blocked saving.
        // Server-side range/type validation per key, matching what the
        // matching/pricing engines actually assume.
        $numericRangeRules = [
            'profit_margin_percent' => ['numeric', 'min:0', 'max:100'],
            'matching_response_timeout_minutes' => ['integer', 'min:1', 'max:1440'],
            'working_hours_alert_threshold_minutes' => ['integer', 'min:1', 'max:1440'],
            'rest_reset_minutes' => ['integer', 'min:1', 'max:1440'],
            'default_driver_rating' => ['numeric', 'min:0', 'max:5'],
            'matching_batch_size' => ['integer', 'min:1', 'max:100'],
            'matching_weight_proximity' => ['numeric', 'min:0', 'max:1'],
            'matching_weight_rating' => ['numeric', 'min:0', 'max:1'],
            'matching_weight_acceptance' => ['numeric', 'min:0', 'max:1'],
            'matching_weight_fairness' => ['numeric', 'min:0', 'max:1'],
            'matching_weight_route_experience' => ['numeric', 'min:0', 'max:1'],
        ];

        try {
            $request->validate(['value' => $numericRangeRules[$key] ?? ['string']]);
        } catch (\Illuminate\Validation\ValidationException $e) {
            return response()->json(['message' => 'Invalid value for this setting', 'errors' => $e->errors()], 422);
        }

        // The five matching weights are edited one key at a time, but the
        // matching score only makes sense if they sum to 1 — reject a save
        // that would push the total more than a rounding hair away from 1.0,
        // computed against the OTHER four keys' currently-stored values.
        if (in_array($key, self::WEIGHT_KEYS, true)) {
            $sum = (float) $validated['value'];
            foreach (self::WEIGHT_KEYS as $weightKey) {
                if ($weightKey === $key) {
                    continue;
                }
                $sum += (float) PlatformSetting::get($weightKey, '0');
            }
            if (abs($sum - 1.0) > 0.01) {
                return response()->json([
                    'message' => "Matching weights must sum to 1.0 across all five keys (currently would total {$sum}). Update the other weights first.",
                ], 422);
            }
        }

        PlatformSetting::set($key, $validated['value']);

        return response()->json([
            'message' => 'Setting updated successfully',
            'key' => $key,
            'value' => $validated['value'],
        ], 200);
    }
}
