<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\FinancialTransaction;
use App\Models\Shipment;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;

class ReportController extends Controller
{
    /**
     * Human-readable labels matching the Flutter side's statusLabel(),
     * kept here so report output reads the same way across both apps.
     */
    private function statusLabel(int $status): string
    {
        return [
            0 => 'Pending',
            1 => 'In Transit',
            2 => 'Out for Delivery',
            3 => 'Delivered',
            4 => 'Cancelled',
            5 => 'Delayed',
        ][$status] ?? 'Unknown';
    }

    /**
     * Security fix (2026-08-26): every /reports/* endpoint used to sit
     * behind nothing but the blanket auth:sanctum group — any logged-in
     * driver or company could request every driver's/company's report and
     * the overall commission summary straight from the API, even though
     * the Flutter UI never exposed a Reports button to them.
     *
     * Scope tightened again (2026-08-27): Reports moved from "any sub
     * admin" to specifically finance and crm — reports/financial oversight
     * (payments, receipts, commission) for companies and drivers is the
     * finance admin's area, and crm was confirmed to also need read
     * access (view-only; crm holds no admin/reject actions on Reports
     * regardless, since this controller has none). trainer and
     * technical_check are document-review-only roles (see
     * ProfileController::reviewPermissionFor()) and do not see Reports at
     * all. hasPermission() already returns true unconditionally for
     * Super Admin, so no separate isSuperAdmin() check is needed here.
     */
    private function requireAdmin(Request $request)
    {
        $user = $request->user();
        if (! $user->hasPermission('finance') && ! $user->hasPermission('crm')) {
            return response()->json(['message' => 'You are not authorized to view reports'], 403);
        }

        return null;
    }

    /**
     * ?period=month|30d|all (default: all — no filter). Applied against
     * shipments.created_at everywhere it's used, so "this month" means
     * "shipments created this month", consistently across the summary,
     * driver, and company reports.
     */
    private function periodStart(?string $period): ?Carbon
    {
        return match ($period) {
            'month' => now()->startOfMonth(),
            '30d' => now()->subDays(30),
            default => null,
        };
    }

