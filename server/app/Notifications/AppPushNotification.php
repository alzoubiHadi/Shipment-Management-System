<?php

namespace App\Notifications;

use App\Notifications\Channels\FcmChannel;
use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Notification;

/**
 * One generic notification class reused for every push/in-app event in the
 * spec (matched driver, CRM manual-pricing alert, delivery-awaiting
 * confirmation, balance/payout updates, approval-status changes, new
 * compliance reports, ...) instead of a separate class per event — the
 * only thing that varies is the type/title/body/data payload. Always
 * recorded to the database (in-app notification center); also attempts a
 * real push via FcmChannel, which no-ops gracefully if Firebase isn't
 * configured yet (see FcmChannel's docblock).
 */
class AppPushNotification extends Notification
{
    use Queueable;

    public function __construct(
        private readonly string $notificationType,
        private readonly string $title,
        private readonly string $body,
        private readonly array $data = [],
    ) {
    }

    public function via(object $notifiable): array
    {
        return ['database', FcmChannel::class];
    }

    public function toDatabase(object $notifiable): array
    {
        return [
            'notification_type' => $this->notificationType,
            'title' => $this->title,
            'body' => $this->body,
            'data' => $this->data,
        ];
    }

    public function toFcm(object $notifiable): array
    {
        return [
            'title' => $this->title,
            'body' => $this->body,
            'data' => array_merge($this->data, ['type' => $this->notificationType]),
        ];
    }
}
