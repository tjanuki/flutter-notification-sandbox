<?php

namespace App\Http\Controllers\Admin;

use App\Events\NotificationSent;
use App\Http\Controllers\Controller;
use App\Jobs\SendPushNotificationJob;
use App\Models\Notification;
use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class NotificationController extends Controller
{
    /**
     * Get all sent notifications (admin view)
     */
    public function index(): JsonResponse
    {
        $notifications = Notification::with('sender')
            ->orderBy('sent_at', 'desc')
            ->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $notifications,
            'message' => 'Notifications retrieved successfully',
        ]);
    }

    /**
     * Get all users (for recipient selection)
     */
    public function getUsers(): JsonResponse
    {
        $users = User::where('is_admin', false)
            ->select('id', 'name', 'email')
            ->orderBy('name')
            ->get();

        return response()->json([
            'success' => true,
            'data' => $users,
            'message' => 'Users retrieved successfully',
        ]);
    }

    /**
     * Send a notification to selected users
     */
    public function send(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'body' => 'required|string|max:5000',
            'user_ids' => 'required|array|min:1',
            'user_ids.*' => 'integer|exists:users,id',
        ]);

        $users = User::whereIn('id', $validated['user_ids'])->get();

        if ($users->isEmpty()) {
            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'No valid users found',
            ], 400);
        }

        DB::beginTransaction();

        try {
            // Create notification record
            $notification = Notification::create([
                'sender_id' => $request->user()->id,
                'title' => $validated['title'],
                'body' => $validated['body'],
                'recipient_ids' => $validated['user_ids'],
                'sent_at' => now(),
            ]);

            $pushData = [
                'notification_id' => (string) $notification->id,
                'type' => 'notification',
            ];

            foreach ($users as $user) {
                // Create user notification record
                UserNotification::create([
                    'user_id' => $user->id,
                    'notification_id' => $notification->id,
                ]);

                // 1. Send via WebSocket (Reverb) - real-time in-app
                broadcast(new NotificationSent(
                    $user->id,
                    $validated['title'],
                    $validated['body'],
                    $notification->id
                ));

                // 2. Queue push notification (FCM) - native push
                SendPushNotificationJob::dispatch(
                    $user->id,
                    $validated['title'],
                    $validated['body'],
                    $pushData
                );
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'data' => [
                    'notification' => $notification,
                    'recipients_count' => $users->count(),
                ],
                'message' => 'Notification sent successfully',
            ]);
        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'Failed to send notification: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Send notification to all non-admin users
     */
    public function sendToAll(Request $request): JsonResponse
    {
        $validated = $request->validate([
            'title' => 'required|string|max:255',
            'body' => 'required|string|max:5000',
        ]);

        $users = User::where('is_admin', false)->get();

        if ($users->isEmpty()) {
            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'No users found',
            ], 400);
        }

        $userIds = $users->pluck('id')->toArray();

        DB::beginTransaction();

        try {
            $notification = Notification::create([
                'sender_id' => $request->user()->id,
                'title' => $validated['title'],
                'body' => $validated['body'],
                'recipient_ids' => $userIds,
                'sent_at' => now(),
            ]);

            $pushData = [
                'notification_id' => (string) $notification->id,
                'type' => 'notification',
            ];

            foreach ($users as $user) {
                UserNotification::create([
                    'user_id' => $user->id,
                    'notification_id' => $notification->id,
                ]);

                broadcast(new NotificationSent(
                    $user->id,
                    $validated['title'],
                    $validated['body'],
                    $notification->id
                ));

                SendPushNotificationJob::dispatch(
                    $user->id,
                    $validated['title'],
                    $validated['body'],
                    $pushData
                );
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'data' => [
                    'notification' => $notification,
                    'recipients_count' => $users->count(),
                ],
                'message' => 'Notification sent to all users',
            ]);
        } catch (\Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'Failed to send notification: ' . $e->getMessage(),
            ], 500);
        }
    }

    /**
     * Get notification details with delivery stats
     */
    public function show(int $id): JsonResponse
    {
        $notification = Notification::with(['sender', 'userNotifications.user'])
            ->find($id);

        if (!$notification) {
            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'Notification not found',
            ], 404);
        }

        $stats = [
            'total_recipients' => $notification->userNotifications->count(),
            'read_count' => $notification->userNotifications->where('read', true)->count(),
            'unread_count' => $notification->userNotifications->where('read', false)->count(),
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'notification' => $notification,
                'stats' => $stats,
            ],
            'message' => 'Notification retrieved successfully',
        ]);
    }

    /**
     * Delete a notification (admin only)
     */
    public function destroy(int $id): JsonResponse
    {
        $notification = Notification::find($id);

        if (!$notification) {
            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'Notification not found',
            ], 404);
        }

        // Delete associated user notifications first
        UserNotification::where('notification_id', $id)->delete();
        $notification->delete();

        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'Notification deleted successfully',
        ]);
    }
}
