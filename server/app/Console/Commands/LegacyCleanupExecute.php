<?php

namespace App\Console\Commands;

use App\Models\Company;
use App\Models\CompanyDocument;
use App\Models\Driver;
use App\Models\DriverDocument;
use App\Models\Truck;
use App\Models\User;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;

/**
 * 2026-08-23: Phase 2 of the approved legacy-data-cleanup plan (see
 * data:audit-driver-truck-legacy + data:audit-legacy-cleanup-details for the
 * Phase 1 findings this executes against). Safe by default — runs as a
 * DRY RUN unless --confirm is passed, so `php artisan data:legacy-cleanup-execute`
 * alone never writes anything.
 *
 * Exactly four kinds of change, all pre-approved:
 *   A. Fix ONE mismatched User.type (id 39: 'company' -> 'driver') — this
 *      user has no Company row at all and IS driver #12's real login; this
 *      single fix is also what explains the Drivers(13)/Users[driver](12)
 *      and Companies(3)/Users[company](4) count mismatches from Phase 1.
 *   B. Soft-delete driver #1 ("driver1") and its linked user (#26) —
 *      rejected, no truck, zero activity anywhere (verified in Phase 1's
 *      per-driver dependent-row check). Reversible via the existing
 *      Deleted Drivers recycle-bin screen. Makes Drivers=Trucks=12.
 *   C. Restore any file that's genuinely missing on disk but already has a
 *      path recorded in the DB — written back to that EXACT existing path,
 *      never a new/fake one. Covers every DriverDocument/CompanyDocument
 *      row and every non-empty Truck.*_file_path column.
 *   D. Backfill a placeholder file (+ a freshly generated path) ONLY for
 *      the two fields Phase 1 confirmed the current code actually treats
 *      as required-in-practice: Truck.license_file_path and
 *      Company.license_file_path. Insurance/technical-inspection files and
 *      every *_expiry date are deliberately left untouched — the running
 *      code (Truck::isRoadworthy(), ComplianceService) already treats a
 *      null expiry/optional file as fine, and Phase 1 found zero drivers
 *      with an actually-missing required document DATE to backfill, so no
 *      expiry values are invented anywhere by this command.
 *
 * Placeholder assets ship in resources/placeholders/ (blank.jpg /
 * blank.pdf) — a clearly-labeled blank page, matched to whichever
 * extension the target path already uses (or .jpg for a brand new path).
 * (Not storage/app/ — that tree's .gitignore excludes everything except
 * private/public, so a bundled asset needed by this command has to live
 * outside it to actually ship with the repo.)
 * No Shipment/ShipmentOffer/FinancialTransaction/pricing table is touched
 * anywhere in this file.
 */
class LegacyCleanupExecute extends Command
{
    protected $signature = 'data:legacy-cleanup-execute {--confirm : actually write changes; omit for a dry run}';

    protected $description = 'Phase 2 of the approved legacy-data cleanup (dry-run unless --confirm).';

    private bool $confirm = false;

    public function handle(): int
    {
        $this->confirm = (bool) $this->option('confirm');

        $this->info($this->confirm ? '=== LEGACY CLEANUP — EXECUTING ===' : '=== LEGACY CLEANUP — DRY RUN (pass --confirm to write) ===');

        DB::transaction(function () {
            $this->fixMismatchedUserType();
            $this->deleteDriverOne();
        });

        $this->restoreMissingOnDiskFiles();
        $this->backfillRequiredFiles();

        $this->newLine();
        $this->info($this->confirm ? '=== DONE — changes written ===' : '=== DRY RUN COMPLETE — nothing was written ===');

        return self::SUCCESS;
    }

    private function section(string $title): void
    {
        $this->newLine();
        $this->line("<fg=yellow;options=bold>{$title}</>");
    }

    // ---- A. Fix the one mismatched User.type -----------------------------

    private function fixMismatchedUserType(): void
    {
        $this->section('A. Fix mismatched User.type (id 39: company -> driver)');

        $user = User::find(39);

        if (! $user) {
            $this->line('  user #39 not found — already handled or IDs changed, skipping.');

            return;
        }

        if ($user->email !== 'mohammed.alzoubi@albatrans.ae') {
            $this->warn("  user #39's email is now '{$user->email}', not the expected mohammed.alzoubi@albatrans.ae — skipping to be safe.");

            return;
        }

        if ($user->type === 'driver') {
            $this->line('  user #39 is already type=driver — nothing to do.');

            return;
        }

        $this->line("  user #39 ({$user->email}): type '{$user->type}' -> 'driver'" . ($this->confirm ? '' : '  [dry run]'));

        if ($this->confirm) {
            $user->update(['type' => 'driver']);
        }
    }

    // ---- B. Delete driver #1 + its user -----------------------------------

