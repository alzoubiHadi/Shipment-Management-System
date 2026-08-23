<?php

namespace App\Console\Commands;

use App\Models\Company;
use App\Models\CompanyDocument;
use App\Models\ComplianceReport;
use App\Models\Driver;
use App\Models\DriverDestination;
use App\Models\DriverDocument;
use App\Models\DriverRating;
use App\Models\PayoutRequest;
use App\Models\ShipmentOfferDriverResponse;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Console\Command;

/**
 * 2026-08-29: follow-up to data:audit-driver-truck-legacy — that command's
 * counts showed Users(type=driver)=12 vs Drivers=13, and Users(type=company)=4
 * vs Companies=3, and flagged several files as "MISSING ON DISK" without
 * printing the actual stored path (needed to know exactly where a
 * placeholder file must be created). This fills both gaps. Still 100%
 * read-only — no writes anywhere in this file.
 */
class AuditLegacyCleanupDetails extends Command
{
    protected $signature = 'data:audit-legacy-cleanup-details';

    protected $description = 'Read-only follow-up audit: user_id integrity + exact missing file paths.';

    public function handle(): int
    {
        $this->info('=== FOLLOW-UP AUDIT (read-only) ===');

        $this->section('1. Driver.user_id integrity (why Drivers=13 but Users[type=driver]=12)');
        foreach (Driver::withTrashed()->orderBy('id')->get() as $d) {
            $user = $d->user_id ? User::withTrashed()->find($d->user_id) : null;
            $flag = ! $user ? 'BROKEN: no such user'
                : ($user->type !== 'driver' ? "MISMATCH: user type is '{$user->type}', not driver" : 'ok');
            $this->line(sprintf(
                'driver #%d  %-20s user_id=%s  -> %s  [%s]',
                $d->id, $d->name, $d->user_id ?? 'NULL',
                $user ? "{$user->email} (verified=" . ($user->email_verified_at ? 'yes' : 'no') . ', trashed=' . ($user->trashed() ? 'yes' : 'no') . ')' : 'N/A',
                $flag
            ));
        }

        $this->section('2. driver-type Users with NO Driver row at all');
        $driverUserIds = Driver::withTrashed()->pluck('user_id')->filter();
        $orphanDriverUsers = User::where('type', 'driver')->whereNotIn('id', $driverUserIds)->get();
        $this->line('Count: ' . $orphanDriverUsers->count());
        foreach ($orphanDriverUsers as $u) {
            $this->line("  user #{$u->id}  {$u->email}  verified=" . ($u->email_verified_at ? 'yes' : 'no') . "  created={$u->created_at?->toDateString()}");
        }

        $this->section('3. Company.user_id integrity (why Companies=3 but Users[type=company]=4)');
        foreach (Company::withTrashed()->orderBy('id')->get() as $c) {
            $user = $c->user_id ? User::withTrashed()->find($c->user_id) : null;
            $flag = ! $user ? 'BROKEN: no such user'
                : ($user->type !== 'company' ? "MISMATCH: user type is '{$user->type}', not company" : 'ok');
            $this->line(sprintf(
                'company #%d  %-20s user_id=%s  -> %s  [%s]',
                $c->id, $c->name, $c->user_id ?? 'NULL',
                $user ? "{$user->email} (verified=" . ($user->email_verified_at ? 'yes' : 'no') . ', trashed=' . ($user->trashed() ? 'yes' : 'no') . ')' : 'N/A',
                $flag
            ));
        }

        $this->section('4. company-type Users with NO Company row at all');
        $companyUserIds = Company::withTrashed()->pluck('user_id')->filter();
        $orphanCompanyUsers = User::where('type', 'company')->whereNotIn('id', $companyUserIds)->get();
        $this->line('Count: ' . $orphanCompanyUsers->count());
        foreach ($orphanCompanyUsers as $u) {
            $this->line("  user #{$u->id}  {$u->email}  verified=" . ($u->email_verified_at ? 'yes' : 'no') . "  created={$u->created_at?->toDateString()}");
        }

        $this->section('5. Every DriverDocument row (all 17 were reported missing on disk) — exact stored paths');
        foreach (DriverDocument::orderBy('driver_id')->orderBy('type')->get() as $doc) {
            $this->line("  doc #{$doc->id}  driver #{$doc->driver_id}  type={$doc->type}  is_current=" . ($doc->is_current ? 'Y' : 'N') . "  expiry={$doc->expiry_date}  path='{$doc->file_path}'");
        }

        $this->section('6. The one CompanyDocument row — exact stored path');
        foreach (CompanyDocument::get() as $doc) {
            $this->line("  doc #{$doc->id}  company #{$doc->company_id}  type={$doc->type}  is_current=" . ($doc->is_current ? 'Y' : 'N') . "  expiry={$doc->expiry_date}  path='{$doc->file_path}'");
        }

        $this->section('7. Trucks — exact stored path for every non-null file column');
        foreach (Truck::orderBy('id')->get() as $t) {
            $this->line("  truck #{$t->id}  {$t->truck_number}  license_file_path='{$t->license_file_path}'  insurance_file_path='{$t->insurance_file_path}'  technical_inspection_file_path='{$t->technical_inspection_file_path}'");
        }

        $this->section('8. Company #1 — exact stored license_file_path');
        $c1 = Company::find(1);
        if ($c1) {
            $this->line("  company #1  license_file_path='{$c1->license_file_path}'");
        }

        $this->section('9. Driver #1 (delete candidate) — every dependent row, enumerated');
        $d1 = Driver::find(1);
        if ($d1) {
            $this->line('DriverDocument rows: ' . DriverDocument::where('driver_id', 1)->count() . ' (ids: ' . DriverDocument::where('driver_id', 1)->pluck('id')->implode(',') . ')');
            $this->line('DriverDestination rows: ' . DriverDestination::where('driver_id', 1)->count());
            $this->line('ComplianceReport rows: ' . ComplianceReport::where('driver_id', 1)->count());
            $this->line('DriverRating rows: ' . DriverRating::where('driver_id', 1)->count());
            $this->line('PayoutRequest rows: ' . PayoutRequest::where('driver_id', 1)->count());
            $this->line('ShipmentOfferDriverResponse rows: ' . ShipmentOfferDriverResponse::where('driver_id', 1)->count());
            $user1 = $d1->user_id ? User::find($d1->user_id) : null;
            $this->line('Linked user: ' . ($user1 ? "#{$user1->id} {$user1->email}" : 'NONE/broken'));
        } else {
            $this->line('Driver #1 not found (already handled?).');
        }

        $this->newLine();
        $this->info('=== END — no data was changed ===');

        return self::SUCCESS;
    }

    private function section(string $title): void
    {
        $this->newLine();
        $this->line("<fg=yellow;options=bold>{$title}</>");
    }
}