    /**
     * Admin: for every driver, how many shipments they completed vs
     * cancelled — a quick way to spot reliable drivers vs problem ones.
     */
    public function drivers(Request $request)
    {
        if ($response = $this->requireAdmin($request)) {
            return $response;
        }

        $since = $this->periodStart($request->query('period'));

        // Perf fix (2026-08-26): this used to run 2 extra queries PER
        // driver (Shipment::where('driver_id', $id)->where('status',
        // X)->count()) inside the ->map() loop — 200 drivers meant ~400
        // queries for one report screen. Replaced with two grouped
        // aggregate queries total, keyed by driver_id; the response JSON
        // shape is byte-for-byte identical, only the query count changes.
        $completed = Shipment::where('status', 3)
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since))
            ->selectRaw('driver_id, COUNT(*) as cnt')
            ->groupBy('driver_id')
            ->pluck('cnt', 'driver_id');

        $cancelled = Shipment::where('status', 4)
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since))
            ->selectRaw('driver_id, COUNT(*) as cnt')
            ->groupBy('driver_id')
            ->pluck('cnt', 'driver_id');

        $drivers = Driver::all()->map(function (Driver $driver) use ($completed, $cancelled) {
            return [
                'id' => $driver->id,
                'name' => $driver->name,
                'rating' => $driver->rating,
                'compliance_status' => $driver->compliance_status,
                'completed_count' => (int) ($completed[$driver->id] ?? 0),
                'cancelled_count' => (int) ($cancelled[$driver->id] ?? 0),
            ];
        });

        return response()->json([
            'message' => 'Driver report retrieved successfully',
            'drivers' => $drivers,
        ], 200);
    }

    /**
     * Shared by myReport() and driverSelf() below so both endpoints return
     * the exact same shape.
     */
    private function buildDriverReport(Driver $driver): array
    {
        return [
            'completed_count' => Shipment::where('driver_id', $driver->id)
                ->where('status', 3)->count(),
            'cancelled_count' => Shipment::where('driver_id', $driver->id)
                ->where('status', 4)->count(),
            // Surfaced here (rather than a new endpoint) so the existing
            // Profile screen call gets it for free — used by the Flutter
            // balance page to show the driver's current withdrawable amount.
            'balance' => $driver->balance,
            'has_pending_payout' => $driver->hasPendingPayout(),
            // Driver Wallet redesign (2026-08-17): "Total Earnings" is this
            // calendar month's realized earnings — summed straight from the
            // ledger (the single source of truth for balance-affecting
            // events), not derived from `balance` which is a running total
            // net of payouts.
            'total_earnings_this_month' => (float) FinancialTransaction::where('account_type', FinancialTransaction::ACCOUNT_DRIVER)
                ->where('account_id', $driver->id)
                ->where('transaction_type', 'DRIVER_EARNING')
                ->where('status', FinancialTransaction::STATUS_POSTED)
                ->whereBetween('created_at', [now()->startOfMonth(), now()->endOfMonth()])
                ->sum('amount'),
            // Bug fix (2026-08-26): this used to also require
            // status=3 ("Delivered"), but status is only ever set to 3
            // inside ShipmentController::confirmDelivery()/resolveDispute()
            // — i.e. AT THE SAME TIME delivery_status becomes 'confirmed'.
            // There is no code path where status=3 and
            // delivery_status='awaiting_confirmation' are simultaneously
            // true, so the old query always matched zero rows and
            // pending_amount was permanently stuck at 0 even when a driver
            // genuinely had a delivered-but-unconfirmed shipment sitting in
            // limbo. delivery_status alone is the correct signal here —
            // status is irrelevant (still pre-3) at this point.
            'pending_amount' => (float) Shipment::where('driver_id', $driver->id)
                ->where('delivery_status', 'awaiting_confirmation')
                ->sum('price_to_driver'),
            // New (2026-08-26): money tied up in a shipment the company
            // disputed instead of confirmed — not paid, not necessarily
            // ever going to be, but worth surfacing separately from
            // pending_amount so a driver isn't left wondering why a
            // delivered shipment's earnings never showed up anywhere.
            'disputed_amount' => (float) Shipment::where('driver_id', $driver->id)
                ->where('delivery_status', 'disputed')
                ->sum('price_to_driver'),
            // UC-23/24/25/26: surfaced here too, for the same reason as
            // balance above — the Profile screen already calls this.
            'rating' => $driver->rating,
            'compliance_status' => $driver->compliance_status,
        ];
    }

    /**
     * Driver app: this driver's OWN report, resolved from the
     * authenticated user rather than any client-supplied id — the
     * IDOR-safe replacement for driverSelf() below. Flutter should call
     * this one; driverSelf() is kept only for backward compatibility (now
     * with an ownership check of its own — see there).
     */
    public function myReport(Request $request)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        return response()->json(array_merge(
            ['message' => 'Driver report retrieved successfully'],
            $this->buildDriverReport($driver)
        ), 200);
    }

    /**
     * Security fix (2026-08-26): this used to trust $driver_user_id
     * straight from the URL with no check that it belonged to the caller
     * — any authenticated user could read any driver's balance, pending
     * earnings, rating, and compliance status by changing the id in the
     * URL (IDOR). Now only the driver themselves, or an admin with the
     * same finance/crm scope as requireAdmin() above, may fetch it (see
     * 2026-08-27 note there). New clients should prefer myReport()/
     * `/my-driver-report` above, which doesn't take an id at all; this
     * route is kept only because nothing forces every caller to have
     * upgraded yet.
     */
    public function driverSelf(Request $request, $driver_user_id)
    {
        $requester = $request->user();
        if ((string) $requester->id !== (string) $driver_user_id
            && ! $requester->hasPermission('finance')
            && ! $requester->hasPermission('crm')) {
            return response()->json(['message' => 'You are not authorized to view this report'], 403);
        }

        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        return response()->json(array_merge(
            ['message' => 'Driver report retrieved successfully'],
            $this->buildDriverReport($driver)
        ), 200);
    }

    /**
     * Admin: for every company, shipment counts broken down by status,
     * plus their top 3 most frequently requested destinations.
     */
    public function companies(Request $request)
    {
        if ($response = $this->requireAdmin($request)) {
            return $response;
        }

        $since = $this->periodStart($request->query('period'));

        // Perf fix (2026-08-26): this used to run
        // Shipment::where('company_id', $id)->get() — a full-row fetch —
        // PER company inside the ->map() loop, then group/count in PHP.
        // Replaced with two grouped aggregate queries total.
        $statusRows = Shipment::query()
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since))
            ->selectRaw('company_id, status, COUNT(*) as cnt')
            ->groupBy('company_id', 'status')
            ->get()
            ->groupBy('company_id');

        $destinationRows = Shipment::query()
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since))
            ->whereNotNull('destination')
            ->where('destination', '!=', '')
            ->selectRaw('company_id, destination, COUNT(*) as cnt')
            ->groupBy('company_id', 'destination')
            ->get()
            ->groupBy('company_id');

        $companies = Company::all()->map(function (Company $company) use ($statusRows, $destinationRows) {
            $byStatus = [];
            $total = 0;
            foreach ($statusRows->get($company->id, collect()) as $row) {
                $label = $this->statusLabel((int) $row->status);
                $byStatus[$label] = ($byStatus[$label] ?? 0) + (int) $row->cnt;
                $total += (int) $row->cnt;
            }

            $topDestinations = $destinationRows->get($company->id, collect())
                ->sortByDesc('cnt')
                ->take(3)
                ->mapWithKeys(fn ($row) => [$row->destination => (int) $row->cnt]);

            return [
                'id' => $company->id,
                'name' => $company->name,
                'total_shipments' => $total,
                // Bug fix (2026-08-25): a PHP array with no elements
                // json_encode()s as `[]`, not `{}` — PHP can't tell an
                // empty associative array from an empty list. A company
                // with zero matching shipments left $byStatus/
                // $topDestinations empty, so the response sent `[]` for
                // that field instead of `{}`, which crashed Flutter's
                // Map<String, dynamic>.from(...) cast. Casting to (object)
                // forces `{}` for the empty case too.
                'by_status' => (object) $byStatus,
                'top_destinations' => (object) $topDestinations->toArray(),
            ];
        });

        return response()->json([
            'message' => 'Company report retrieved successfully',
            'companies' => $companies,
        ], 200);
    }

    /**
     * Admin: overall commission earned so far — the difference between
     * what clients were charged and what drivers were paid, summed across
     * every delivered-and-confirmed shipment — plus a small delivered/
     * active/cancelled breakdown for the dashboard's "Shipments Overview"
     * chart.
     */
    public function summary(Request $request)
    {
        if ($response = $this->requireAdmin($request)) {
            return $response;
        }

        $since = $this->periodStart($request->query('period'));

        // Realized-commission fix (2026-08-26): in every current code path
        // a shipment only ever reaches status=3 together with
        // delivery_status='confirmed' in the exact same update() call (see
        // ShipmentController::confirmDelivery()/resolveDispute()) — a
        // disputed shipment stays below status 3 until the dispute is
        // resolved, at which point it becomes 'confirmed' too. So this
        // condition is redundant against today's state machine, but it's
        // cheap defense-in-depth: commission can never silently include a
        // disputed shipment even if a future code path sets status=3
        // without going through the confirm flow. Sum moved from PHP
        // (->get() then Collection::sum()) to SQL for the same reason the
        // N+1 fixes above moved to aggregate queries.
        $delivered = Shipment::where('status', 3)
            ->where('delivery_status', 'confirmed')
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since));

        $deliveredCount = (clone $delivered)->count();
        $totalCommission = (float) (clone $delivered)
            ->selectRaw('COALESCE(SUM(price_to_client - price_to_driver), 0) as commission')
            ->value('commission');

        // New (2026-08-26): backs the Admin Dashboard's "Shipments
        // Overview" bar chart — Delivered / Active (everything that isn't
        // delivered or cancelled: Pending, In Transit, Out for Delivery,
        // Delayed) / Cancelled, honoring the same period filter as the
        // rest of this endpoint. One extra grouped query.
        $statusCounts = Shipment::query()
            ->when($since, fn ($q) => $q->where('created_at', '>=', $since))
            ->selectRaw('status, COUNT(*) as cnt')
            ->groupBy('status')
            ->pluck('cnt', 'status');

        return response()->json([
            'message' => 'Summary report retrieved successfully',
            'delivered_shipments_count' => $deliveredCount,
            'total_commission' => round($totalCommission, 2),
            'currency' => 'AED',
            'status_overview' => [
                'delivered' => (int) ($statusCounts[3] ?? 0),
                'active' => (int) $statusCounts->except([3, 4])->sum(),
                'cancelled' => (int) ($statusCounts[4] ?? 0),
            ],
        ], 200);
    }
}
