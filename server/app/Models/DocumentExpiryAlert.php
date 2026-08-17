<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Unified Approvals / document-expiry feature (2026-08-22): dedup
 * bookkeeping used only by the CheckDocumentExpiry daily command — see the
 * 2026_08_22_000106 migration's docblock for why this is a generic
 * (subject_type, subject_id, field) key rather than a polymorphic relation.
 */
class DocumentExpiryAlert extends Model
{
    protected $fillable = [
        'subject_type',
        'subject_id',
        'field',
        'last_threshold_days',
    ];

    /**
     * Fetch (or lazily create) the tracking row for one watched field, then
     * update it if $newThreshold is smaller (closer to/past expiry) than
     * whatever was last sent — returns true when a notification should
     * actually go out for $newThreshold, false if it was already sent (or
     * a LARGER threshold than what's already recorded, e.g. the document
     * was renewed and is now valid again further out).
     */
    public static function shouldNotify(string $subjectType, int $subjectId, string $field, ?int $newThreshold): bool
    {
        $row = static::firstOrCreate(
            ['subject_type' => $subjectType, 'subject_id' => $subjectId, 'field' => $field],
            ['last_threshold_days' => null],
        );

        if ($newThreshold === null) {
            // Document is valid again (renewed) — reset so a future
            // re-expiry notifies from scratch.
            if ($row->last_threshold_days !== null) {
                $row->update(['last_threshold_days' => null]);
            }
            return false;
        }

        if ($row->last_threshold_days !== null && $row->last_threshold_days <= $newThreshold) {
            return false;
        }

        $row->update(['last_threshold_days' => $newThreshold]);
        return true;
    }
}
