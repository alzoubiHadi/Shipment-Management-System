<?php

namespace App\Http\Controllers;

use App\Http\Resources\CompanyFacingDriverResource;
use App\Models\ActivityLog;
use App\Models\Company;
use App\Models\Driver;
use App\Models\Shipment;
use App\Models\ShipmentComment;
use App\Models\User;
use App\Notifications\AppPushNotification;
use App\Services\LedgerService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class ShipmentController extends Controller
{
    //
    public function assignDriver(Request $request)
    {
        $shipment = Shipment::findOrFail($request->shipmentId);
        $driver = Driver::findOrFail($request->driverId);

        $shipment->update([
            'driver_id' => $driver->id,
            'status' => 1, // assigned
        ]);

        return response()->json([
            'message' => 'Driver assigned to shipment successfully',
            'shipment' => $shipment,
        ], 200);
    }
    public function refuse(Request $request)
    {
        $shipment = Shipment::findOrFail($request->shipment_id);
        $shipment->update([
            'status' => 0, // refused
        ]);

        return response()->json([
            'message' => 'Shipment refused successfully',
            'shipment' => $shipment,
        ], 200);
    }
    public function index()
    {
        // List all shipments
        $shipments = Shipment::all();
        return response()->json([
            'message' => 'shipments Displayed successfully',
            'shipments' => $shipments,
        ], 200);
    }
    public function delete(Shipment $shipment)
    {        // Soft delete a shipment
        $shipment->delete();
        return response()->json([
            'message' => 'Shipment deleted successfully',
        ], 200);
    }
    public function restore($id)
    {
        // Restore a soft-deleted shipment
        $shipment = Shipment::withTrashed()->findOrFail($id);
        $shipment->restore();
        return response()->json([
            'message' => 'Shipment restored successfully',
            'shipment' => $shipment,
        ], 200);
    }
    public function create(Request $request)
    {
        $user_id = auth()->user()->id;

        $company = Company::where('user_id', $user_id)->first();

        if (!$company) {
            return response()->json([
                'message' => 'Company not found'
            ], 404);
        }

        $trackingNumber = $request->tracking_number ?? uniqid('TRK');

        $exists = Shipment::where('tracking_number', $trackingNumber)->exists();

        if ($exists) {
            return response()->json([
                'message' => 'Tracking number already exists',
                'tracking_number' => $trackingNumber,
            ], 205);
        }

        $shipment = Shipment::create([
            'company_id' => $company->id,
            'origin' => $request->origin,
            'destination' => $request->destination,
            'weight' => $request->weight,
            'description' => $request->description,
            'tracking_number' => $trackingNumber,
            'status' => 0,
        ]);

        return response()->json([
            'message' => 'Shipment created successfully',
            'shipment' => $shipment,
        ], 201);
    }
    public function update(Request $request, Shipment $shipment)
    {


        $shipment->update([
            'driver_id' => $request->driver_id ?? $shipment->driver_id,
            'status' => $request->status ?? $shipment->status,
            'pickup_time' => $request->pickup_time ?? $shipment->pickup_time,
            'delivered_at' => $request->delivered_at ?? $shipment->delivered_at,
        ]);

        return response()->json([
            'message' => 'Shipment updated successfully',
            'shipment' => $shipment,
        ], 200);
    }
    /**
     * Driver data attached here is stripped to the company-safe subset
     * (CompanyFacingDriverResource) — health_conditions, balance, and the
     * rest of the admin-only fields never leave this endpoint. A company
     * only ever sees the driver actually assigned to ITS own shipment, so
     * visibility is inherently scoped to that relationship.
     */
    public function trackmyshipment($tracking_number)
    {
        $shipment = Shipment::with('driver', 'truck')->where('tracking_number', $tracking_number)->first();

        if (!$shipment) {
            return response()->json([
                'message' => 'Shipment not found',
            ], 404);
        }

        $data = $shipment->toArray();
        $data['driver'] = $shipment->driver ? new CompanyFacingDriverResource($shipment->driver) : null;

        return response()->json([
            'message' => 'Shipment tracked successfully',
            'shipment' => $data,
        ], 200);
    }
    public function drivergetShipments($driver_id)
    {
        $driver = Driver::where('user_id', $driver_id)->first();

        if (! $driver) {
            return response()->json(['message' => 'Driver not found'], 404);
        }

        $shipments = Shipment::where('driver_id', $driver->id)->get();

        return response()->json([
            'message' => 'Shipments retrieved successfully',
            'shipments' => $shipments,
        ], 200);
    }
    public function companygetShipments($company_id)
    {
        $company = Company::where('user_id', $company_id)->first();

        if (! $company) {
            return response()->json(['message' => 'Company not found'], 404);
        }

        $shipments = Shipment::with('driver', 'truck')
            ->where('company_id', $company->id)
            ->get()
            ->map(function (Shipment $shipment) {
                $data = $shipment->toArray();
                $data['driver'] = $shipment->driver ? new CompanyFacingDriverResource($shipment->driver) : null;
                return $data;
            });

        return response()->json([
            'message' => 'Shipments retrieved successfully',
            'shipments' => $shipments,
        ], 200);
    }
    /**
     * Driver app: move the shipment forward one step in its tracking
     * timeline (internal: 1 going to load ... 4 offloading; external: 1
     * going to load ... 6 offloading). The stage after this range
     * ("Uploading delivery note") is handled by deliver() below since it
     * requires a proof-of-delivery signature; the final "Completed" stage
     * is handled by confirmDelivery() since only the company can mark it.
     */
    public function advanceStage(Request $request, Shipment $shipment)
    {
        $driver = Driver::where('user_id', auth()->user()->id)->first();

        if (! $driver || $shipment->driver_id != $driver->id) {
            return response()->json([
                'message' => 'You are not assigned to this shipment',
            ], 403);
        }

        $orderType = $shipment->order_type ?? 'internal';
        $maxAdvance = Shipment::driverAdvanceMaxFor($orderType);
        $nextStage = $shipment->current_stage + 1;

        if ($nextStage > $maxAdvance) {
            return response()->json([
                'message' => 'Use the delivery endpoint to complete the final stage',
            ], 422);
        }

        $shipment->update([
            'current_stage' => $nextStage,
            Shipment::advanceColumnsFor($orderType)[$nextStage] => now(),
        ]);

        return response()->json([
            'message' => 'Shipment stage updated successfully',
            'shipment' => $shipment,
        ], 200);
    }

    /**
     * Driver app (UC-19): final tracking stage. Captures the
     * proof-of-delivery signature and recipient name and moves the
     * shipment to "awaiting company confirmation" — deliberately does NOT
     * free the driver or mark the shipment fully "delivered" yet. Per the
     * spec, the driver stays busy and unpaid until the company actually
     * confirms (UC-20, ShipmentController::confirmDelivery) or a dispute
     * gets resolved in the driver's favor — crediting a driver's balance
     * (or freeing them) the instant they merely claim delivery would let
     * an unscrupulous driver get paid for a shipment that never arrived.
     */
    public function deliver(Request $request, Shipment $shipment)
    {
        $driver = Driver::where('user_id', auth()->user()->id)->first();

        if (! $driver || $shipment->driver_id != $driver->id) {
            return response()->json([
                'message' => 'You are not assigned to this shipment',
            ], 403);
        }

        $orderType = $shipment->order_type ?? 'internal';
        $maxAdvance = Shipment::driverAdvanceMaxFor($orderType);

        if ($shipment->current_stage < $maxAdvance) {
            return response()->json([
                'message' => 'Complete unloading before capturing the delivery signature',
            ], 422);
        }

        $validated = $request->validate([
            'pod_signature' => ['required', 'string'],
            'pod_recipient_name' => ['required', 'string'],
        ]);

        $shipment->update([
            'current_stage' => $maxAdvance + 1,
            'delivered_at' => now(),
            'pod_signature' => $validated['pod_signature'],
            'pod_recipient_name' => $validated['pod_recipient_name'],
        ]);

        $shipment->markAwaitingCompanyConfirmation();

        $company = $shipment->company;
        if ($company && $company->user) {
            $company->user->notify(new AppPushNotification(
                'delivery_awaiting_confirmation',
                'Delivery awaiting your confirmation',
                sprintf('Shipment %s has been delivered — please review and confirm receipt.', $shipment->tracking_number),
                ['shipment_id' => $shipment->id],
            ));
        }

        return response()->json([
            'message' => 'Delivery recorded — awaiting company confirmation',
            'shipment' => $shipment->fresh(),
        ], 200);
    }

    /**
     * Company app (UC-20): reviews the proof of delivery and confirms
     * receipt. This is the ONLY action that credits the driver's balance
     * and the only thing that frees the driver back up for new jobs —
     * never deliver() above.
     */
    public function confirmDelivery(Request $request, Shipment $shipment)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company || $shipment->company_id !== $company->id) {
            return response()->json(['message' => 'This is not your shipment'], 403);
        }

        if ($shipment->delivery_status !== 'awaiting_confirmation') {
            return response()->json([
                'message' => 'This shipment is not currently awaiting your confirmation',
            ], 409);
        }

        DB::transaction(function () use ($shipment, $request) {
            $shipment = Shipment::lockForUpdate()->findOrFail($shipment->id);

            $shipment->confirmByCompany($request->user());
            // "Completed" is the final tracking stage and only the
            // company's own confirmation may reach it — never the driver.
            $shipment->update([
                'status' => 3, // delivered
                'current_stage' => Shipment::totalStagesFor($shipment->order_type ?? 'internal'),
            ]);

            $driver = Driver::lockForUpdate()->find($shipment->driver_id);
            if ($driver) {
                app(LedgerService::class)->record(
                    $driver,
                    'DRIVER_EARNING',
                    (float) $shipment->price_to_driver,
                    $shipment,
                    "Earning for shipment {$shipment->tracking_number}",
                );
                $driver->update(['status' => 'available']);

                ActivityLog::record(
                    'shipment.delivery_confirmed',
                    $shipment,
                    "Company confirmed receipt of shipment {$shipment->tracking_number} — driver credited {$shipment->price_to_driver} AED",
                    ['shipment_id' => $shipment->id, 'amount' => $shipment->price_to_driver]
                );

                $driver->user?->notify(new AppPushNotification(
                    'balance_credited',
                    'Payment received',
                    sprintf('Your balance was credited %s AED for shipment %s.', $shipment->price_to_driver, $shipment->tracking_number),
                    ['shipment_id' => $shipment->id],
                ));
            }
        });

        return response()->json([
            'message' => 'Delivery confirmed — driver has been paid',
            'shipment' => $shipment->fresh(),
        ], 200);
    }

    /**
     * Company app (UC-20 alternative flow): reports a problem instead of
     * confirming (missing/damaged goods, etc.). Routes to CRM/Super Admin
     * review instead of auto-crediting the driver — the driver stays busy
     * and unpaid until resolveDispute() below settles it either way.
     */
    public function disputeDelivery(Request $request, Shipment $shipment)
    {
        $company = Company::where('user_id', $request->user()->id)->first();

        if (! $company || $shipment->company_id !== $company->id) {
            return response()->json(['message' => 'This is not your shipment'], 403);
        }

        if ($shipment->delivery_status !== 'awaiting_confirmation') {
            return response()->json([
                'message' => 'This shipment is not currently awaiting your confirmation',
            ], 409);
        }

        $validated = $request->validate([
            'dispute_reason' => ['required', 'string'],
        ]);

        $shipment->disputeDelivery($validated['dispute_reason']);

        $this->notifyAdminsOfDispute($shipment);

        return response()->json([
            'message' => 'Dispute recorded — an admin will review this delivery',
            'shipment' => $shipment->fresh(),
        ], 200);
    }

    /**
     * Super Admin / CRM Admin: settles a disputed delivery. 'confirm' pays
     * the driver exactly like a normal company confirmation would have;
     * 'reject' closes it out with no payment (the driver's account of
     * events wasn't accepted) but still frees them for new jobs — the
     * shipment itself already physically happened, so it isn't cancelled.
     */
    public function resolveDispute(Request $request, Shipment $shipment)
    {
        if (! $request->user()->isSuperAdmin() && ! $request->user()->hasPermission('crm')) {
            return response()->json(['message' => 'You are not authorized to resolve delivery disputes'], 403);
        }

        if ($shipment->delivery_status !== 'disputed') {
            return response()->json(['message' => 'This shipment is not currently disputed'], 409);
        }

        $validated = $request->validate([
            'resolution' => ['required', 'in:confirm,reject'],
        ]);

        DB::transaction(function () use ($shipment, $validated, $request) {
            $shipment = Shipment::lockForUpdate()->findOrFail($shipment->id);
            $driver = Driver::lockForUpdate()->find($shipment->driver_id);

            if ($validated['resolution'] === 'confirm') {
                $shipment->confirmByCompany($request->user());
                $shipment->update(['status' => 3]);

                if ($driver) {
                    app(LedgerService::class)->record(
                        $driver,
                        'DRIVER_EARNING',
                        (float) $shipment->price_to_driver,
                        $shipment,
                        "Earning for shipment {$shipment->tracking_number} (dispute resolved in driver's favor)",
                    );
                    $driver->user?->notify(new AppPushNotification(
                        'balance_credited',
                        'Payment received',
                        sprintf('Your balance was credited %s AED for shipment %s (dispute resolved in your favor).', $shipment->price_to_driver, $shipment->tracking_number),
                        ['shipment_id' => $shipment->id],
                    ));
                }
            } else {
                $shipment->update(['delivery_status' => 'confirmed', 'status' => 3]);

                $driver?->user?->notify(new AppPushNotification(
                    'dispute_resolved_against_driver',
                    'Delivery dispute resolved',
                    sprintf('The dispute for shipment %s was resolved without payment.', $shipment->tracking_number),
                    ['shipment_id' => $shipment->id],
                ));
            }

            ActivityLog::record(
                'shipment.dispute_resolved',
                $shipment,
                "Resolved delivery dispute for shipment {$shipment->tracking_number}: {$validated['resolution']}",
                ['resolution' => $validated['resolution']]
            );

            $driver?->update(['status' => 'available']);
        });

        return response()->json([
            'message' => 'Dispute resolved',
            'shipment' => $shipment->fresh(),
        ], 200);
    }

    /**
     * UC-22: driver adds a field comment to a shipment they're actively
     * assigned to (e.g. a technical problem CRM Admin should know about).
     */
    public function addComment(Request $request, Shipment $shipment)
    {
        $driver = Driver::where('user_id', $request->user()->id)->first();

        if (! $driver || $shipment->driver_id != $driver->id) {
            return response()->json([
                'message' => 'You are not assigned to this shipment',
            ], 403);
        }

        $validated = $request->validate([
            'comment' => ['required', 'string', 'max:2000'],
        ]);

        $comment = ShipmentComment::create([
            'shipment_id' => $shipment->id,
            'user_id' => $request->user()->id,
            'comment' => $validated['comment'],
        ]);

        return response()->json([
            'message' => 'Comment added successfully',
            'comment' => $comment,
        ], 201);
    }

    /**
     * Shared by the driver (their own shipment), the owning company, and
     * any admin — every party who can already see this shipment can see
     * its comment log.
     */
    public function listComments(Request $request, Shipment $shipment)
    {
        $user = $request->user();

        $driver = Driver::where('user_id', $user->id)->first();
        $company = Company::where('user_id', $user->id)->first();

        $isAssignedDriver = $driver && $shipment->driver_id == $driver->id;
        $isOwningCompany = $company && $shipment->company_id == $company->id;
        $isAdmin = $user->isSuperAdmin() || $user->isSubAdmin();

        if (! $isAssignedDriver && ! $isOwningCompany && ! $isAdmin) {
            return response()->json(['message' => 'You cannot view this shipment'], 403);
        }

        return response()->json([
            'message' => 'Comments retrieved successfully',
            'comments' => $shipment->comments()->with('user:id,name,type')->get(),
        ], 200);
    }

    /**
     * UC-25/13-style broadcast: every Super Admin plus every sub-admin
     * holding the 'crm' permission, mirroring
     * ShipmentOfferController::notifyCrmAdmins.
     */
    private function notifyAdminsOfDispute(Shipment $shipment): void
    {
        $crmAdmins = User::where('type', 'super_admin')
            ->orWhere('type', 'admin')
            ->orWhere(function ($q) {
                $q->where('type', 'sub_admin')->whereHas('permissions', fn ($p) => $p->where('key', 'crm'));
            })
            ->get();

        foreach ($crmAdmins as $admin) {
            $admin->notify(new AppPushNotification(
                'delivery_disputed',
                'Delivery dispute needs review',
                sprintf('Company disputed delivery for shipment %s: %s', $shipment->tracking_number, $shipment->dispute_reason),
                ['shipment_id' => $shipment->id],
            ));
        }
    }

    public function updateshipmentstatus(Request $request)
    {
        $shipment = Shipment::findOrFail($request->shipment_id);
        $newStatus = $request->status ?? $shipment->status;

        // Cancelling a shipment requires a reason (missing documents,
        // client declined, etc.) so the admin/company can see why later.
        if ((int) $newStatus === 4 && empty($request->cancellation_reason)) {
            return response()->json([
                'message' => 'A cancellation reason is required to cancel a shipment',
            ], 422);
        }

        $shipment->update([
            'status' => $newStatus,
            'cancellation_reason' => (int) $newStatus === 4
                ? $request->cancellation_reason
                : $shipment->cancellation_reason,
            // Cancellation Report screen (2026-08-24): who + exactly when,
            // not inferable from updated_at alone (that column changes on
            // every subsequent edit, not just the cancellation itself).
            'cancelled_by_user_id' => (int) $newStatus === 4 ? $request->user()->id : $shipment->cancelled_by_user_id,
            'cancelled_at' => (int) $newStatus === 4 ? now() : $shipment->cancelled_at,
        ]);

        // Free the driver back up once the job is finished (delivered=3, cancelled=4)
        if (in_array((int) $shipment->status, [3, 4]) && $shipment->driver_id) {
            $driver = Driver::find($shipment->driver_id);
            $driver?->update(['status' => 'available']);
        }

        if ((int) $shipment->status === 3) {
            $shipment->update(['delivered_at' => now()]);
        }

        return response()->json([
            'message' => 'Shipment status updated successfully',
            'shipment' => $shipment,
        ], 200);
    }
}
