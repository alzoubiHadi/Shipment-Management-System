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
        'matching_batch_size',
    ];

    public function index()
    {
        return response()->json([
            'message' => 'Platform settings retrieved successfully',
            'settings' => PlatformSetting::whereIn('key', self::EDITABLE_KEYS)->orderBy('key')->get(),
        ], 200);
    }

    public function update(Request $request, string $key)
    {
        if (! in_array($key, self::EDITABLE_KEYS, true)) {
            return response()->json(['message' => 'This setting cannot be edited'], 422);
        }

        $validated = $request->validate([
            'value' => ['required', 'string'],
        ]);

        PlatformSetting::set($key, $validated['value']);

        return response()->json([
            'message' => 'Setting updated successfully',
            'key' => $key,
            'value' => $validated['value'],
        ], 200);
    }
}
