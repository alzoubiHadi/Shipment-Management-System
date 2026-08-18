<?php

namespace App\Http\Controllers;

use App\Models\Shipment;
use App\Models\ShipmentOffer;
use App\Models\ShipmentOfferMatchingRound;
use App\Services\MatchingService;
use App\Support\Geo;
use Carbon\Carbon;
use Illuminate\Http\Request;

/**
 * Admin Shipments redesign (2026-08-24) — backs the new card-based admin
 * Shipments list plus its status-aware detail routing (Pending -> Matching
 * Status, Active -> Live Tracking, Delivered -> Trip Report, Cancelled ->
 * Cancellation Report). The list is a UNIFIED feed merging two different
 * backing tables:
 *   - ShipmentOffer rows still in 'pending'/'awaiting_manual_price'/
 *     'escalated' — no Shipment row exists yet at this point (one is only
 *     created once a driver actually accepts, see
 *     ShipmentOfferController::finalizeAcceptance()).
 *   - Shipment rows for everything else (assigned/in-transit/delivered/
 *     cancelled).
 * Both now carry their own tracking_number (offers got one in this same
 * pass — see the 2026_08_24_000204 migration), so the admin sees one
 * continuous #TRK-xxxxx identity across the whole lifecycle instead of the
 * offers-vs-shipments split being visible in the UI.
 */
class AdminShipmentController extends Controller
{
    /**
     * Unified list. Query params: group (all|active|pending|delivered|
     * cancelled, default all), search (matches tracking number/company
     * name/driver name), page/per_page (defaults 1/20).
     */
    public function index(Request $request)
    {
        $group = $request->query('group', 'all');
        $search = trim((string) $request->query('search', ''));
        $perPage = min(50, max(5, (int) $request->query('per_page', 20)));
        $page = max(1, (int) $request->query('page', 1));

        $items = collect();

        if (in_array($group, ['all', 'pending'], true)) {
            $offers = ShipmentOffer::with('company')
                ->whereIn('status', ['pending', ShipmentOffer::STATUS_AWAITING_MANUAL_PRICE, 'escalated'])
                ->when($search !== '', fn ($q) => $q->where(function ($q2) use ($search) {
                    $q2->where('tracking_number', 'like', "%{$search}%")
                        ->orWhereHas('company', fn ($c) => $c->where('name', 'like', "%{$search}%"));
                }))
                ->orderByDesc('created_at')
                ->get();

            foreach ($offers as $offer) {
                $items->push($this->summarizeOffer($offer));
            }
        }

        if ($group !== 'pending') {
            $statusesForGroup = match ($group) {
                'active' => [1, 2],
                'delivered' => [3],
                'cancelled' => [4],
                default => [0, 1, 2, 3, 4],
            };

            $shipments = Shipment::with(['company', 'driver', 'truck'])
                ->whereIn('status', $statusesForGroup)
                ->when($search !== '', fn ($q) => $q->where(function ($q2) use ($search) {
                    $q2->where('tracking_number', 'like', "%{$search}%")
                        ->orWhereHas('company', fn ($c) => $c->where('name', 'like', "%{$search}%"))
                        ->orWhereHas('driver', fn ($d) => $d->where('name', 'like', "%{$search}%"));
                }))
                ->orderByDesc('created_at')
                ->get();

            foreach ($shipments as $shipment) {
                $items->push($this->summarizeShipment($shipment));
            }
        }

        $sorted = $items->sortByDesc('created_at')->values();
        $total = $sorted->count();
        $paged = $sorted->forPage($page, $perPage)->values();

        return response()->json([
            'message' => 'Shipments retrieved successfully',
            'shipments' => $paged,
            'pagination' => ['page' => $page, 'per_page' => $perPage, 'total' => $total],
        ], 200);
    }

    /**
     * Status-aware detail, keyed by the shared tracking_number. Tries the
     * Shipment table first (the common case once a driver has accepted),
     * falls back to ShipmentOffer for anything still mid-matching.
     */
    public function show(string $trackingNumber)
    {
        $shipment = Shipment::with(['company', 'driver', 'truck', 'cancelledBy'])
            ->where('tracking_number', $trackingNumber)
            ->first();

        if ($shipment) {
            return response()->json([
                'message' => 'Shipment detail retrieved successfully',
                'kind' => 'shipment',
                'shipment' => $this->detailForShipment($shipment),
            ], 200);
        }

        $offer = ShipmentOffer::with(['company', 'cancelledBy', 'matchingRounds.acceptedByDriver'])
            ->where('tracking_number', $trackingNumber)
            ->first();

        if ($offer) {
            return response()->json([
                'message' => 'Offer detail retrieved successfully',
                'kind' => 'offer',
                'offer' => $this->detailForOffer($offer),
            ], 200);
        }

        return response()->json(['message' => 'Not found'], 404);
    }

