<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Notification extends Model
{
    use HasFactory;

    protected $fillable = [
        'sender_id',
        'title',
        'body',
        'recipient_ids',
        'sent_at',
    ];

    protected function casts(): array
    {
        return [
            'recipient_ids' => 'array',
            'sent_at' => 'datetime',
        ];
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_id');
    }

    public function userNotifications(): HasMany
    {
        return $this->hasMany(UserNotification::class);
    }
}
