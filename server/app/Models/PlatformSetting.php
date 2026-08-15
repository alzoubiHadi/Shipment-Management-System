<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class PlatformSetting extends Model
{
    protected $fillable = [
        'key',
        'value',
    ];

    /**
     * Cached read helper — settings are read on nearly every pricing /
     * matching request, so avoid a query each time. Cache is cleared by
     * set() below.
     */
    public static function get(string $key, $default = null)
    {
        return Cache::rememberForever("platform_setting:{$key}", function () use ($key, $default) {
            $row = static::where('key', $key)->first();

            return $row ? $row->value : $default;
        });
    }

    public static function set(string $key, string $value): void
    {
        static::updateOrCreate(['key' => $key], ['value' => $value]);
        Cache::forget("platform_setting:{$key}");
    }
}
