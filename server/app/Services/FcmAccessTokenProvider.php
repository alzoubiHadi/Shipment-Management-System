<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

/**
 * Mints short-lived OAuth2 access tokens for the FCM HTTP v1 API by
 * signing a JWT with the Firebase service account's private key (RS256,
 * via PHP's built-in openssl extension) and exchanging it at Google's
 * token endpoint. Deliberately avoids firebase-admin / google/apiclient —
 * no Composer package could be verified-installable in the sandbox this
 * project was built in, and the whole JWT-bearer flow only needs
 * `openssl_sign()` (core PHP) plus one HTTP POST.
 */
class FcmAccessTokenProvider
{
    private const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';
    private const TOKEN_URL = 'https://oauth2.googleapis.com/token';
    private const CACHE_KEY_PREFIX = 'fcm_v1_access_token:';

    /**
     * Returns ['project_id' => ..., 'access_token' => ...] or null if the
     * service account file isn't present/valid — callers should treat
     * that as "FCM not configured yet" and no-op silently, exactly like
     * before Firebase was set up.
     */
    public function getProjectAndToken(): ?array
    {
        $credentials = $this->loadCredentials();

        if (! $credentials) {
            return null;
        }

        $cacheKey = self::CACHE_KEY_PREFIX . $credentials['project_id'];

        // Access tokens are valid for 3600s; cache for a bit less so we
        // never hand out one that expires mid-request.
        $token = Cache::remember($cacheKey, 3000, fn () => $this->mintAccessToken($credentials));

        if (! $token) {
            return null;
        }

        return ['project_id' => $credentials['project_id'], 'access_token' => $token];
    }

    private function loadCredentials(): ?array
    {
        $path = config('services.fcm.credentials_path');

        if (! $path || ! is_file($path)) {
            return null;
        }

        $decoded = json_decode((string) file_get_contents($path), true);

        if (
            ! is_array($decoded)
            || empty($decoded['client_email'])
            || empty($decoded['private_key'])
            || empty($decoded['project_id'])
        ) {
            return null;
        }

        return $decoded;
    }

    private function mintAccessToken(array $credentials): ?string
    {
        $now = time();

        $header = ['alg' => 'RS256', 'typ' => 'JWT'];
        $claims = [
            'iss' => $credentials['client_email'],
            'scope' => self::SCOPE,
            'aud' => self::TOKEN_URL,
            'iat' => $now,
            'exp' => $now + 3600,
        ];

        $signingInput = $this->base64UrlEncode(json_encode($header))
            . '.' . $this->base64UrlEncode(json_encode($claims));

        $signature = '';
        $signed = openssl_sign($signingInput, $signature, $credentials['private_key'], 'SHA256');

        if (! $signed) {
            return null;
        }

        $jwt = $signingInput . '.' . $this->base64UrlEncode($signature);

        $response = Http::asForm()->post(self::TOKEN_URL, [
            'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
            'assertion' => $jwt,
        ]);

        if (! $response->successful()) {
            return null;
        }

        return $response->json('access_token');
    }

    private function base64UrlEncode(string $data): string
    {
        return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
    }
}
