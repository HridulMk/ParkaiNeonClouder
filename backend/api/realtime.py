from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from django.utils import timezone


def notify_slot_update(space_id, reason='updated'):
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    async_to_sync(channel_layer.group_send)(
        f'space_slots_{space_id}',
        {
            'type': 'slot_update',
            'space_id': int(space_id),
            'reason': reason,
            'timestamp': timezone.now().isoformat(),
        },
    )

def notify_user(user_id, title, message, notification_type='system'):
    channel_layer = get_channel_layer()
    if not channel_layer:
        return

    async_to_sync(channel_layer.group_send)(
        f'user_notifications_{user_id}',
        {
            'type': 'notification_message',
            'title': title,
            'message': message,
            'notification_type': notification_type,
            'timestamp': timezone.now().isoformat(),
        },
    )
