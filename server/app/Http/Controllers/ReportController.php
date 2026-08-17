<?php

namespace App\Http\Controllers;

use App\Models\Company;
use App\Models\Driver;
use App\Models\FinancialTransaction;
use App\Models\Shipment;

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
     * Admin: for every driver, how many shipments they completed vs
     * cancelled — a quick way to spot reliable drivers vs problem ones.
     */
    public function drivers()
    {
        $drivers = Driver::all()->map(function (Driver $driver) {
            return [
                'id' => $driver->id,
                'name' => $driver->name,
                'rating' => $driver->rating,
                'compliance_status' => $driver->compliance_status,
                'completed_count' => Shipment::where('driver_id', $driver->id)
                    ->where('status', 3)->count(),
                'cancelled_count' => Shipment::where('driver_id', $driver->id)
                    ->where('status', 4)->count(),
            ];
        });

        return response()->json([
            'message' => 'Driver report retrieved successfully',
            'drivers' => $drivers,
        ], 200);
    }

    /**
     * Driver app: this driver's own completed/cancelled counts, for the
     * stats card shown on their profile.
     */
    public function driverSelf($driver_user_id)
    {
        $driver = Driver::where('user_id', $driver_user_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        return response()->json([
            'message' => 'Driver report retrieved successfully',
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
            // net of payouts. "Pending Amount" is money already earned from
            // a delivered shipment that hasn't been credited to `balance`
            // yet because the company hasn't confirmed delivery
            // (delivery_status stays 'awaiting_confirmation' until then —
            // see Shipment::confirmByCompany()). Deliberately NOT the same
            // number as `balance`, which is the current withdrawable amount.
            'total_earnings_this_month' => (float) FinancialTransaction::where('account_type', FinancialTransaction::ACCOUNT_DRIVER)
                ->where('account_id', $driver->id)
                ->where('transaction_type', 'DRIVER_EARNING')
                ->where('status', FinancialTransaction::STATUS_POSTED)
                ->whereBetween('created_at', [now()->startOfMonth(), now()->endOfMonth()])
                ->sum('amount'),
            'pending_amount' => (float) Shipment::where('driver_id', $driver->id)
                ->where('status', 3)
                ->where('delivery_status', 'awaiting_confirmation')
                ->sum('price_to_driver'),
            // UC-23/24/25/26: surfaced here too, for the same reason as
            // balance above — the Profile screen already calls this.
            'rating' => $driver->rating,
            'compliance_status' => $driver->compliance_status,
        ], 200);
    }

    /**
     * Admin: for every company, shipment counts broken down by status,
     * plus their top 3 most frequently requested destinations.
     */
    public function companies()
    {
        $companies = Company::all()->map(function (Company $company) {
            $shipments = Shipment::where('company_id', $company->id)->get();

            $byStatus = [];
            foreach ($shipments as $shipment) {
                $label = $this->statusLabel((int) $shipment->status);
                $byStatus[$label] = ($byStatus[$label] ?? 0) + 1;
            }

            $topDestinations = $shipments
                ->filter(fn ($s) => ! empty($s->destination))
                ->groupBy('destination')
                ->map(fn ($group) => $group->count())
                ->sortDesc()
                ->take(3);

            return [
                'id' => $company->id,
                'name' => $company->name,
                'total_shipments' => $shipments->count(),
                'by_status' => $byStatus,
                'top_destinations' => $topDestinations,
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
     * every delivered shipment.
     */
    public function summary()
    {
        $delivered = Shipment::where('status', 3)->get();

        $totalCommission = $delivered->sum(function (Shipment $shipment) {
            return (float) ($shipment->price_to_client ?? 0)
                - (float) ($shipment->price_to_driver ?? 0);
        });

        return response()->json([
            'message' => 'Summary report retrieved successfully',
            'delivered_shipments_count' => $delivered->count(),
            'total_commission' => round($totalCommission, 2),
        ], 200);
    }
}