    private function deleteDriverOne(): void
    {
        $this->section("B. Soft-delete driver #1 (\"driver1\") + user #26");

        $driver = Driver::find(1);

        if (! $driver) {
            $this->line('  driver #1 not found — already deleted, skipping.');
        } elseif ($driver->name !== 'driver1' || $driver->approval_status !== 'rejected') {
            $this->warn("  driver #1 no longer matches the expected state (name='{$driver->name}', approval_status='{$driver->approval_status}') — skipping to be safe.");
        } elseif ($driver->trashed()) {
            $this->line('  driver #1 already soft-deleted — nothing to do.');
        } else {
            $this->line('  soft-deleting driver #1' . ($this->confirm ? '' : '  [dry run]'));
            if ($this->confirm) {
                $driver->delete();
            }
        }

        $user = User::find(26);

        if (! $user) {
            $this->line('  user #26 not found — already deleted, skipping.');
        } elseif ($user->email !== 'info@albatrans.ae') {
            $this->warn("  user #26's email is now '{$user->email}', not the expected info@albatrans.ae — skipping to be safe.");
        } elseif ($user->trashed()) {
            $this->line('  user #26 already soft-deleted — nothing to do.');
        } else {
            $this->line('  soft-deleting user #26' . ($this->confirm ? '' : '  [dry run]'));
            if ($this->confirm) {
                $user->delete();
            }
        }
    }

    // ---- C. Restore files that have a path but are missing on disk -------

    private function restoreMissingOnDiskFiles(): void
    {
        $this->section('C. Restore files missing on disk (written back to their EXISTING recorded path)');

        $restored = 0;

        foreach (DriverDocument::all() as $doc) {
            $restored += $this->restoreIfMissing($doc->file_path, "DriverDocument #{$doc->id} (driver #{$doc->driver_id}, {$doc->type})");
        }

        foreach (CompanyDocument::all() as $doc) {
            $restored += $this->restoreIfMissing($doc->file_path, "CompanyDocument #{$doc->id} (company #{$doc->company_id}, {$doc->type})");
        }

        foreach (Truck::all() as $truck) {
            foreach (['license_file_path', 'insurance_file_path', 'technical_inspection_file_path'] as $col) {
                $restored += $this->restoreIfMissing($truck->{$col}, "Truck #{$truck->id} ({$truck->truck_number}).{$col}");
            }
        }

        if ($restored === 0) {
            $this->line('  nothing to restore.');
        }
    }

    private function restoreIfMissing(?string $path, string $label): int
    {
        if (empty($path)) {
            return 0;
        }

        if (Storage::disk('local')->exists($path)) {
            return 0;
        }

        $this->line("  restoring {$label} -> '{$path}'" . ($this->confirm ? '' : '  [dry run]'));

        if ($this->confirm) {
            Storage::disk('local')->put($path, $this->placeholderBytesFor($path));
        }

        return 1;
    }

    // ---- D. Backfill a brand-new placeholder + path for the two fields ---
    // ---- Phase 1 confirmed the running code actually requires ------------

    private function backfillRequiredFiles(): void
    {
        $this->section('D. Backfill placeholder + new path for empty REQUIRED fields (truck/company license only)');

        $created = 0;

        foreach (Truck::all() as $truck) {
            if (! empty($truck->license_file_path)) {
                continue;
            }
            $path = 'truck_licenses/' . Str::random(40) . '.jpg';
            $this->line("  Truck #{$truck->id} ({$truck->truck_number}): license_file_path empty -> '{$path}'" . ($this->confirm ? '' : '  [dry run]'));
            if ($this->confirm) {
                Storage::disk('local')->put($path, $this->placeholderBytesFor($path));
                $truck->update(['license_file_path' => $path]);
            }
            $created++;
        }

        foreach (Company::all() as $company) {
            if (! empty($company->license_file_path)) {
                continue;
            }
            $path = 'company_licenses/' . Str::random(40) . '.jpg';
            $this->line("  Company #{$company->id} ({$company->name}): license_file_path empty -> '{$path}'" . ($this->confirm ? '' : '  [dry run]'));
            if ($this->confirm) {
                Storage::disk('local')->put($path, $this->placeholderBytesFor($path));
                $company->update(['license_file_path' => $path]);
            }
            $created++;
        }

        if ($created === 0) {
            $this->line('  nothing to backfill.');
        }
    }

    // ---- Shared placeholder asset loader -----------------------------------

    private function placeholderBytesFor(string $path): string
    {
        $isPdf = str_ends_with(strtolower($path), '.pdf');
        $asset = resource_path('placeholders/' . ($isPdf ? 'blank.pdf' : 'blank.jpg'));

        return file_get_contents($asset);
    }
}
