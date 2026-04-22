from decimal import Decimal

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    USER_TYPE_CHOICES = [
        ('customer', 'Customer'),
        ('vendor', 'Slot Vendor'),
        ('security', 'Security'),
        ('admin', 'Admin'),
    ]
    user_type = models.CharField(max_length=20, choices=USER_TYPE_CHOICES, default='customer')
    phone = models.CharField(max_length=15, blank=True)
    assigned_parking_space = models.ForeignKey(
        'ParkingSpace',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name='security_personnel',
        help_text='Parking space assigned to security personnel'
    )

    # Vendor-specific fields
    address = models.TextField(blank=True, help_text='Vendor address')
    company_name = models.CharField(max_length=100, blank=True, help_text='Company name for vendors')
    land_owner_name = models.CharField(max_length=100, blank=True, help_text='Land owner name for vendors')

    # Document uploads for vendor verification
    land_tax_receipt = models.FileField(
        upload_to='vendor_documents/land_tax/',
        null=True,
        blank=True,
        help_text='Land tax payment receipt'
    )
    license_document = models.FileField(
        upload_to='vendor_documents/license/',
        null=True,
        blank=True,
        help_text='Business license document'
    )
    government_id = models.FileField(
        upload_to='vendor_documents/gov_id/',
        null=True,
        blank=True,
        help_text='Government issued ID (Aadhaar/Voter ID/Driving License)'
    )

    def __str__(self):
        return f"{self.username} ({self.user_type})"


class ParkingSpace(models.Model):
    name = models.CharField(max_length=100)
    vendor = models.ForeignKey(User, on_delete=models.CASCADE, limit_choices_to={'user_type': 'vendor'})
    address = models.TextField()
    total_slots = models.PositiveIntegerField()
    location = models.TextField(blank=True)
    open_time = models.TimeField(null=True, blank=True)
    close_time = models.TimeField(null=True, blank=True)
    google_map_link = models.URLField(blank=True)
    parking_image = models.ImageField(upload_to='parking_space_images/', null=True, blank=True)
    cctv_video = models.FileField(upload_to='parking_space_cctv/', null=True, blank=True)
    is_active = models.BooleanField(default=True)
    # Realistic Indian parking rates (Rs per hour)
    hourly_rate = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal('30.00'),
        help_text='Hourly parking rate in Rs (default Rs 30/hr)')
    booking_fee = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal('20.00'),
        help_text='One-time booking/reservation fee in Rs (default Rs 20)')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.name


class ParkingSlot(models.Model):
    space = models.ForeignKey(ParkingSpace, on_delete=models.CASCADE)
    slot_id = models.CharField(max_length=10, unique=True)
    label = models.CharField(max_length=50)
    is_occupied = models.BooleanField(default=False)
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.label} ({self.slot_id})"


def _qr_image_upload_path(instance, filename):
    return f'qr/{instance.reservation_id}/{filename}'


class Reservation(models.Model):
    STATUS_PENDING_BOOKING_PAYMENT = 'pending_booking_payment'
    STATUS_RESERVED = 'reserved'
    STATUS_CHECKED_IN = 'checked_in'
    STATUS_CHECKED_OUT = 'checked_out'
    STATUS_COMPLETED = 'completed'

    STATUS_CHOICES = [
        (STATUS_PENDING_BOOKING_PAYMENT, 'Pending Booking Payment'),
        (STATUS_RESERVED, 'Reserved'),
        (STATUS_CHECKED_IN, 'Checked In'),
        (STATUS_CHECKED_OUT, 'Checked Out'),
        (STATUS_COMPLETED, 'Completed'),
    ]

    user = models.ForeignKey(User, on_delete=models.CASCADE)
    slot = models.ForeignKey(ParkingSlot, on_delete=models.CASCADE)
    reservation_id = models.CharField(max_length=20, unique=True)
    start_time = models.DateTimeField()
    end_time = models.DateTimeField()
    amount = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal('0.00'))
    is_paid = models.BooleanField(default=False)
    booking_fee = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal('20.00'))
    booking_fee_paid = models.BooleanField(default=False)
    checkin_time = models.DateTimeField(null=True, blank=True)
    checkout_time = models.DateTimeField(null=True, blank=True)
    final_fee = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    final_fee_paid = models.BooleanField(default=False)
    hourly_rate = models.DecimalField(max_digits=8, decimal_places=2, default=Decimal('30.00'))
    status = models.CharField(max_length=40, choices=STATUS_CHOICES, default=STATUS_PENDING_BOOKING_PAYMENT)
    qr_code = models.TextField(blank=True)
    qr_image = models.ImageField(upload_to=_qr_image_upload_path, blank=True, null=True)
    vehicle_number = models.CharField(max_length=20, blank=True, help_text='Vehicle registration number')
    vehicle_type = models.CharField(max_length=20, choices=[
        ('suv', 'SUV'),
        ('pickup', 'Pickup'),
        ('sedan', 'Sedan'),
        ('hatchback', 'Hatchback'),
    ], blank=True, help_text='Type of vehicle')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Reservation {self.reservation_id}"


