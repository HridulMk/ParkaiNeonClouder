import time
import threading
import datetime
from django.utils import timezone
from django.db import transaction

def daemon_loop():
    while True:
        try:
            from .models import Reservation, Notification
            from .realtime import notify_slot_update, notify_user
            
            now = timezone.now()
            expired = Reservation.objects.filter(
                status__in=[Reservation.STATUS_PENDING_BOOKING_PAYMENT, Reservation.STATUS_RESERVED],
                expected_checkin_time__isnull=False,
                checkin_time__isnull=True
            )
            
            for res in expired:
                limit = res.expected_checkin_time + datetime.timedelta(minutes=45)
                if limit < now:
                    cancellation_reason = "Time exceeded - 45 minute check-in grace period expired"
                    
                    with transaction.atomic():
                        res.status = Reservation.STATUS_CANCELLED
                        res.cancellation_reason = cancellation_reason
                        res.save(update_fields=['status', 'cancellation_reason'])
                        
                        if res.slot:
                            # Safely free the slot
                            res.slot.is_occupied = False
                            res.slot.save(update_fields=['is_occupied'])
                            notify_slot_update(res.slot.space_id, reason='auto_cancelled')

                            # Notify Vendor
                            vendor = res.slot.space.vendor
                            if vendor:
                                msg_v = f"Reservation {res.reservation_id} for {res.slot.label} auto-cancelled. Reason: {cancellation_reason}"
                                Notification.objects.create(user=vendor, title="Auto Cancellation", message=msg_v, notification_type='cancellation')
                                try:
                                    notify_user(vendor.id, "Auto Cancellation", msg_v, 'cancellation')
                                except:
                                    pass

                        # Notify Customer
                        msg_c = f"Reservation {res.reservation_id} was automatically cancelled. Reason: {cancellation_reason}"
                        Notification.objects.create(user=res.user, title="Reservation Cancelled", message=msg_c, notification_type='cancellation')
                        try:
                            notify_user(res.user.id, "Reservation Cancelled", msg_c, 'cancellation')
                        except:
                            pass
                        
        except Exception as e:
            print("Auto cancel daemon error:", e)
        
        time.sleep(60)

def start_daemon():
    t = threading.Thread(target=daemon_loop, daemon=True)
    t.start()
