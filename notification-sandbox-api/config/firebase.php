<?php

return [
    /*
    |--------------------------------------------------------------------------
    | Firebase Credentials
    |--------------------------------------------------------------------------
    |
    | Path to the Firebase service account credentials JSON file.
    | You can download this from Firebase Console > Project Settings >
    | Service Accounts > Generate new private key.
    |
    */
    'credentials' => env('FIREBASE_CREDENTIALS', storage_path('app/firebase-credentials.json')),

    /*
    |--------------------------------------------------------------------------
    | Firebase Project ID
    |--------------------------------------------------------------------------
    |
    | Your Firebase project ID, used for FCM HTTP v1 API.
    |
    */
    'project_id' => env('FIREBASE_PROJECT_ID'),

    /*
    |--------------------------------------------------------------------------
    | FCM Settings
    |--------------------------------------------------------------------------
    |
    | Configuration options for Firebase Cloud Messaging.
    |
    */
    'fcm' => [
        // Default time-to-live for messages (in seconds)
        'ttl' => env('FCM_TTL', 2419200), // 28 days default

        // Android-specific settings
        'android' => [
            'priority' => 'high',
            'notification' => [
                'channel_id' => 'notifications',
            ],
        ],

        // iOS/APNs-specific settings
        'apns' => [
            'headers' => [
                'apns-priority' => '10',
            ],
            'payload' => [
                'aps' => [
                    'sound' => 'default',
                    'badge' => 1,
                ],
            ],
        ],
    ],
];