class PaymentRecord(models.Model):
    PAYMENT_TYPE_BOOKING = 'booking'
    PAYMENT_TYPE_FINAL = 'final'
    PAYMENT_TYPE_CHOICES = [
        (PAYMENT_TYPE_BOOKING, 'Booking Fee'),
        (PAYMENT_TYPE_FINAL, 'Final Fee'),
    ]

    reservation = models.ForeignKey(Reservation, on_delete=models.CASCADE, related_name='payments')
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='payments')
    # Denormalised snapshot — preserved even if slot/space is later deleted
    user_full_name = models.CharField(max_length=200, blank=True)
    user_email = models.CharField(max_length=254, blank=True)
    user_phone = models.CharField(max_length=15, blank=True)
    slot_id = models.CharField(max_length=10, help_text='Slot identifier at time of payment')
    slot_label = models.CharField(max_length=50, blank=True)
    parking_space_name = models.CharField(max_length=100)
    parking_space_location = models.TextField(blank=True)
    payment_type = models.CharField(max_length=10, choices=PAYMENT_TYPE_CHOICES)
    amount = models.DecimalField(max_digits=8, decimal_places=2)
    paid_at = models.DateTimeField(auto_now_add=True)
    transaction_ref = models.CharField(max_length=40, unique=True,
        help_text='Internal transaction reference')

    class Meta:
        ordering = ['-paid_at']

    def __str__(self):
        return f"{self.payment_type} | {self.user_full_name} | Rs {self.amount} | {self.paid_at:%Y-%m-%d %H:%M}"


class Gate(models.Model):
    name = models.CharField(max_length=100)
    space = models.ForeignKey(ParkingSpace, on_delete=models.CASCADE)
    is_active = models.BooleanField(default=True)
    last_access = models.DateTimeField(null=True, blank=True)
    access_count = models.PositiveIntegerField(default=0)

    def __str__(self):
        return self.name


class CCTVFeed(models.Model):
    space = models.ForeignKey(ParkingSpace, on_delete=models.CASCADE)
    camera_id = models.CharField(max_length=20)
    name = models.CharField(max_length=100)
    stream_url = models.URLField()
    is_active = models.BooleanField(default=True)

    def __str__(self):
        return f"{self.name} - {self.space.name}"


class VehicleLog(models.Model):
    space = models.ForeignKey(ParkingSpace, on_delete=models.CASCADE, related_name='vehicle_logs')
    slot = models.ForeignKey(ParkingSlot, on_delete=models.SET_NULL, null=True, blank=True, related_name='vehicle_logs')
    vehicle_number = models.CharField(max_length=20)
    vehicle_type = models.CharField(max_length=50, blank=True, help_text='e.g., Car, Motorcycle, Truck')
    check_in_time = models.DateTimeField()
    check_out_time = models.DateTimeField(null=True, blank=True)
    duration_minutes = models.PositiveIntegerField(null=True, blank=True, help_text='Duration in minutes')
    user = models.ForeignKey(User, on_delete=models.SET_NULL, null=True, blank=True, related_name='vehicle_logs')
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.vehicle_number} at {self.space.name}"

    def save(self, *args, **kwargs):
        if self.check_out_time and self.check_in_time:
            delta = self.check_out_time - self.check_in_time
            self.duration_minutes = int(delta.total_seconds() / 60)
        super().save(*args, **kwargs)

