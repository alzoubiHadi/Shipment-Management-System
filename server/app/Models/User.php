<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\SoftDeletes;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    /** @use HasFactory<\Database\Factories\UserFactory> */
    use HasFactory, Notifiable,SoftDeletes,HasApiTokens;

    /**
     * The attributes that are mass assignable.
     *
     * @var list<string>
     */
    protected $fillable = [
        'name',
        'email',
        'password',
        'type',
        'must_change_password',
        'is_suspended',
        'otp_code',
        'otp_expires_at',
        'fcm_token',
        'avatar_path',
    ];

    /**
     * The attributes that should be hidden for serialization.
     *
     * @var list<string>
     */
    protected $hidden = [
        'password',
        'remember_token',
        'otp_code',
        'otp_expires_at',
    ];

    /**
     * Get the attributes that should be cast.
     *
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
            'must_change_password' => 'boolean',
            'is_suspended' => 'boolean',
            'otp_expires_at' => 'datetime',
        ];
    }

    /**
     * Case-insensitivity fix (2026-08-25): Postgres text comparison is
     * case-sensitive by default, so "User@Example.com" and
     * "user@example.com" used to be treated as two different emails —
     * different rows could exist for both, and a user typing their email
     * with different capitalization than they registered with would fail
     * to log in. This mutator normalizes every write (User::create(),
     * ->update(), $user->email = ...) to lowercase+trimmed, so storage is
     * always consistent from here on. See the accompanying migration for
     * the one-time backfill of existing rows, and normalizeEmail() below
     * for callers that need to normalize a search value the same way
     * (lookups don't pass through this mutator, only writes do).
     */
    protected function setEmailAttribute(?string $value): void
    {
        $this->attributes['email'] = $value === null ? null : strtolower(trim($value));
    }

    /**
     * Same normalization as the mutator above, exposed for callers that
     * need to normalize a raw search value BEFORE it's used in a
     * where('email', ...) lookup or a `unique:users,email` validation rule
     * — neither of those passes through setEmailAttribute(), since that
     * only fires on Eloquent writes.
     */
    public static function normalizeEmail(?string $email): ?string
    {
        return $email === null ? null : strtolower(trim($email));
    }

    public function driver()
    {
        return $this->hasOne(Driver::class);
    }

    public function company()
    {
        return $this->hasOne(Company::class);
    }

    /**
     * Composable admin permission groups (see permissions/permission_user
     * tables). A single sub-admin account can hold several of these at
     * once, e.g. finance + trainer.
     */
    public function permissions()
    {
        return $this->belongsToMany(Permission::class);
    }

    /**
     * Super Admin implicitly has every permission and is never expected to
     * have rows in permission_user. type='admin' is kept as an accepted
     * alias for backward compatibility with data created before the
     * super_admin/sub_admin split.
     */
    public function isSuperAdmin(): bool
    {
        return in_array($this->type, ['super_admin', 'admin'], true);
    }

    public function isSubAdmin(): bool
    {
        return $this->type === 'sub_admin';
    }

    public function hasPermission(string $key): bool
    {
        if ($this->isSuperAdmin()) {
            return true;
        }

        if (! $this->isSubAdmin()) {
            return false;
        }

        return $this->permissions()->where('key', $key)->exists();
    }
}
