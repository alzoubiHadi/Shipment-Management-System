<?php

namespace App\Notifications\Channels;

use App\Services\FcmAccessTokenProvider;
use Illuminate\Notifications\Notification;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Firebase Cloud Messaging sender using the current HTTP v1 API. The
 * project originally used the legacy server-key HTTP API, but Google
 * fully shut that down in mid-2024 — this now signs its own OAuth2 token
 * via App\Services\FcmAccessTokenProvider instead. Requires:
 *   1. A service account JSON from Firebase Console -> Project Settings
 *      -> Service Accounts -> Generate new private key, saved to the path
 *      configured by FIREBASE_CREDENTIALS_PATH in .env (default:
 *      storage/app/firebase-service-account.json).
 *   2. The notifiable user having a users.fcm_token, registered by the
 *      Flutter app after login via firebase_messaging.
 *
 * Silently no-ops (logs a debug line, never throws) when either is
 * missing, so the rest of the notification flow — the database record
 * every notification always gets — keeps working without Firebase set up.
 */
class FcmChannel
{
    public function send(object $notifiable, Notification $notification): void
    {
        $token = $notifiable->fcm_token ?? null;

        if (! $token) {
            Log::debug('FCM push skipped (no device token)', [
                'notifiable_id' => $notifiable->id ?? null,
                'notification' => get_class($notification),
            ]);
            return;
        }

        if (! method_exists($notification, 'toFcm')) {
            return;
        }

        $auth = app(FcmAccessTokenProvider::class)->getProjectAndToken();

        if (! $auth) {
            Log::debug('FCM push skipped (Firebase not configured — no valid service account file)', [
                'notifiable_id' => $notifiable->id ?? null,
            ]);
            return;
        }

        $payload = $notification->toFcm($notifiable);

        // FCM v1 requires every "data" value to be a string.
        $data = array_map('strval', $payload['data'] ?? []);

        try {
            $response = Http::withToken($auth['access_token'])
                ->post("https://fcm.googleapis.com/v1/projects/{$auth['project_id']}/messages:send", [
                    'message' => [
                        'token' => $token,
                        'notification' => [
                            'title' => $payload['title'] ?? '',
                            'body' => $payload['body'] ?? '',
                        ],
                        'data' => $data,
                    ],
                ]);

            if (! $response->successful()) {
                Log::warning('FCM push rejected by Google', [
                    'status' => $response->status(),
                    'body' => $response->body(),
                ]);
            }
        } catch (\Throwable $e) {
            // Never let a push-delivery failure break the request that
            // triggered it (offer creation, matching, etc.).
            Log::warning('FCM push failed: ' . $e->getMessage());
        }
    }
}
