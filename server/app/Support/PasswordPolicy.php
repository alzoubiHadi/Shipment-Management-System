<?php

namespace App\Support;

use Illuminate\Validation\Rules\Password;

/**
 * Single source of truth for the password-strength rule (UC-7): minimum 8
 * characters, upper + lower case, at least one digit, at least one special
 * character. Applied identically to self-registration (UC-2/UC-3) and to
 * the forced password change after a sub-admin's first login (UC-7) and to
 * a driver/company's own password-change flow.
 */
class PasswordPolicy
{
    public static function rules(): Password
    {
        return Password::min(8)->mixedCase()->numbers()->symbols();
    }
}
