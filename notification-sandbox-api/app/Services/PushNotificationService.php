<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Log;
use Kreait\Firebase\Factory;
use Kreait\Firebase\Messaging\CloudMessage;
use Kreait\Firebase\Messaging\Notification;
use Kreait\Firebase\Exception\MessagingException;

class PushNotificationService
{
    protected $messaging;

    public function __construct()
    {
        $credentialsPath = config('firebase.credentials');

        if ($credentialsPath && file_exists($credentialsPath)) {
            $factory = (new Factory)->withServiceAccount($credentialsPath);
            $this->messaging = $factory->createMessaging();
        }
    }

    /**
     * Check if the service is configured and ready
     */
    public function isConfigured(): bool
    {
        return $this->messaging !== null;
    }

    /**
     * Send push notification to a single user
     */
    public function sendToUser(User $user, string $title, string $body, array $data = []): bool
    {
        if (!$this->isConfigured()) {
            Log::warning('PushNotificationService: Firebase not configured, skipping push notification');
            return false;
        }

        if (!$user->fcm_token) {
            Log::info("PushNotificationService: User {$user->id} has no FCM token");
            return false;
        }

        try {
            $message = CloudMessage::withTarget('token', $user->fcm_token)
                ->withNotification(Notification::create($title, $body))
                ->withData($this->normalizeData($data));

            $this->messaging->send($message);

            Log::info("PushNotificationService: Sent notification to user {$user->id}");
            return true;
        } catch (MessagingException $e) {
            $this->handleMessagingException($e, $user);
            return false;
        } catch (\Exception $e) {
            Log::error("PushNotificationService: Error sending to user {$user->id}: " . $e->getMessage());
            return false;
        }
    }

    /**
     * Send push notification to multiple users
     */
    public function sendToMultipleUsers(array $users, string $title, string $body, array $data = []): array
    {
        if (!$this->isConfigured()) {
            Log::warning('PushNotificationService: Firebase not configured, skipping push notifications');
            return ['success' => 0, 'failure' => count($users)];
        }

        $tokens = collect($users)
            ->filter(fn($user) => !empty($user->fcm_token))
            ->pluck('fcm_token')
            ->toArray();

        if (empty($tokens)) {
            Log::info('PushNotificationService: No valid FCM tokens found');
            return ['success' => 0, 'failure' => 0];
        }

        try {
            $message = CloudMessage::new()
                ->withNotification(Notification::create($title, $body))
                ->withData($this->normalizeData($data));

            $report = $this->messaging->sendMulticast($message, $tokens);

            Log::info("PushNotificationService: Multicast sent - success: {$report->successes()->count()}, failure: {$report->failures()->count()}");

            // Handle invalid tokens
            foreach ($report->failures()->getItems() as $failure) {
                $this->handleFailedToken($failure);
            }

            return [
                'success' => $report->successes()->count(),
                'failure' => $report->failures()->count(),
            ];
        } catch (\Exception $e) {
            Log::error('PushNotificationService: Error in multicast: ' . $e->getMessage());
            return ['success' => 0, 'failure' => count($tokens)];
        }
    }

    /**
     * Send to specific FCM tokens directly
     */
    public function sendToTokens(array $tokens, string $title, string $body, array $data = []): array
    {
        if (!$this->isConfigured()) {
            Log::warning('PushNotificationService: Firebase not configured');
            return ['success' => 0, 'failure' => count($tokens)];
        }

        $tokens = array_filter($tokens);

        if (empty($tokens)) {
            return ['success' => 0, 'failure' => 0];
        }

        try {
            $message = CloudMessage::new()
                ->withNotification(Notification::create($title, $body))
                ->withData($this->normalizeData($data));

            $report = $this->messaging->sendMulticast($message, $tokens);

            return [
                'success' => $report->successes()->count(),
                'failure' => $report->failures()->count(),
            ];
        } catch (\Exception $e) {
            Log::error('PushNotificationService: Error sending to tokens: ' . $e->getMessage());
            return ['success' => 0, 'failure' => count($tokens)];
        }
    }

    /**
     * Normalize data payload - FCM requires all values to be strings
     */
    protected function normalizeData(array $data): array
    {
        return collect($data)->map(function ($value) {
            return is_string($value) ? $value : json_encode($value);
        })->toArray();
    }

    /**
     * Handle messaging exceptions and potentially invalidate tokens
     */
    protected function handleMessagingException(MessagingException $e, User $user): void
    {
        $error = $e->getMessage();

        // Check for invalid/expired token errors
        if (str_contains($error, 'UNREGISTERED') ||
            str_contains($error, 'INVALID_ARGUMENT') ||
            str_contains($error, 'not a valid FCM registration token')) {

            Log::warning("PushNotificationService: Invalid FCM token for user {$user->id}, clearing token");

            // Clear the invalid token
            $user->update(['fcm_token' => null]);
        } else {
            Log::error("PushNotificationService: FCM error for user {$user->id}: {$error}");
        }
    }

    /**
     * Handle failed token from multicast
     */
    protected function handleFailedToken($failure): void
    {
        $error = $failure->error()?->getMessage() ?? 'Unknown error';
        $token = $failure->target()?->value() ?? 'unknown';

        Log::warning("PushNotificationService: Failed to send to token: {$error}");

        // If the token is invalid, find and clear it
        if (str_contains($error, 'UNREGISTERED') || str_contains($error, 'INVALID_ARGUMENT')) {
            User::where('fcm_token', $token)->update(['fcm_token' => null]);
        }
    }
}
