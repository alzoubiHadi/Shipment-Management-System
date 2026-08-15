<?php

return [

    /*
    |--------------------------------------------------------------------------
    | Third Party Services
    |--------------------------------------------------------------------------
    |
    | This file is for storing the credentials for third party services such
    | as Mailgun, Postmark, AWS and more. This file provides the de facto
    | location for this type of information, allowing packages to have
    | a conventional file to locate the various service credentials.
    |
    */

    'postmark' => [
        'key' => env('POSTMARK_API_KEY'),
    ],

    'resend' => [
        'key' => env('RESEND_API_KEY'),
    ],

    'ses' => [
        'key' => env('AWS_ACCESS_KEY_ID'),
        'secret' => env('AWS_SECRET_ACCESS_KEY'),
        'region' => env('AWS_DEFAULT_REGION', 'us-east-1'),
    ],

    'slack' => [
        'notifications' => [
            'bot_user_oauth_token' => env('SLACK_BOT_USER_OAUTH_TOKEN'),
            'channel' => env('SLACK_BOT_USER_DEFAULT_CHANNEL'),
        ],
    ],

    /*
    | Firebase Cloud Messaging — HTTP v1 API. Google fully shut down the
    | old legacy server-key HTTP API in mid-2024, so this project uses the
    | current OAuth2-based v1 endpoint instead (see
    | App\Services\FcmAccessTokenProvider). Requires a service account
    | JSON downloaded from Firebase Console -> Project Settings -> Service
    | Accounts -> Generate new private key, saved to the path below
    | (gitignored — never commit this file). Push silently no-ops wherever
    | the file is missing, so the app keeps working fully via the in-app
    | notifications list before Firebase is configured.
    */
    'fcm' => [
        'credentials_path' => env('FIREBASE_CREDENTIALS_PATH', storage_path('app/firebase-service-account.json')),
    ],

];
