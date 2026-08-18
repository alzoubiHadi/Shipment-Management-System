<?php

namespace App\Http\Controllers;

use App\Models\Zone;
use Illuminate\Http\Request;

/**
 * Zones / Smart Pricing Engine (2026-08-27) — read-only lookup for the
 * Company Create-Shipment flow's Country -> City -> Zone pickers. Zones
 * themselves are seeded from real historical data (see
 * 2026_08_27_000002_import_zones_from_pricing_data.php), not
 * user-creatable — there is no store()/update()/destroy() here.
 */
class ZoneController extends Controller
{
    /**
     * GET /zones — optionally narrowed with ?country=UAE&city=Dubai.
     * With no params, returns every active zone (a few hundred rows,
     * cheap enough not to paginate); the Flutter picker groups/filters
     * client-side after that, same pattern as the existing
     * PriceListController::destinationOptions().
     */
    public function index(Request $request)
    {
        $query = Zone::where('is_active', true)->orderBy('country')->orderBy('city')->orderBy('name');

        if ($request->filled('country')) {
            $query->where('country', $request->query('country'));
        }
        if ($request->filled('city')) {
            $query->where('city', $request->query('city'));
        }

        return response()->json([
            'message' => 'Zones retrieved successfully',
            'zones' => $query->get(['id', 'country', 'city', 'name', 'zone_type']),
        ], 200);
    }

    /**
     * GET /zones/countries — distinct country list for the first picker
     * step, so the Flutter side doesn't need to derive it client-side
     * from the full zones list every time.
     */
    public function countries()
    {
        $countries = Zone::where('is_active', true)
            ->distinct()
            ->orderBy('country')
            ->pluck('country');

        return response()->json([
            'message' => 'Countries retrieved successfully',
            'countries' => $countries,
        ], 200);
    }
}
