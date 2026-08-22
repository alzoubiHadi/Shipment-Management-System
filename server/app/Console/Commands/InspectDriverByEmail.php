<?php

namespace App\Console\Commands;

use App\Models\Driver;
use App\Models\Shipment;
use App\Models\ShipmentOffer;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Console\Command;

/**
 * 2026-08-28 (support request): READ-ONLY — dumps everything about one
 * driver (by login email) so we can find the specific shipment the user
 * says is blocking that driver, before deciding anything is safe to
 * delete. Makes no changes.
 *
 * Usage: php artisan data:inspect-driver alzoubi.0020@gmail.com
 */
class InspectDriverByEmail extends Command
{
    protected $signature = 'data:inspect-driver {email}';

    protected $description = 'Read-only dump of one driver (by email) and every shipment/offer/truck linked to them';

    public function handle(): int
    {
        $email = User::normalizeEmail($this->argument('email'));

        $user = User::withTrashed()->where('email', $email)->first();

        if (! $user) {
            $this->error("No user found with email {$email}");
            return self::FAILURE;
        }

        $this->info('=== USER ===');
        $this->line("id={$user->id}  type={$user->type}  email={$user->email}  is_suspended=" . ($user->is_suspended ? 'true' : 'false'));
        $this->line('email_verified_at=' . ($user->email_verified_at ?? 'NULL') . '  deleted_at=' . ($user->deleted_at ?? 'NULL'));
        $this->newLine();

        $driver = Driver::withTrashed()->where('user_id', $user->id)->first();

        if (! $driver) {
            $this->warn('No Driver row linked to this user_id — this user has no driver profile at all.');
            return self::SUCCESS;
        }

        $this->info('=== DRIVER ===');
        $this->line("driver_id={$driver->id}  name={$driver->name}  approval_status={$driver->approval_status}"
            . "  compliance_status={$driver->compliance_status}  status={$driver->status}  deleted_at=" . ($driver->deleted_at ?? 'NULL'));
        $this->line('license_expiry=' . ($driver->license_expiry ?? 'NULL')
            . '  passport_expiry=' . ($driver->passport_expiry ?? 'NULL')
            . '  residency_expiry=' . ($driver->residency_expiry ?? 'NULL'));
        $this->newLine();

        $truck = Truck::where('default_driver_id', $driver->id)->first();
        $this->info('=== TRUCK ===');
        if ($truck) {
            $this->line("truck_id={$truck->id}  truck_number={$truck->truck_number}  truck_type={$truck->truck_type}"
                . '  is_active=' . ($truck->is_active ? 'true' : 'false') . '  deleted_at=' . ($truck->deleted_at ?? 'NULL'));
        } else {
            $this->line('(none)');
        }
        $this->newLine();

        $shipments = Shipment::where('driver_id', $driver->id)->orderBy('id')->get();
        $this->info("=== SHIPMENTS (driver_id={$driver->id}) — count=" . $shipments->count() . ' ===');
        foreach ($shipments as $s) {
            $this->line("shipment #{$s->id}  tracking={$s->tracking_number}  status={$s->status}  order_type=" . ($s->order_type ?? 'NULL')
                . '  current_stage=' . ($s->current_stage ?? 'NULL') . '  delivery_status=' . ($s->delivery_status ?? 'NULL'));
            $this->line("    company_id={$s->company_id}  truck_id=" . ($s->truck_id ?? 'NULL')
                . '  origin_zone_id=' . ($s->origin_zone_id ?? 'NULL') . '  destination_zone_id=' . ($s->destination_zone_id ?? 'NULL'));
            $this->line("    origin={$s->origin}  destination={$s->destination}  created_at={$s->created_at}");
        }
        $this->newLine();

        $offers = ShipmentOffer::where('accepted_by_driver_id', $driver->id)->orderBy('id')->get();
        $this->info("=== SHIPMENT OFFERS accepted by this driver — count=" . $offers->count() . ' ===');
        foreach ($offers as $o) {
            $this->line("offer #{$o->id}  company_id={$o->company_id}  status={$o->status}  created_at={$o->created_at}");
        }

        return self::SUCCESS;
    }
}
