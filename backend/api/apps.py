from django.apps import AppConfig


class ApiConfig(AppConfig):
    name = 'api'

    def ready(self):
        import os
        # Run only in the main thread/server process, not during migrate/makemigrations
        if not os.environ.get('RUN_MAIN', None):
            return
            
        from .auto_cancel import start_daemon
        start_daemon()
