<?php

namespace App\Jobs;

use App\Models\User;
use App\Services\PushNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;

class SendPushNotificationJob implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    public int $tries = 3;
    public int $backoff = 30;

    public function __construct(
        protected int $userId,
        protected string $title,
        protected string $body,
        protected array $data = []
    ) {}

    public function handle(PushNotificationService $pushService): void
    {
        $user = User::find($this->userId);

        if (!$user) {
            Log::warning("SendPushNotificationJob: User {$this->userId} not found");
            return;
        }

        $pushService->sendToUser($user, $this->title, $this->body, $this->data);
    }

    public function failed(\Throwable $exception): void
    {
        Log::error("SendPushNotificationJob failed for user {$this->userId}: " . $exception->getMessage());
    }
}
