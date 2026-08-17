<?php

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'permission' => \App\Http\Middleware\EnsureHasPermission::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        //
    })
    ->withSchedule(function (Schedule $schedule): void {
        // UC-16: re-match or escalate any offer whose round timed out.
        // Needs a real cron entry (`* * * * * php artisan schedule:run`) in
        // production, or `php artisan schedule:work` while developing.
        $schedule->command('offers:process-expired-matches')->everyMinute();

        // Unified Approvals / document-expiry feature (2026-08-22): daily
        // sweep of every driver/truck/company document's expiry status —
        // updates Valid/Expiring Soon/Expired, sends the 30/15/7/1-day
        // notifications, and recomputes compliance_status for anyone whose
        // critical document just expired in place (no renewal submitted).
        $schedule->command('documents:check-expiry')->daily();
    })
    ->create();
