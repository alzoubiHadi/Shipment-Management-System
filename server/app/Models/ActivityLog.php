<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

/**
 * Append-only audit trail (NFR/Security: "سجل تدقيق لكل إجراء حساس").
 * Rows are written via ActivityLog::record() from inside controllers right
 * after a sensitive action succeeds — never updated or deleted afterward.
 */
class ActivityLog extends Model
{
    public $timestamps = false; // only created_at, set explicitly below

    protected $fillable = [
        'user_id',
        'user_name',
        'action',
        'subject_type',
        'subject_id',
        'description',
        'meta',
        'created_at',
    ];

    protected $casts = [
        'meta' => 'array',
        'created_at' => 'datetime',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Write one audit entry. Call this right after the sensitive action
     * has actually succeeded (not before), so the log only ever reflects
     * things that really happened.
     *
     * @param  string  $action      e.g. 'company.suspended'
     * @param  mixed   $subject     the model the action was performed on (or null)
     * @param  string  $description human-readable summary, e.g. "Suspended company 'Acme Freight'"
     * @param  array   $meta        optional extra context (reason, old/new values, ...)
     */
    public static function record(string $action, $subject, string $description, array $meta = []): self
    {
        $actor = auth()->user();

        return self::create([
            'user_id' => $actor?->id,
            'user_name' => $actor?->name,
            'action' => $action,
            'subject_type' => $subject ? class_basename($subject) : null,
            'subject_id' => $subject?->id,
            'description' => $description,
            'meta' => $meta ?: null,
            'created_at' => now(),
        ]);
    }
}
