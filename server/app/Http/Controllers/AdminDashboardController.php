<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\CompanyDocument;
use App\Models\Driver;
use App\Models\DriverDocument;
use App\Models\ProfileEditRequest;
use App\Models\Shipment;
use App\Models\Truck;
use App\Models\TruckDocument;
use Illuminate\Http\Request;

/**
 * Backs the new Admin Dashboard "Home" screen (2026-08-21 design pass) —
 * one endpoint returning every summary count the screen needs, computed
 * with real queries instead of the app fetching full driver/company/
 * shipment lists just to count them client-side.
 *
 * Unified Approvals / document-expiry feature (2026-08-22): added
 * pending_approvals (New Registrations + Document Renewals + Changes
 * Required, matching the 3 tabs of the admin Approvals screen) and split
 * the old single "documents expiring" alert into Expiring Soon vs Expired,
 * now covering driver + truck + company documents instead of only driver
 * ones.
 */
class AdminDashboardController extends Controller
{
    const RENEWAL_CATEGORIES = ['document', 'truck_document', 'company_license'];

    /**
     * 2026-08-27 (security review): neither endpoint below checked the
     * caller was an admin at all — any authenticated driver or company
     * account could read these platform-wide counts and the affected-people
     * list. This spans several permission categories at once (finance,
     * compliance, crm...), so unlike the single-category endpoints
     * elsewhere in the app it's gated here by "any admin" rather than one
     * specific 'permission:<key>' route middleware.
     */
    private function requireAdmin(Request $request): void
    {
        $user = $request->user();
        if (! $user || (! $user->isSuperAdmin() && ! $user->isSubAdmin())) {
            abort(403, 'Admin access required.');
        }
    }

    public function stats(Request $request)
    {
        $this->requireAdmin($request);
        $now = now();

        $pendingDrivers = Driver::where('approval_status', 'pending')->count();
        $pendingCompanies = Company::where('approval_status', 'pending')->count();
        $pendingTotal = $pendingDrivers + $pendingCompanies;

        $changesRequiredDrivers = Driver::where('approval_status', 'changes_required')->count();
        $changesRequiredCompanies = Company::where('approval_status', 'changes_required')->count();
        $changesRequiredTotal = $changesRequiredDrivers + $changesRequiredCompanies;

        $pendingDocumentRenewals = ProfileEditRequest::whereIn('category', self::RENEWAL_CATEGORIES)
            ->where('status', 'pending')
            ->count();

        $pendingApprovals = $pendingTotal + $pendingDocumentRenewals + $changesRequiredTotal;

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

        $expiringSoonCount = DriverDocument::where('is_current', true)->where('status', 'expiring_soon')->count()
            + TruckDocument::where('is_current', true)->where('status', 'expiring_soon')->count()
            + CompanyDocument::where('is_current', true)->where('status', 'expiring_soon')->count();

        $expiredCount = DriverDocument::where('is_current', true)->where('status', 'expired')->count()
            + TruckDocument::where('is_current', true)->where('status', 'expired')->count()
            + CompanyDocument::where('is_current', true)->where('status', 'expired')->count();

        $alerts = [];
        if ($expiringSoonCount > 0) {
            $alerts[] = [
                'type' => 'documents_expiring',
                'count' => $expiringSoonCount,
                'message' => "$expiringSoonCount document(s) expiring within 30 days",
            ];
        }
        if ($expiredCount > 0) {
            $alerts[] = [
                'type' => 'documents_expired',
                'count' => $expiredCount,
                'message' => "$expiredCount document(s) expired",
            ];
        }
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
                'pending_approvals' => $pendingApprovals,
                'registration_pending' => $pendingTotal,
                'registration_pending_drivers' => $pendingDrivers,
                'registration_pending_companies' => $pendingCompanies,
                'document_renewals_pending' => $pendingDocumentRenewals,
                'changes_required_total' => $changesRequiredTotal,
                'drivers_active' => $activeDrivers,
                'trucks_available' => $availableTrucks,
                'companies_active' => $activeCompanies,
                'shipments_active' => $activeShipments,
                'shipments_completed_this_month' => $completedThisMonth,
                'documents_expiring_soon' => $expiringSoonCount,
                'documents_expired' => $expiredCount,
            ],
            'alerts' => $alerts,
        ], 200);
    }

    /**
     * "Documents Expiring Soon" / "Expired Documents" alert tap-through:
     * a list of the AFFECTED PEOPLE (driver/truck-owner/company), not an
     * approval queue — per spec, the person may well not have submitted a
     * renewal yet, so this is deliberately separate from
     * ProfileController::adminIndex() (the actual Document Renewals
     * queue). One flat list merging all three document tables.
     */
    public function documentAlerts(Request $request)
    {
        $this->requireAdmin($request);
        $status = $request->query('status', 'expiring_soon');
        if (! in_array($status, ['expiring_soon', 'expired'], true)) {
            return response()->json(['message' => 'status must be expiring_soon or expired'], 422);
        }

        $items = collect();

        DriverDocument::where('is_current', true)->where('status', $status)
            ->with('driver')
            ->get()
            ->each(function (DriverDocument $doc) use ($items) {
                if (! $doc->driver) {
                    return;
                }
                $items->push([
                    'subject_type' => 'driver',
                    'subject_id' => $doc->driver->id,
                    'name' => $doc->driver->name,
                    'document_type' => $doc->type,
                    'expiry_date' => optional($doc->expiry_date)->toDateString(),
                ]);
            });

        TruckDocument::where('is_current', true)->where('status', $status)
            ->with('truck.ownerDriver')
            ->get()
            ->each(function (TruckDocument $doc) use ($items) {
                $driver = $doc->truck?->ownerDriver;
                if (! $driver) {
                    return;
                }
                $items->push([
                    'subject_type' => 'driver',
                    'subject_id' => $driver->id,
                    'name' => $driver->name,
                    'document_type' => "truck_{$doc->type}",
                    'expiry_date' => optional($doc->expiry_date)->toDateString(),
                ]);
            });

        CompanyDocument::where('is_current', true)->where('status', $status)
            ->with('company')
            ->get()
            ->each(function (CompanyDocument $doc) use ($items) {
                if (! $doc->company) {
                    return;
                }
                $items->push([
                    'subject_type' => 'company',
                    'subject_id' => $doc->company->id,
                    'name' => $doc->company->name,
                    'document_type' => $doc->type,
                    'expiry_date' => optional($doc->expiry_date)->toDateString(),
                ]);
            });

        return response()->json([
            'message' => 'Affected accounts retrieved successfully',
            'items' => $items->values(),
        ], 200);
    }
}
