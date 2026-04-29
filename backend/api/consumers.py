from channels.generic.websocket import AsyncJsonWebsocketConsumer


class SpaceSlotsConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        self.space_id = self.scope['url_route']['kwargs']['space_id']
        self.group_name = f'space_slots_{self.space_id}'

        await self.channel_layer.group_add(self.group_name, self.channel_name)
        await self.accept()
        await self.send_json({'type': 'connected', 'space_id': int(self.space_id)})

    async def disconnect(self, close_code):
        await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def slot_update(self, event):
        await self.send_json({
            'type': 'slot_update',
            'space_id': event.get('space_id'),
            'reason': event.get('reason', 'updated'),
            'timestamp': event.get('timestamp'),
        })

import jwt
from django.conf import settings

class NotificationConsumer(AsyncJsonWebsocketConsumer):
    async def connect(self):
        query_string = self.scope['query_string'].decode()
        token = None
        for param in query_string.split('&'):
            if param.startswith('token='):
                token = param.split('=')[1]
                break
        
        if not token:
            await self.close()
            return

        try:
            payload = jwt.decode(token, settings.SECRET_KEY, algorithms=['HS256'])
            self.user_id = payload['user_id']
            self.group_name = f'user_notifications_{self.user_id}'

            await self.channel_layer.group_add(self.group_name, self.channel_name)
            await self.accept()
            await self.send_json({'type': 'connected', 'user_id': self.user_id})
        except Exception:
            await self.close()

    async def disconnect(self, close_code):
        if hasattr(self, 'group_name'):
            await self.channel_layer.group_discard(self.group_name, self.channel_name)

    async def notification_message(self, event):
        await self.send_json({
            'type': 'notification',
            'title': event.get('title'),
            'message': event.get('message'),
            'notification_type': event.get('notification_type'),
            'timestamp': event.get('timestamp'),
        })
