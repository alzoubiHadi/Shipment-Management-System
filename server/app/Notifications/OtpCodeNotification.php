<?php

namespace App\Notifications;

use Illuminate\Bus\Queueable;
use Illuminate\Notifications\Messages\MailMessage;
use Illuminate\Notifications\Notification;

/**
 * Email OTP sent at self-registration time (UC-4). With MAIL_MAILER=log in
 * the local .env this simply writes the code to storage/logs/laravel.log
 * instead of sending a real email — fine for development, swap the mailer
 * driver for production.
 */
class OtpCodeNotification extends Notification
{
    use Queueable;

    public function __construct(private readonly string $code)
    {
    }

    public function via(object $notifiable): array
    {
        return ['mail'];
    }

    public function toMail(object $notifiable): MailMessage
    {
        return (new MailMessage)
            ->subject('Freight Management System — Email verification code')
            ->line('Your verification code is:')
            ->line("**{$this->code}**")
            ->line('This code expires in 10 minutes.')
            ->line('If you did not request this, you can ignore this email.');
    }
}
