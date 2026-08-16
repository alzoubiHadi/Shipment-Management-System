<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\DriverDocument;
use App\Models\Shipment;
use App\Models\Truck;
use Illuminate\Http\Request;

/**
 * Backs the new Admin Dashboard "Home" screen (2026-08-21 design pass) —
 * one endpoint returning every summary count the screen needs, computed
 * with real queries instead of the app fetching full driver/company/
 * shipment lists just to count them client-side.
 */
class AdminDashboardController extends Controller
{
    public function stats(Request $request)
    {
        $now = now();

        $pendingDrivers = Driver::where('approval_status', 'pending')->count();
        $pendingCompanies = Company::where('approval_status', 'pending')->count();

        $activeDrivers = Driver::where('approval_status', 'approved')->count();

        // "Available trucks" — this app doesn't have a truck-level status
        // column; availability lives on the owning driver instead (see
        // Driver::status). A truck counts as available right now if its
        // owning driver is currently marked available.
        $availableTrucks = Truck::whereHas('ownerDriver', function ($q) {
            $q->where('status', 'available');
        })->count();

        $activeCompanies = Company::where('approval_status', 'approved')
            ->where('account_status', 'active')
            ->count();

        // Shipment.status: 0 = pending/unassigned, 1 = assigned, 2 = in
        // progress, 3 = delivered/completed, 4 = cancelled — see
        // ShipmentController for where these are set.
        $activeShipments = Shipment::whereIn('status', [0, 1, 2])->count();

        $completedThisMonth = Shipment::where('status', 3)
            ->whereNotNull('delivered_at')
            ->whereMonth('delivered_at', $now->month)
            ->whereYear('delivered_at', $now->year)
            ->count();

        // Alerts feed — kept intentionally small for this first pass:
        // documents expiring soon (license/passport/residency, any driver)
        // and the same pending-registration count already computed above.
        $documentsExpiringSoon = DriverDocument::where('is_current', true)
            ->whereNotNull('expiry_date')
            ->whereBetween('expiry_date', [$now->toDateString(), $now->copy()->addDays(7)->toDateString()])
            ->count();

        $alerts = [];
        if ($documentsExpiringSoon > 0) {
            $alerts[] = [
                'type' => 'documents_expiring',
                'count' => $documentsExpiringSoon,
                'message' => "$documentsExpiringSoon documents expiring within 7 days",
            ];
        }
        $pendingTotal = $pendingDrivers + $pendingCompanies;
        if ($pendingTotal > 0) {
            $alerts[] = [
                'type' => 'registration_pending',
                'count' => $pendingTotal,
                'message' => "$pendingTotal accounts awaiting review",
            ];
        }

        return response()->json([
            'message' => 'Dashboard stats retrieved successfully',
            'stats' => [
                'registration_pending' => $pendingTotal,
                'registration_pending_drivers' => $pendingDrivers,
                'registration_pending_companies' => $pendingCompanies,
                'drivers_active' => $activeDrivers,
                'trucks_available' => $availableTrucks,
                'companies_active' => $activeCompanies,
                'shipments_active' => $activeShipments,
                'shipments_completed_this_month' => $completedThisMonth,
            ],
            'alerts' => $alerts,
        ], 200);
    }
}
