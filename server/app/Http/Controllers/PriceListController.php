<?php

namespace App\Http\Controllers;

use App\Models\PriceListEntry;
use App\Models\Truck;
use App\Support\Destinations;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

/**
 * Finance Admin: manages the central price matrix (UC-33) via CSV
 * download/edit/upload rather than a manual per-cell UI, per the spec.
 * CSV instead of true .xlsx on purpose — no Excel-writing Composer package
 * (phpoffice/phpspreadsheet) could be installed in the sandbox this was
 * written in (no PHP/Composer runtime available to verify the install).
 * A CSV opens and saves in Excel exactly the same way for this purpose;
 * swap to phpoffice/phpspreadsheet later if a real .xlsx is required.
 */
class PriceListController extends Controller
{
    public function index()
    {
        return response()->json([
            'message' => 'Price list retrieved successfully',
            'entries' => PriceListEntry::orderBy('destination')->orderBy('truck_type')->get(),
        ], 200);
    }

    /**
     * Full grid (every destination x every truck type), pre-filled with
     * whatever prices already exist — so Finance Admin sees exactly which
     * cells are still missing (blank) when they open it in Excel.
     */
    public function export()
    {
        $existing = PriceListEntry::all()->keyBy(fn ($e) => $e->destination . '|' . $e->truck_type);

        $rows = [['destination', 'truck_type', 'base_price']];

        foreach (Destinations::all() as $destination) {
            foreach (Truck::TRUCK_TYPES as $truckType) {
                $key = $destination . '|' . $truckType;
                $rows[] = [$destination, $truckType, $existing->get($key)?->base_price ?? ''];
            }
        }

        $csv = fopen('php://temp', 'r+');
        foreach ($rows as $row) {
            fputcsv($csv, $row);
        }
        rewind($csv);
        $content = stream_get_contents($csv);
        fclose($csv);

        return response($content, 200, [
            'Content-Type' => 'text/csv',
            'Content-Disposition' => 'attachment; filename="price_list.csv"',
        ]);
    }

    /**
     * Upload the edited CSV back. Rows with a blank price are skipped
     * (not deleted — leaving a cell blank just means "still no price for
     * this combo", not "remove it"). Invalid destination/truck_type values
     * are reported back rather than silently ignored.
     */
    public function import(Request $request)
    {
        $request->validate([
            'file' => ['required', 'file', 'mimes:csv,txt', 'max:2048'],
        ]);

        $handle = fopen($request->file('file')->getRealPath(), 'r');
        $header = fgetcsv($handle);

        $updated = 0;
        $skipped = [];
        $rowNumber = 1;

        DB::transaction(function () use ($handle, &$updated, &$skipped, &$rowNumber) {
            while (($row = fgetcsv($handle)) !== false) {
                $rowNumber++;

                if (count($row) < 3) {
                    continue;
                }

                [$destination, $truckType, $basePrice] = array_map('trim', $row);

                if ($basePrice === '') {
                    continue; // still unpriced — leave it out of the table
                }

                if (! in_array($destination, Destinations::all(), true)) {
                    $skipped[] = "Row {$rowNumber}: unknown destination '{$destination}'";
                    continue;
                }

                if (! in_array($truckType, Truck::TRUCK_TYPES, true)) {
                    $skipped[] = "Row {$rowNumber}: unknown truck type '{$truckType}'";
                    continue;
                }

                if (! is_numeric($basePrice)) {
                    $skipped[] = "Row {$rowNumber}: '{$basePrice}' is not a valid price";
                    continue;
                }

                PriceListEntry::updateOrCreate(
                    ['destination' => $destination, 'truck_type' => $truckType],
                    ['base_price' => (float) $basePrice]
                );
                $updated++;
            }
        });

        fclose($handle);

        return response()->json([
            'message' => "Price list updated: {$updated} row(s) saved" . ($skipped ? ', ' . count($skipped) . ' skipped' : ''),
            'updated' => $updated,
            'skipped' => $skipped,
        ], 200);
    }

    public function destinationOptions()
    {
        return response()->json([
            'message' => 'Destination options retrieved successfully',
            'destinations' => Destinations::all(),
        ], 200);
    }
}
