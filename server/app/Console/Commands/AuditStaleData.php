<?php

namespace App\Console\Commands;

use App\Models\Company;
use App\Models\CompanyDocument;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\DriverDocument;
use App\Models\ProfileEditRequest;
use App\Models\Shipment;
use App\Models\ShipmentOffer;
use App\Models\Truck;
use App\Models\TruckDocument;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

/**
 * 2026-08-28 (data cleanup request): READ-ONLY audit. Reports two kinds of
 * suspect rows left over from earlier, incompatible app versions —
 *   1. Orphaned rows: a foreign key that points at a parent row which no
 *      longer exists (e.g. a Driver whose user_id doesn't match any User).
 *   2. Incomplete rows: a Driver/Company that exists but is missing fields
 *      the CURRENT app version requires at registration time (e.g.
 *      license_expiry), meaning it was almost certainly created by an old
 *      build before that field was mandatory, or by manual/seed testing.
 *
 * This command makes NO changes — it only counts and lists candidates so a
 * human can review before anything is deleted. Driver/Company already use
 * SoftDeletes (see their model docblocks), so once a list of IDs is
 * confirmed, removing them is a reversible ->delete() (recoverable from the
 * existing "Deleted Drivers"/"Deleted Companies" recycle-bin screens), not a
 * permanent ->forceDelete(). Orphan rows in child tables (documents,
 * destinations, trucks...) have no such recycle bin, so those are listed
 * for manual review rather than auto-deleted by this command.
 *
 * Usage: php artisan data:audit
 */
class AuditStaleData extends Command
{
    protected $signature = 'data:audit';

    protected $description = 'Read-only report of orphaned and incomplete driver/company/shipment data (no deletions)';

    private const SAMPLE_LIMIT = 15;

