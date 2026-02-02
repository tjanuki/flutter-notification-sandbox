<?php

namespace App\Providers;

use App\Services\PushNotificationService;
use Illuminate\Support\ServiceProvider;

class PushNotificationServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(PushNotificationService::class, function ($app) {
            return new PushNotificationService();
        });
    }

    public function boot(): void
    {
        //
    }
}