    private function summarizeOffer(ShipmentOffer $offer): array
    {
        return [
            'kind' => 'offer',
            'id' => $offer->id,
            'tracking_number' => $offer->tracking_number ?? ('OFR-' . $offer->id),
            'status_group' => 'pending',
            'status_label' => $this->offerStatusLabel($offer),
            'origin' => $offer->origin,
            'destination' => $offer->destination,
            'order_type' => $offer->order_type,
            'weight' => $offer->weight,
            'company_name' => $offer->company->name ?? null,
            'driver_name' => null,
            'truck_label' => null,
            'created_at' => optional($offer->created_at)->toIso8601String(),
            'updated_at' => optional($offer->updated_at)->toIso8601String(),
        ];
    }

    private function summarizeShipment(Shipment $shipment): array
    {
        return [
            'kind' => 'shipment',
            'id' => $shipment->id,
            'tracking_number' => $shipment->tracking_number,
            'status_group' => $this->shipmentStatusGroup($shipment),
            'status_label' => $this->shipmentStatusLabel($shipment),
            'origin' => $shipment->origin,
            'destination' => $shipment->destination,
            'order_type' => $shipment->order_type,
            'weight' => $shipment->weight,
            'current_stage' => $shipment->current_stage,
            'total_stages' => Shipment::totalStagesFor($shipment->order_type ?? 'internal'),
            'company_name' => $shipment->company->name ?? null,
            'driver_name' => $shipment->driver->name ?? null,
            'truck_label' => $shipment->truck
                ? trim(($shipment->truck->truck_type ?? '') . ' • ' . ($shipment->truck->truck_number ?? ''), ' •')
                : null,
            'created_at' => optional($shipment->created_at)->toIso8601String(),
            'updated_at' => optional($shipment->updated_at)->toIso8601String(),
        ];
    }

    private function detailForShipment(Shipment $shipment): array
    {
        $orderType = $shipment->order_type ?? 'internal';

        $distanceKm = null;
        if ($shipment->origin_lat && $shipment->origin_lng && $shipment->destination_lat && $shipment->destination_lng) {
            $distanceKm = round(Geo::haversineKm(
                (float) $shipment->origin_lat,
                (float) $shipment->origin_lng,
                (float) $shipment->destination_lat,
                (float) $shipment->destination_lng,
            ), 1);
        }

        $labels = Shipment::stageLabelsFor($orderType);
        $advanceColumns = Shipment::advanceColumnsFor($orderType);
        $driverAdvanceMax = Shipment::driverAdvanceMaxFor($orderType);

        $stages = [];
        foreach ($labels as $num => $label) {
            if (isset($advanceColumns[$num])) {
                $timestamp = $shipment->{$advanceColumns[$num]};
            } elseif ($num === $driverAdvanceMax + 1) {
                $timestamp = $shipment->delivered_at;
            } else {
                $timestamp = $shipment->company_confirmed_at;
            }

            $stages[] = [
                'stage' => $num,
                'label' => $label,
                'timestamp' => optional($timestamp)->toIso8601String(),
                'done' => $timestamp !== null,
            ];
        }

        $durationLabel = null;
        if ($shipment->delivered_at) {
            $start = $shipment->pickup_time ? Carbon::parse($shipment->pickup_time) : $shipment->created_at;
            $minutes = $start->diffInMinutes($shipment->delivered_at);
            $durationLabel = sprintf('%dh %dm', intdiv($minutes, 60), $minutes % 60);
        }

        return [
            'id' => $shipment->id,
            'tracking_number' => $shipment->tracking_number,
            'status' => (int) $shipment->status,
            'status_group' => $this->shipmentStatusGroup($shipment),
            'status_label' => $this->shipmentStatusLabel($shipment),
            'order_type' => $orderType,
            'origin' => $shipment->origin,
            'destination' => $shipment->destination,
            'origin_lat' => $shipment->origin_lat,
            'origin_lng' => $shipment->origin_lng,
            'destination_lat' => $shipment->destination_lat,
            'destination_lng' => $shipment->destination_lng,
            'distance_km' => $distanceKm,
            'duration_label' => $durationLabel,
            'weight' => $shipment->weight,
            'description' => $shipment->description,
            'needs_permit' => $shipment->needs_permit,
            'is_hazardous' => $shipment->is_hazardous,
            'is_fragile' => $shipment->is_fragile,
            'pickup_time' => $shipment->pickup_time,
            'delivered_at' => optional($shipment->delivered_at)->toIso8601String(),
            'current_stage' => $shipment->current_stage,
            'total_stages' => Shipment::totalStagesFor($orderType),
            'stages' => $stages,
            'company' => $shipment->company ? [
                'id' => $shipment->company->id,
                'name' => $shipment->company->name,
                'phone' => $shipment->company->phone,
            ] : null,
            'driver' => $shipment->driver ? [
                'id' => $shipment->driver->id,
                'name' => $shipment->driver->name,
                'phone' => $shipment->driver->phone,
                'rating' => $shipment->driver->rating,
                'last_lat' => $shipment->driver->last_lat,
                'last_lng' => $shipment->driver->last_lng,
                'last_location_at' => optional($shipment->driver->last_location_at)->toIso8601String(),
            ] : null,
            'truck' => $shipment->truck ? [
                'id' => $shipment->truck->id,
                'truck_type' => $shipment->truck->truck_type,
                'truck_number' => $shipment->truck->truck_number,
            ] : null,
            'financial' => [
                'price_to_client' => $shipment->price_to_client,
                'price_to_driver' => $shipment->price_to_driver,
                'commission' => ($shipment->price_to_client !== null && $shipment->price_to_driver !== null)
                    ? round((float) $shipment->price_to_client - (float) $shipment->price_to_driver, 2)
                    : null,
            ],
            'delivery_status' => $shipment->delivery_status,
            // 2026-08-25: pod_document_path (photo/file) is the current
            // capture method — pod_signature is kept only for shipments
            // delivered before this change, so old trip reports still show
            // what was actually captured at the time.
            'pod' => [
                'pod_document_path' => $shipment->pod_document_path,
                'signature_present' => ! empty($shipment->pod_signature),
                'pod_signature' => $shipment->pod_signature,
                'recipient_name' => $shipment->pod_recipient_name,
            ],
            'dispute_reason' => $shipment->dispute_reason,
            'cancellation' => (int) $shipment->status === 4 ? [
                'reason' => $shipment->cancellation_reason,
                'cancelled_by' => $shipment->cancelledBy->name ?? null,
                'cancelled_at' => optional($shipment->cancelled_at)->toIso8601String(),
                'stage_reached' => $labels[$shipment->current_stage] ?? null,
                'driver_assigned' => $shipment->driver_id !== null,
            ] : null,
            'created_at' => optional($shipment->created_at)->toIso8601String(),
        ];
    }