    public function handle(): int
    {
        $this->info('=== DATA AUDIT (read-only — nothing is changed by this command) ===');
        $this->newLine();

        $this->section('A. ORPHANED ROWS (foreign key points at a parent that no longer exists)');

        $this->checkOrphans(
            'Drivers whose user_id has no matching User',
            Driver::withTrashed()->whereNotIn('user_id', User::withTrashed()->pluck('id')),
            fn ($d) => "driver #{$d->id}  name={$d->name}  user_id={$d->user_id}"
        );

        $this->checkOrphans(
            'Companies whose user_id has no matching User',
            Company::withTrashed()->whereNotIn('user_id', User::withTrashed()->pluck('id')),
            fn ($c) => "company #{$c->id}  name={$c->name}  user_id={$c->user_id}"
        );

        $this->checkOrphans(
            "Users of type 'driver' with no matching Driver row",
            User::withTrashed()->where('type', 'driver')->whereNotIn('id', Driver::withTrashed()->pluck('user_id')->filter()),
            fn ($u) => "user #{$u->id}  email={$u->email}"
        );

        $this->checkOrphans(
            "Users of type 'company' with no matching Company row",
            User::withTrashed()->where('type', 'company')->whereNotIn('id', Company::withTrashed()->pluck('user_id')->filter()),
            fn ($u) => "user #{$u->id}  email={$u->email}"
        );

        $this->checkOrphans(
            'Trucks whose default_driver_id has no matching Driver',
            Truck::whereNotIn('default_driver_id', Driver::withTrashed()->pluck('id')),
            fn ($t) => "truck #{$t->id}  truck_number={$t->truck_number}  default_driver_id={$t->default_driver_id}"
        );

        $this->checkOrphans(
            'DriverDocuments whose driver_id has no matching Driver',
            DriverDocument::whereNotIn('driver_id', Driver::withTrashed()->pluck('id')),
            fn ($d) => "driver_document #{$d->id}  driver_id={$d->driver_id}  type={$d->type}"
        );

        $this->checkOrphans(
            'TruckDocuments whose truck_id has no matching Truck',
            TruckDocument::whereNotIn('truck_id', Truck::pluck('id')),
            fn ($d) => "truck_document #{$d->id}  truck_id={$d->truck_id}"
        );

        $this->checkOrphans(
            'CompanyDocuments whose company_id has no matching Company',
            CompanyDocument::whereNotIn('company_id', Company::withTrashed()->pluck('id')),
            fn ($d) => "company_document #{$d->id}  company_id={$d->company_id}"
        );

        $this->checkOrphans(
            'DriverDestinations whose driver_id has no matching Driver',
            DriverDestination::whereNotIn('driver_id', Driver::withTrashed()->pluck('id')),
            fn ($d) => "driver_destination #{$d->id}  driver_id={$d->driver_id}  destination={$d->destination}"
        );

        $this->checkOrphans(
            'ProfileEditRequests whose user_id has no matching User',
            ProfileEditRequest::whereNotIn('user_id', User::withTrashed()->pluck('id')),
            fn ($r) => "profile_edit_request #{$r->id}  user_id={$r->user_id}  category={$r->category}"
        );

        $this->checkOrphans(
            'Shipments with a driver_id set that has no matching Driver',
            Shipment::whereNotNull('driver_id')->whereNotIn('driver_id', Driver::withTrashed()->pluck('id')),
            fn ($s) => "shipment #{$s->id}  tracking={$s->tracking_number}  driver_id={$s->driver_id}"
        );

        $this->checkOrphans(
            'Shipments whose company_id has no matching Company',
            Shipment::whereNotIn('company_id', Company::withTrashed()->pluck('id')),
            fn ($s) => "shipment #{$s->id}  tracking={$s->tracking_number}  company_id={$s->company_id}"
        );

        $this->checkOrphans(
            'ShipmentOffers whose company_id has no matching Company',
            ShipmentOffer::whereNotIn('company_id', Company::withTrashed()->pluck('id')),
            fn ($o) => "shipment_offer #{$o->id}  company_id={$o->company_id}"
        );

        $this->newLine();
        $this->section('B. INCOMPLETE ROWS (exist, but missing fields the current app requires at registration)');

        $this->checkOrphans(
            'Drivers missing core registration fields (license/phone/nationality/age)',
            Driver::withTrashed()->where(function ($q) {
                $q->whereNull('driver_license')->orWhereNull('phone')
                  ->orWhereNull('nationality')->orWhereNull('age');
            }),
            fn ($d) => "driver #{$d->id}  name={$d->name}  license=" . ($d->driver_license ?? 'NULL')
                . "  phone=" . ($d->phone ?? 'NULL') . "  nationality=" . ($d->nationality ?? 'NULL') . "  age=" . ($d->age ?? 'NULL')
        );

        $this->checkOrphans(
            'Drivers missing mandatory document-expiry dates (license/passport/residency)',
            Driver::withTrashed()->where(function ($q) {
                $q->whereNull('license_expiry')->orWhereNull('passport_expiry')->orWhereNull('residency_expiry');
            }),
            fn ($d) => "driver #{$d->id}  name={$d->name}  approval_status={$d->approval_status}"
                . "  license_expiry=" . ($d->license_expiry ?? 'NULL')
                . "  passport_expiry=" . ($d->passport_expiry ?? 'NULL')
                . "  residency_expiry=" . ($d->residency_expiry ?? 'NULL')
        );

        $this->checkOrphans(
            'Companies missing core fields (name/email/phone)',
            Company::withTrashed()->where(function ($q) {
                $q->whereNull('name')->orWhereNull('email')->orWhereNull('phone');
            }),
            fn ($c) => "company #{$c->id}  name=" . ($c->name ?? 'NULL') . "  email=" . ($c->email ?? 'NULL') . "  phone=" . ($c->phone ?? 'NULL')
        );

        $this->checkOrphans(
            'Shipments missing tracking_number/origin/destination',
            Shipment::where(function ($q) {
                $q->whereNull('tracking_number')->orWhere('tracking_number', '')
                  ->orWhereNull('origin')->orWhere('origin', '')
                  ->orWhereNull('destination')->orWhere('destination', '');
            }),
            fn ($s) => "shipment #{$s->id}  tracking=" . ($s->tracking_number ?: 'EMPTY')
                . "  origin=" . ($s->origin ?: 'EMPTY') . "  destination=" . ($s->destination ?: 'EMPTY')
        );

        $this->newLine();
        $this->info('=== END OF AUDIT — no data was changed. Share this output to decide what is safe to remove. ===');

        return self::SUCCESS;
    }

    private function section(string $title): void
    {
        $this->newLine();
        $this->line("<fg=cyan;options=bold>{$title}</>");
        $this->line(str_repeat('-', strlen($title)));
    }

    /**
     * @param \Illuminate\Database\Eloquent\Builder $query
     * @param callable $formatter
     */
    private function checkOrphans(string $label, $query, callable $formatter): void
    {
        $count = (clone $query)->count();

        if ($count === 0) {
            $this->line("  [OK] {$label}: 0");
            return;
        }

        $this->warn("  [FOUND] {$label}: {$count}");

        $sample = (clone $query)->limit(self::SAMPLE_LIMIT)->get();
        foreach ($sample as $row) {
            $this->line('      - ' . $formatter($row));
        }
        if ($count > self::SAMPLE_LIMIT) {
            $this->line('      ... and ' . ($count - self::SAMPLE_LIMIT) . ' more');
        }
    }
}
