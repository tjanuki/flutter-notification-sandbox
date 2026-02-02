<?php

namespace App\Http\Controllers;

use App\Events\NotificationSent;
use App\Jobs\SendPushNotificationJob;
use App\Models\Notification;
use App\Models\User;
use App\Models\UserNotification;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class NotificationController extends Controller
{
    /**
     * Get notifications for the authenticated user
     */
    public function index(Request $request): JsonResponse
    {
        $notifications = UserNotification::with('notification.sender')
            ->where('user_id', $request->user()->id)
            ->orderBy('created_at', 'desc')
            ->paginate(20);

        return response()->json([
            'success' => true,
            'data' => $notifications,
            'message' => 'Notifications retrieved successfully',
        ]);
    }

    /**
     * Get a single notification
     */
    public function show(Request $request, int $id): JsonResponse
    {
        $userNotification = UserNotification::with('notification.sender')
            ->where('user_id', $request->user()->id)
            ->where('notification_id', $id)
            ->first();

        if (!$userNotification) {
            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'Notification not found',
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => $userNotification,
            'message' => 'Notification retrieved successfully',
        ]);
    }

    /**
     * Mark a notification as read
     */
    public function markAsRead(Request $request, int $id): JsonResponse
    {
        $userNotification = UserNotification::where('user_id', $request->user()->id)
            ->where('notification_id', $id)
            ->first();

        if (!$userNotification) {
            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'Notification not found',
            ], 404);
        }

        $userNotification->update([
            'read' => true,
            'read_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'data' => $userNotification,
            'message' => 'Notification marked as read',
        ]);
    }

    /**
     * Mark all notifications as read
     */
    public function markAllAsRead(Request $request): JsonResponse
    {
        UserNotification::where('user_id', $request->user()->id)
            ->where('read', false)
            ->update([
                'read' => true,
                'read_at' => now(),
            ]);

        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'All notifications marked as read',
        ]);
    }

    /**
     * Get unread notification count
     */
    public function unreadCount(Request $request): JsonResponse
    {
        $count = UserNotification::where('user_id', $request->user()->id)
            ->where('read', false)
            ->count();

        return response()->json([
            'success' => true,
            'data' => ['count' => $count],
            'message' => 'Unread count retrieved successfully',
        ]);
    }

    /**
     * Delete a notification for the user
     */
    public function destroy(Request $request, int $id): JsonResponse
    {
        $userNotification = UserNotification::where('user_id', $request->user()->id)
            ->where('notification_id', $id)
            ->first();

        if (!$userNotification) {
            return response()->json([
                'success' => false,
                'data' => null,
                'message' => 'Notification not found',
            ], 404);
        }

        $userNotification->delete();

        return response()->json([
            'success' => true,
            'data' => null,
            'message' => 'Notification deleted successfully',
        ]);
    }
}
