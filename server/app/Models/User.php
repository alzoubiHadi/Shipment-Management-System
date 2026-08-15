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
        'otp_code',
        'otp_expires_at',
        'fcm_token',
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
            'otp_expires_at' => 'datetime',
        ];
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
