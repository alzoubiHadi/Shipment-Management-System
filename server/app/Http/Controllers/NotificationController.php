<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

/**
 * In-app notification center — always populated regardless of whether
 * real FCM push is configured (see App\Notifications\Channels\FcmChannel).
 * This is what the Flutter app should poll/display as a fallback (and
 * primary source of truth) for every notification event in the spec.
 */
class NotificationController extends Controller
{
    public function index(Request $request)
    {
        $notifications = $request->user()
            ->notifications()
            ->orderByDesc('created_at')
            ->limit(100)
            ->get();

        return response()->json([
            'message' => 'Notifications retrieved successfully',
            'unread_count' => $request->user()->unreadNotifications()->count(),
            'notifications' => $notifications,
        ], 200);
    }

    public function markRead(Request $request, string $id)
    {
        $notification = $request->user()->notifications()->where('id', $id)->first();

        if (! $notification) {
            return response()->json(['message' => 'Notification not found'], 404);
        }

        $notification->markAsRead();

        return response()->json(['message' => 'Notification marked as read'], 200);
    }

    public function markAllRead(Request $request)
    {
        $request->user()->unreadNotifications->markAsRead();

        return response()->json(['message' => 'All notifications marked as read'], 200);
    }

    /**
     * Registers/updates this device's FCM token, called by the Flutter app
     * right after login (see PushNotificationSetup.initialize(), wired in
     * HomeScreen.initState()).
     */
    public function updateFcmToken(Request $request)
    {
        $validated = $request->validate([
            'fcm_token' => ['required', 'string'],
        ]);

        $request->user()->update(['fcm_token' => $validated['fcm_token']]);

        return response()->json(['message' => 'Device token registered'], 200);
    }
}
