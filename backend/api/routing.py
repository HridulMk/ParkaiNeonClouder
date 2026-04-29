from django.urls import re_path

from .consumers import NotificationConsumer, SpaceSlotsConsumer

websocket_urlpatterns = [
    re_path(r'^ws/spaces/(?P<space_id>\d+)/slots/?$', SpaceSlotsConsumer.as_asgi()),
    re_path(r'^ws/notifications/?$', NotificationConsumer.as_asgi()),
]