    private function detailForOffer(ShipmentOffer $offer): array
    {
        $rounds = $offer->matchingRounds->map(fn (ShipmentOfferMatchingRound $round) => [
            'round_number' => $round->round_number,
            'driver_count' => count($round->driver_ids ?? []),
            'notified_at' => optional($round->notified_at)->toIso8601String(),
            'outcome' => $round->outcome,
            'accepted_by_driver_name' => $round->acceptedByDriver->name ?? null,
            'resolved_at' => optional($round->resolved_at)->toIso8601String(),
        ]);

        $eligibleDriversCount = $offer->status === 'pending'
            ? app(MatchingService::class)->eligibleDriversQuery($offer)->count()
            : null;

        return [
            'id' => $offer->id,
            'tracking_number' => $offer->tracking_number ?? ('OFR-' . $offer->id),
            'status' => $offer->status,
            'status_label' => $this->offerStatusLabel($offer),
            'order_type' => $offer->order_type,
            'origin' => $offer->origin,
            'destination' => $offer->destination,
            'weight' => $offer->weight,
            'required_truck_type' => $offer->required_truck_type,
            'company' => $offer->company ? [
                'id' => $offer->company->id,
                'name' => $offer->company->name,
                'phone' => $offer->company->phone,
            ] : null,
            'eligible_drivers_count' => $eligibleDriversCount,
            'matching_round' => $offer->matching_round,
            'matching_rounds' => $rounds,
            'financial' => [
                'price_to_client' => $offer->price_to_client,
                'price_to_driver' => $offer->price_to_driver,
            ],
            'cancellation' => $offer->status === 'cancelled' ? [
                'reason' => $offer->cancellation_reason,
                'cancelled_by' => $offer->cancelledBy->name ?? null,
                'cancelled_at' => optional($offer->cancelled_at)->toIso8601String(),
            ] : null,
            'created_at' => optional($offer->created_at)->toIso8601String(),
        ];
    }

    private function shipmentStatusGroup(Shipment $shipment): string
    {
        return match ((int) $shipment->status) {
            1, 2 => 'active',
            3 => 'delivered',
            4 => 'cancelled',
            default => 'pending',
        };
    }

    private function shipmentStatusLabel(Shipment $shipment): string
    {
        return match ((int) $shipment->status) {
            3 => 'DELIVERED',
            4 => 'CANCELLED',
            0 => 'PENDING',
            default => strtoupper(Shipment::stageLabelsFor($shipment->order_type ?? 'internal')[$shipment->current_stage] ?? 'IN TRANSIT'),
        };
    }

    private function offerStatusLabel(ShipmentOffer $offer): string
    {
        return match ($offer->status) {
            'pending' => 'MATCHING',
            ShipmentOffer::STATUS_AWAITING_MANUAL_PRICE => 'AWAITING PRICE',
            'escalated' => 'ESCALATED',
            'cancelled' => 'CANCELLED',
            default => strtoupper($offer->status),
        };
    }
}
