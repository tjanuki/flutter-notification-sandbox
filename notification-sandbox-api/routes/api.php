<?php

use App\Http\Controllers\AuthController;
use App\Http\Controllers\NotificationController;
use App\Http\Controllers\Admin\NotificationController as AdminNotificationController;
use Illuminate\Support\Facades\Route;

// Public routes
Route::post('/register', [AuthController::class, 'register']);
Route::post('/login', [AuthController::class, 'login']);

// Protected routes
Route::middleware('auth:sanctum')->group(function () {
    // Auth routes
    Route::post('/logout', [AuthController::class, 'logout']);
    Route::get('/user', [AuthController::class, 'user']);
    Route::put('/user/fcm-token', [AuthController::class, 'updateFcmToken']);

    // User notification routes
    Route::prefix('notifications')->group(function () {
        Route::get('/', [NotificationController::class, 'index']);
        Route::get('/unread-count', [NotificationController::class, 'unreadCount']);
        Route::get('/{id}', [NotificationController::class, 'show']);
        Route::put('/{id}/read', [NotificationController::class, 'markAsRead']);
        Route::put('/read-all', [NotificationController::class, 'markAllAsRead']);
        Route::delete('/{id}', [NotificationController::class, 'destroy']);
    });

    // Admin routes
    Route::middleware('admin')->prefix('admin')->group(function () {
        Route::get('/users', [AdminNotificationController::class, 'getUsers']);
        Route::get('/notifications', [AdminNotificationController::class, 'index']);
        Route::get('/notifications/{id}', [AdminNotificationController::class, 'show']);
        Route::post('/notifications/send', [AdminNotificationController::class, 'send']);
        Route::post('/notifications/send-all', [AdminNotificationController::class, 'sendToAll']);
        Route::delete('/notifications/{id}', [AdminNotificationController::class, 'destroy']);
    });
});
