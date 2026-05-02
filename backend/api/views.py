from decimal import Decimal, ROUND_HALF_UP
from datetime import timedelta
import io
import json
import os
import uuid
import requests
import tempfile
import cloudinary.uploader
from django.conf import settings
from django.core.files.base import ContentFile
from django.db import transaction
from django.db.models import Count, Exists, OuterRef, Q, Sum
from django.db.models.functions import TruncDay
from django.shortcuts import get_object_or_404
from django.utils.dateparse import parse_date
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView
import qrcode

from .models import CCTVFeed, Gate, ParkingSlot, ParkingSpace, PaymentRecord, Reservation, SystemSetting, User, VehicleLog, Wallet, WalletTransaction, Notification, FAQ
from .permissions import IsAdminUserType, IsVendorOrAdmin
from .realtime import notify_slot_update, notify_user
from .serializers import (
    CCTVFeedSerializer,
    AdminUserSerializer,
    CustomTokenObtainPairSerializer,
    GateSerializer,
    PaymentRecordSerializer,
    ParkingSlotSerializer,
    ParkingSpaceCreateSerializer,
    ParkingSpaceSerializer,
    ReservationSerializer,
    UserRegistrationSerializer,
    UserSerializer,
    SystemSettingSerializer,
    VehicleLogSerializer,
    WalletSerializer,
    FAQSerializer,
)

# Fallback rates — actual rates are read from ParkingSpace per reservation
DEFAULT_BOOKING_FEE = Decimal('20.00')   # Rs 20 reservation fee
DEFAULT_HOURLY_RATE = Decimal('30.00')   # Rs 30 / hour

# Vehicle-type multipliers applied on top of the space hourly rate
VEHICLE_RATE_MULTIPLIER = {
    'suv':      Decimal('1.50'),   # SUV  → 1.5x
    'pickup':   Decimal('1.40'),   # Pickup → 1.4x
    'sedan':    Decimal('1.00'),   # Sedan  → 1.0x (base)
    'hatchback':Decimal('0.85'),   # Hatchback → 0.85x
}


def _generate_qr_image(reservation):
    img = qrcode.make(reservation.qr_code)
    with io.BytesIO() as buffer:
        img.save(buffer, format='PNG')
        buffer.seek(0)
        filename = f"{reservation.reservation_id}.png"
        reservation.qr_image.save(
            filename,
            ContentFile(buffer.read()),
            save=False,
        )


def _can_manage_space(user, space):
    if user.is_staff or user.user_type == 'admin':
        return True
    return user.user_type == 'vendor' and space.vendor_id == user.id


def _active_booking_exists(slot):
    return Reservation.objects.filter(
        slot=slot,
        status__in=[
            Reservation.STATUS_PENDING_BOOKING_PAYMENT,
            Reservation.STATUS_RESERVED,
            Reservation.STATUS_CHECKED_IN,
        ],
    ).exists()


ACTIVE_RESERVATION_STATUSES = [
    Reservation.STATUS_PENDING_BOOKING_PAYMENT,
    Reservation.STATUS_RESERVED,
    Reservation.STATUS_CHECKED_IN,
]


def _visible_spaces_for_user(user):
    queryset = ParkingSpace.objects.select_related('vendor').all()
    if user.user_type == 'vendor':
        return queryset.filter(vendor=user)
    if user.user_type == 'security' and user.assigned_parking_space_id:
        return queryset.filter(id=user.assigned_parking_space_id)
    if user.user_type == 'admin' or user.is_staff:
        return queryset
    return queryset.filter(is_active=True)


def _visible_reservations_for_user(user):
    queryset = Reservation.objects.select_related('slot', 'slot__space', 'user').all()
    if user.user_type == 'admin' or user.is_staff:
        return queryset
    if user.user_type == 'vendor':
        return queryset.filter(slot__space__vendor=user)
    if user.user_type == 'security':
        if user.assigned_parking_space_id:
            return queryset.filter(slot__space_id=user.assigned_parking_space_id)
        return queryset.none()
    return queryset.filter(user=user)


def _visible_slots_for_user(user):
    queryset = ParkingSlot.objects.select_related('space').all()
    if user.user_type == 'vendor':
        return queryset.filter(space__vendor=user)
    if user.user_type == 'security' and user.assigned_parking_space_id:
        return queryset.filter(space_id=user.assigned_parking_space_id)
    if user.user_type == 'admin' or user.is_staff:
        return queryset
    return queryset.filter(space__is_active=True, is_active=True)


def _dashboard_payload(user):
    spaces = _visible_spaces_for_user(user)
    reservations = _visible_reservations_for_user(user)
    slots = _visible_slots_for_user(user)

    active_spaces = spaces.filter(is_active=True)
    slot_counts = slots.aggregate(
        total_slots=Count('id'),
        active_slots=Count('id', filter=Q(is_active=True)),
        occupied_slots=Count('id', filter=Q(is_active=True, is_occupied=True)),
        vacant_slots=Count('id', filter=Q(is_active=True, is_occupied=False)),
    )
    reservation_counts = reservations.aggregate(
        total_reservations=Count('id'),
        successful_reservations=Count(
            'id',
            filter=Q(status=Reservation.STATUS_COMPLETED) | Q(final_fee_paid=True) | Q(is_paid=True),
        ),
        active_reservations=Count('id', filter=Q(status__in=ACTIVE_RESERVATION_STATUSES)),
        pending_reservations=Count('id', filter=Q(status=Reservation.STATUS_PENDING_BOOKING_PAYMENT)),
        completed_reservations=Count('id', filter=Q(status=Reservation.STATUS_COMPLETED)),
        cancelled_reservations=Count('id', filter=Q(status=Reservation.STATUS_CANCELLED)),
        total_revenue=Sum('amount', filter=Q(is_paid=True)),
    )

    nearby_spaces = []
    for space in active_spaces.annotate(
        active_slot_count=Count('parkingslot', filter=Q(parkingslot__is_active=True), distinct=True),
        vacant_slot_count=Count('parkingslot', filter=Q(parkingslot__is_active=True, parkingslot__is_occupied=False), distinct=True),
    ).order_by('-created_at')[:6]:
        nearby_spaces.append({
            'id': space.id,
            'name': space.name,
            'location': space.location or space.address,
            'total_slots': space.active_slot_count,
            'vacant_slots': space.vacant_slot_count,
            'google_map_link': space.google_map_link,
        })

    return {
        'total_reservations': reservation_counts['total_reservations'],
        'successful_reservations': reservation_counts['successful_reservations'],
        'active_reservations': reservation_counts['active_reservations'],
        'pending_reservations': reservation_counts['pending_reservations'],
        'completed_reservations': reservation_counts['completed_reservations'],
        'cancelled_reservations': reservation_counts['cancelled_reservations'],
        'nearby_parking_count': active_spaces.count(),
        'total_slots': slot_counts['active_slots'],
        'vacant_slots': slot_counts['vacant_slots'],
        'occupied_slots': slot_counts['occupied_slots'],
        'all_slots': slot_counts['total_slots'],
        'total_revenue': f"{reservation_counts['total_revenue'] or 0:.2f}",
        'nearby_spaces': nearby_spaces,
    }


def _money(value):
    return f"{value or Decimal('0.00'):.2f}"


def _analytics_date_range(request):
    start = parse_date(request.query_params.get('start_date', ''))
    end = parse_date(request.query_params.get('end_date', ''))
    return start, end


def _filter_payments_by_date(queryset, start, end):
    if start:
        queryset = queryset.filter(paid_at__date__gte=start)
    if end:
        queryset = queryset.filter(paid_at__date__lte=end)
    return queryset


def _filter_reservations_by_date(queryset, start, end):
    if start:
        queryset = queryset.filter(created_at__date__gte=start)
    if end:
        queryset = queryset.filter(created_at__date__lte=end)
    return queryset


def _payment_totals(queryset):
    totals = queryset.aggregate(
        total_revenue=Sum('amount'),
        booking_revenue=Sum('amount', filter=Q(payment_type=PaymentRecord.PAYMENT_TYPE_BOOKING)),
        final_revenue=Sum('amount', filter=Q(payment_type=PaymentRecord.PAYMENT_TYPE_FINAL)),
    )
    return {
        'total_revenue': totals['total_revenue'] or Decimal('0.00'),
        'booking_revenue': totals['booking_revenue'] or Decimal('0.00'),
        'final_revenue': totals['final_revenue'] or Decimal('0.00'),
    }


def _daily_revenue(queryset):
    rows = (
        queryset.annotate(day=TruncDay('paid_at'))
        .values('day')
        .annotate(revenue=Sum('amount'), payments=Count('id'))
        .order_by('day')
    )
    return [
        {
            'date': row['day'].date().isoformat(),
            'revenue': _money(row['revenue']),
            'payments': row['payments'],
        }
        for row in rows
        if row['day'] is not None
    ]


def _status_breakdown(queryset):
    rows = queryset.values('status').annotate(count=Count('id')).order_by('status')
    return [{'status': row['status'] or 'unknown', 'count': row['count']} for row in rows]


def _vehicle_type_breakdown(queryset):
    rows = queryset.values('vehicle_type').annotate(count=Count('id')).order_by('vehicle_type')
    return [{'vehicle_type': row['vehicle_type'] or 'unknown', 'count': row['count']} for row in rows]


def _analytics_scope_for_user(user):
    payments = PaymentRecord.objects.select_related(
        'user', 'reservation', 'reservation__slot', 'reservation__slot__space', 'reservation__slot__space__vendor'
    ).all()
    reservations = Reservation.objects.select_related('user', 'slot', 'slot__space', 'slot__space__vendor').all()
    spaces = ParkingSpace.objects.select_related('vendor').all()
    slots = ParkingSlot.objects.select_related('space', 'space__vendor').all()

    if user.user_type == 'vendor':
        return (
            payments.filter(reservation__slot__space__vendor=user),
            reservations.filter(slot__space__vendor=user),
            spaces.filter(vendor=user),
            slots.filter(space__vendor=user),
        )
    if user.user_type == 'customer':
        return (
            payments.filter(user=user),
            reservations.filter(user=user),
            spaces.filter(is_active=True),
            slots.filter(space__is_active=True, is_active=True),
        )
    if user.user_type == 'security':
        if user.assigned_parking_space_id:
            return (
                payments.filter(reservation__slot__space_id=user.assigned_parking_space_id),
                reservations.filter(slot__space_id=user.assigned_parking_space_id),
                spaces.filter(id=user.assigned_parking_space_id),
                slots.filter(space_id=user.assigned_parking_space_id),
            )
        return payments.none(), reservations.none(), spaces.none(), slots.none()

    return payments, reservations, spaces, slots


def _analytics_payload(request):
    payments, reservations, spaces, slots = _analytics_scope_for_user(request.user)
    start, end = _analytics_date_range(request)
    payments = _filter_payments_by_date(payments, start, end)
    reservations = _filter_reservations_by_date(reservations, start, end)

    totals = _payment_totals(payments)
    settings_obj, _ = SystemSetting.objects.get_or_create(pk=1)
    commission_amount = (
        totals['total_revenue'] * settings_obj.commission_percentage / Decimal('100')
    ).quantize(Decimal('0.01'))
    booking_counts = reservations.aggregate(
        total_bookings=Count('id'),
        active_bookings=Count('id', filter=Q(status__in=ACTIVE_RESERVATION_STATUSES)),
        completed_bookings=Count('id', filter=Q(status=Reservation.STATUS_COMPLETED)),
        cancelled_bookings=Count('id', filter=Q(status=Reservation.STATUS_CANCELLED)),
        pending_bookings=Count('id', filter=Q(status=Reservation.STATUS_PENDING_BOOKING_PAYMENT)),
    )
    slot_counts = slots.aggregate(
        total_slots=Count('id'),
        active_slots=Count('id', filter=Q(is_active=True)),
        occupied_slots=Count('id', filter=Q(is_active=True, is_occupied=True)),
        vacant_slots=Count('id', filter=Q(is_active=True, is_occupied=False)),
    )
    top_spaces = (
        payments.values(
            'reservation__slot__space_id',
            'reservation__slot__space__name',
        )
        .annotate(revenue=Sum('amount'), payments=Count('id'))
        .order_by('-revenue')[:5]
    )
    top_customers = (
        payments.values('user_id', 'user__username', 'user_full_name')
        .annotate(spend=Sum('amount'), payments=Count('id'))
        .order_by('-spend')[:5]
    )

    payload = {
        'scope': request.user.user_type,
        'date_range': {
            'start_date': start.isoformat() if start else None,
            'end_date': end.isoformat() if end else None,
        },
        'revenue': {
            'total': _money(totals['total_revenue']),
            'booking': _money(totals['booking_revenue']),
            'final': _money(totals['final_revenue']),
            'commission_percentage': _money(settings_obj.commission_percentage),
            'commission_amount': _money(commission_amount),
            'net_after_commission': _money(totals['total_revenue'] - commission_amount),
        },
        'bookings': booking_counts,
        'spaces': {
            'total_spaces': spaces.count(),
            'active_spaces': spaces.filter(is_active=True).count(),
            'inactive_spaces': spaces.filter(is_active=False).count(),
        },
        'slots': slot_counts,
        'daily_revenue': _daily_revenue(payments),
        'status_breakdown': _status_breakdown(reservations),
        'vehicle_type_breakdown': _vehicle_type_breakdown(reservations),
        'top_spaces': [
            {
                'space_id': row['reservation__slot__space_id'],
                'space_name': row['reservation__slot__space__name'] or 'Unknown',
                'revenue': _money(row['revenue']),
                'payments': row['payments'],
            }
            for row in top_spaces
        ],
        'top_customers': [
            {
                'customer_id': row['user_id'],
                'customer_name': row['user_full_name'] or row['user__username'] or 'Unknown',
                'spend': _money(row['spend']),
                'payments': row['payments'],
            }
            for row in top_customers
        ],
    }

    if request.user.user_type == 'admin' or request.user.is_staff:
        top_vendors = (
            payments.values(
                'reservation__slot__space__vendor_id',
                'reservation__slot__space__vendor__username',
            )
            .annotate(revenue=Sum('amount'), payments=Count('id'))
            .order_by('-revenue')[:5]
        )
        payload['top_vendors'] = [
            {
                'vendor_id': row['reservation__slot__space__vendor_id'],
                'vendor_name': row['reservation__slot__space__vendor__username'] or 'Unknown',
                'revenue': _money(row['revenue']),
                'payments': row['payments'],
            }
            for row in top_vendors
        ]

    return payload


def _vendor_revenue_payload(request, vendor_id):
    vendor = get_object_or_404(User, id=vendor_id, user_type='vendor')
    if not (request.user.user_type == 'admin' or request.user.is_staff or request.user.id == vendor.id):
        return None

    start, end = _analytics_date_range(request)
    payments = PaymentRecord.objects.filter(reservation__slot__space__vendor=vendor)
    payments = _filter_payments_by_date(payments, start, end)
    totals = _payment_totals(payments)
    settings_obj, _ = SystemSetting.objects.get_or_create(pk=1)
    commission_amount = (
        totals['total_revenue'] * settings_obj.commission_percentage / Decimal('100')
    ).quantize(Decimal('0.01'))
    return {
        'vendor_id': vendor.id,
        'vendor_name': vendor.username,
        'date_range': {
            'start_date': start.isoformat() if start else None,
            'end_date': end.isoformat() if end else None,
        },
        'total_revenue': _money(totals['total_revenue']),
        'booking_revenue': _money(totals['booking_revenue']),
        'final_revenue': _money(totals['final_revenue']),
        'commission_amount': _money(commission_amount),
        'net_revenue': _money(totals['total_revenue'] - commission_amount),
        'payments_count': payments.count(),
        'daily_revenue': _daily_revenue(payments),
    }


def _customer_spend_payload(request, customer_id):
    customer = get_object_or_404(User, id=customer_id, user_type='customer')
    if not (request.user.user_type == 'admin' or request.user.is_staff or request.user.id == customer.id):
        return None

    start, end = _analytics_date_range(request)
    payments = PaymentRecord.objects.filter(user=customer)
    payments = _filter_payments_by_date(payments, start, end)
    totals = _payment_totals(payments)
    return {
        'customer_id': customer.id,
        'customer_name': f"{customer.first_name} {customer.last_name}".strip() or customer.username,
        'date_range': {
            'start_date': start.isoformat() if start else None,
            'end_date': end.isoformat() if end else None,
        },
        'total_spend': _money(totals['total_revenue']),
        'booking_spend': _money(totals['booking_revenue']),
        'final_spend': _money(totals['final_revenue']),
        'payments_count': payments.count(),
        'daily_spend': _daily_revenue(payments),
    }


def _notify_admins(title, message, notification_type='system'):
    admins = User.objects.filter(Q(user_type='admin') | Q(is_staff=True)).distinct()
    for admin in admins:
        Notification.objects.create(
            user=admin,
            title=title,
            message=message,
            notification_type=notification_type,
        )
        try:
            notify_user(admin.id, title, message, notification_type)
        except Exception:
            pass


def _create_pending_reservation(user, slot, vehicle_number=None, vehicle_type=None, expected_checkin_time=None, estimated_duration_mins=None):
    if user.user_type != 'customer':
        return Response({'detail': 'Only customers can create a booking reservation.'}, status=status.HTTP_403_FORBIDDEN)

    if not slot.space.is_active:
        return Response({'detail': 'Parking space is not active.'}, status=status.HTTP_400_BAD_REQUEST)

    if not slot.is_active:
        return Response({'detail': 'Parking slot is not active.'}, status=status.HTTP_400_BAD_REQUEST)

    if slot.is_occupied or _active_booking_exists(slot):
        return Response({'detail': 'Slot is not available for booking.'}, status=status.HTTP_400_BAD_REQUEST)

    # Pull rates from the parking space (with fallback)
    space_booking_fee = slot.space.booking_fee if slot.space.booking_fee else DEFAULT_BOOKING_FEE
    space_hourly_rate = slot.space.hourly_rate if slot.space.hourly_rate else DEFAULT_HOURLY_RATE

    # Apply vehicle-type multiplier to hourly rate
    multiplier = VEHICLE_RATE_MULTIPLIER.get((vehicle_type or '').lower(), Decimal('1.00'))
    effective_hourly_rate = (space_hourly_rate * multiplier).quantize(Decimal('0.01'))

    now = timezone.now()
    reservation = Reservation.objects.create(
        user=user,
        slot=slot,
        reservation_id=f"PKG{now.strftime('%Y%m%d%H%M%S')}{user.id}{slot.id}",
        start_time=now,
        end_time=now,
        amount=Decimal('0.00'),
        is_paid=False,
        booking_fee=space_booking_fee,
        booking_fee_paid=False,
        hourly_rate=effective_hourly_rate,
        vehicle_number=vehicle_number or '',
        vehicle_type=vehicle_type or '',
        expected_checkin_time=expected_checkin_time,
        estimated_duration_mins=estimated_duration_mins,
        status=Reservation.STATUS_PENDING_BOOKING_PAYMENT,
    )

    notify_slot_update(slot.space_id, reason='reservation_pending')
    return Response(ReservationSerializer(reservation).data, status=status.HTTP_201_CREATED)


def _create_space_and_slots(request):
    serializer = ParkingSpaceCreateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    validated = serializer.validated_data
    user = request.user
    requested_vendor = validated.get('vendor')

    if user.user_type == 'vendor':
        vendor = user
    else:
        # Admin can assign a vendor, or upload the space as admin when vendor is omitted.
        vendor = requested_vendor or user

    number_of_slots = validated['number_of_slots']

    with transaction.atomic():
        parking_space = ParkingSpace.objects.create(
            name=validated['name'],
            vendor=vendor,
            total_slots=number_of_slots,
            address=validated['location'],
            location=validated['location'],
            open_time=validated.get('open_time'),
            close_time=validated.get('close_time'),
            hourly_rate=validated.get('hourly_rate') or DEFAULT_HOURLY_RATE,
            booking_fee=validated.get('booking_fee') or DEFAULT_BOOKING_FEE,
            google_map_link=validated.get('google_map_link', ''),
            parking_image=validated.get('parking_image'),
            cctv_video=validated.get('cctv_video'),
        )

        for idx in range(1, number_of_slots + 1):
            ParkingSlot.objects.create(
                space=parking_space,
                slot_id=f'S{parking_space.id:03d}-{idx:03d}',
                label=f'Slot {idx}',
            )

    notify_slot_update(parking_space.id, reason='space_slots_created')
    
    if vendor:
        msg_v = f"Parking space '{parking_space.name}' successfully created with {number_of_slots} slots."
        Notification.objects.create(user=vendor, title="Space Created", message=msg_v, notification_type='space')
        try: notify_user(vendor.id, "Space Created", msg_v, 'space')
        except: pass

    _notify_admins(
        "Parking Space Created",
        f"{parking_space.name} was created with {number_of_slots} slots by {user.username}.",
        'space',
    )

    payload = ParkingSpaceSerializer(parking_space).data
    payload['slots_created'] = number_of_slots
    return Response(payload, status=status.HTTP_201_CREATED)


class ParkingSpaceCreateEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsVendorOrAdmin]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def post(self, request):
        return _create_space_and_slots(request)


class CustomerSlotBookingEndpoint(APIView):
    permission_classes = [IsAuthenticated]

    def post(self, request, space_id, slot_id):
        slot = get_object_or_404(ParkingSlot, id=slot_id, space_id=space_id)
        
        # Get vehicle information from request
        vehicle_number = request.data.get('vehicle_number', '').strip()
        vehicle_type = request.data.get('vehicle_type', '').strip()
        expected_checkin_time = request.data.get('expected_checkin_time')
        estimated_duration_mins = request.data.get('estimated_duration_mins')

        if estimated_duration_mins:
            try:
                estimated_duration_mins = int(estimated_duration_mins)
            except ValueError:
                return Response({'detail': 'estimated_duration_mins must be a valid integer.'}, status=status.HTTP_400_BAD_REQUEST)
        
        # Validate vehicle type
        valid_vehicle_types = ['suv', 'pickup', 'sedan', 'hatchback']
        if vehicle_type and vehicle_type not in valid_vehicle_types:
            return Response({'detail': 'Invalid vehicle type. Must be one of: suv, pickup, sedan, hatchback.'}, status=status.HTTP_400_BAD_REQUEST)
        
        return _create_pending_reservation(
            user=request.user, 
            slot=slot, 
            vehicle_number=vehicle_number, 
            vehicle_type=vehicle_type,
            expected_checkin_time=expected_checkin_time,
            estimated_duration_mins=estimated_duration_mins
        )


class ParkingSpaceDeleteEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsVendorOrAdmin]

    def delete(self, request, space_id):
        parking_space = get_object_or_404(ParkingSpace, id=space_id)
        if not _can_manage_space(request.user, parking_space):
            return Response({'detail': 'You do not have permission to delete this parking space.'}, status=status.HTTP_403_FORBIDDEN)

        slot_count = ParkingSlot.objects.filter(space=parking_space).count()
        parking_space.delete()
        return Response({'message': 'Parking space deleted successfully.', 'parking_space_id': space_id, 'slots_deleted': slot_count}, status=status.HTTP_200_OK)


class ParkingSpaceSlotsDeleteEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsVendorOrAdmin]

    def delete(self, request, space_id):
        parking_space = get_object_or_404(ParkingSpace, id=space_id)
        if not _can_manage_space(request.user, parking_space):
            return Response({'detail': 'You do not have permission to delete slots for this parking space.'}, status=status.HTTP_403_FORBIDDEN)

        slot_qs = ParkingSlot.objects.filter(space=parking_space)
        slot_count = slot_qs.count()
        slot_qs.delete()
        notify_slot_update(parking_space.id, reason='space_slots_deleted')
        parking_space.total_slots = 0
        parking_space.save(update_fields=['total_slots'])
        return Response({'message': 'Parking slots deleted successfully.', 'parking_space_id': space_id, 'slots_deleted': slot_count}, status=status.HTTP_200_OK)


class ParkingSlotDeleteEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsVendorOrAdmin]

    def delete(self, request, slot_id):
        slot = get_object_or_404(ParkingSlot, id=slot_id)
        parking_space = slot.space
        if not _can_manage_space(request.user, parking_space):
            return Response({'detail': 'You do not have permission to delete this parking slot.'}, status=status.HTTP_403_FORBIDDEN)

        slot.delete()
        notify_slot_update(parking_space.id, reason='slot_deleted')
        parking_space.total_slots = ParkingSlot.objects.filter(space=parking_space).count()
        parking_space.save(update_fields=['total_slots'])
        return Response({'message': 'Parking slot deleted successfully.', 'parking_slot_id': slot_id, 'parking_space_id': parking_space.id}, status=status.HTTP_200_OK)


class ParkingSpaceActivateEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsAdminUserType]

    def post(self, request, space_id):
        parking_space = get_object_or_404(ParkingSpace, id=space_id)
        parking_space.is_active = True
        parking_space.save(update_fields=['is_active'])
        notify_slot_update(parking_space.id, reason='space_activated')
        return Response({'message': 'Parking space activated.', 'parking_space_id': parking_space.id, 'is_active': parking_space.is_active}, status=status.HTTP_200_OK)


class ParkingSpaceDeactivateEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsAdminUserType]

    def post(self, request, space_id):
        parking_space = get_object_or_404(ParkingSpace, id=space_id)
        parking_space.is_active = False
        parking_space.save(update_fields=['is_active'])
        notify_slot_update(parking_space.id, reason='space_deactivated')
        return Response({'message': 'Parking space deactivated.', 'parking_space_id': parking_space.id, 'is_active': parking_space.is_active}, status=status.HTTP_200_OK)


class ParkingSpaceCCTVUploadEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsVendorOrAdmin]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request, space_id):
        parking_space = get_object_or_404(ParkingSpace, id=space_id)
        if not _can_manage_space(request.user, parking_space):
            return Response({'detail': 'You do not have permission to upload CCTV video for this parking space.'}, status=status.HTTP_403_FORBIDDEN)

        file_obj = request.FILES.get('cctv_video')
        if not file_obj:
            return Response({'detail': 'No CCTV video file provided. Expected field name "cctv_video".'}, status=status.HTTP_400_BAD_REQUEST)

        parking_space.cctv_video = file_obj
        parking_space.save(update_fields=['cctv_video'])

        notify_slot_update(parking_space.id, reason='cctv_video_uploaded')
        return Response(ParkingSpaceSerializer(parking_space).data, status=status.HTTP_200_OK)






class ParkingLotSaveVideoEndpoint(APIView):
    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        file_obj = request.FILES.get('video')

        if not file_obj:
            return Response(
                {'detail': 'No video file provided. Expected field name "video".'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # ✅ Generate session ID
        session_id = uuid.uuid4().hex

        try:
            # ✅ Upload to Cloudinary
            result = cloudinary.uploader.upload_large(
                file_obj,
                resource_type="video",
                folder=f"parking_uploads/{session_id}"
            )

            video_url = result.get('secure_url')
            public_id = result.get('public_id')

        except Exception as e:
            return Response(
                {'detail': f'Cloudinary upload failed: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        return Response({
            'success': True,
            'session_id': session_id,
            'video_url': video_url,
            'public_id': public_id
        }, status=status.HTTP_200_OK)




class ParkingLotRunAnalysisEndpoint(APIView):
    permission_classes = []

    def post(self, request):
        import traceback
        try:
            return self._run(request)
        except Exception as e:
            traceback.print_exc()
            return Response(
                {'success': False, 'error': f'Unhandled server error: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    def _run(self, request):
        session_id = request.data.get('session_id')
        if not session_id:
            return Response({'success': False, 'error': 'session_id is required.'}, status=status.HTTP_400_BAD_REQUEST)

        video_url = request.data.get('video_url')
        if not video_url:
            return Response({'success': False, 'error': 'video_url is required.'}, status=status.HTTP_400_BAD_REQUEST)

        print("\n🚀 RUN ANALYSIS START — session:", session_id)

        temp_dir = tempfile.mkdtemp()
        input_video_path = os.path.join(temp_dir, 'input.mp4')

        # Download video
        print("⬇️ Downloading video...")
        vid_resp = requests.get(video_url, stream=True, timeout=120)
        if vid_resp.status_code != 200:
            return Response({'success': False, 'error': f'Failed to download video (HTTP {vid_resp.status_code}).'}, status=status.HTTP_400_BAD_REQUEST)
        with open(input_video_path, 'wb') as f:
            for chunk in vid_resp.iter_content(chunk_size=8192):
                f.write(chunk)
        print(f"✅ Video downloaded: {os.path.getsize(input_video_path)} bytes")

        # Resolve polygons
        polygon_url = request.data.get('polygon_url')
        polygons_path = os.path.join(settings.MEDIA_ROOT, 'parking_uploads', session_id, 'polygons.json')

        if polygon_url:
            print('⬇️ Downloading polygons...')
            poly_resp = requests.get(polygon_url, timeout=30)
            if poly_resp.status_code != 200:
                return Response({'success': False, 'error': f'Failed to download polygons (HTTP {poly_resp.status_code}).'}, status=status.HTTP_400_BAD_REQUEST)
            os.makedirs(os.path.dirname(polygons_path), exist_ok=True)
            with open(polygons_path, 'wb') as f:
                f.write(poly_resp.content)
        elif not os.path.exists(polygons_path):
            return Response({'success': False, 'error': 'polygons.json not found. Save polygons first.'}, status=status.HTTP_400_BAD_REQUEST)

        # Run YOLO
        from .process_video import process_video
        print("⚙️ Running YOLO...")
        result = process_video(
            session_id=session_id,
            input_path=input_video_path,
            polygons_path=polygons_path,
            output_dir=temp_dir,
        )
        print("🔍 process_video result:", {k: v for k, v in result.items() if k != 'frame_data'})

        if not result.get('success'):
            return Response({'success': False, 'error': result.get('error', 'YOLO processing failed.')}, status=status.HTTP_400_BAD_REQUEST)

        output_path = result.get('output_path')
        if not output_path or not os.path.exists(output_path):
            return Response({'success': False, 'error': 'Output video file not found after processing.'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        # Upload to Cloudinary
        print("☁️ Uploading to Cloudinary...")
        upload_result = cloudinary.uploader.upload_large(
            output_path,
            resource_type='video',
            folder=f'parking_results/{session_id}',
            eager=[{'format': 'mp4', 'video_codec': 'h264'}],
            eager_async=False,
        )
        eager = upload_result.get('eager')
        output_url = (eager[0].get('secure_url') if eager else None) or upload_result.get('secure_url')

        return Response({
            'success': True,
            'occupied': result.get('occupied', 0),
            'free': result.get('free', 0),
            'total': result.get('total', 0),
            'fps': result.get('fps', 20.0),
            'frame_data': result.get('frame_data', []),
            'output_video_url': output_url,
        }, status=status.HTTP_200_OK)
        
        
        
class ParkingLotPolygonsEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsVendorOrAdmin]
    parser_classes = [MultiPartParser, FormParser, JSONParser]

    def get(self, request):
        session_id = request.query_params.get('session_id')

        if not session_id:
            return Response({'polygons': []}, status=status.HTTP_200_OK)

        session_dir = os.path.join(settings.MEDIA_ROOT, 'parking_uploads', session_id)
        polygons_path = os.path.join(session_dir, 'polygons.json')

        if not os.path.exists(polygons_path):
            return Response({'polygons': []}, status=status.HTTP_200_OK)

        try:
            with open(polygons_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
        except Exception:
            return Response({'polygons': []}, status=status.HTTP_200_OK)

        polygons = data.get('polygons', data) if isinstance(data, dict) else data
        return Response({'polygons': polygons}, status=status.HTTP_200_OK)

    def post(self, request):
        session_id = request.data.get('session_id')
        video_url = request.data.get('video_url')  # ✅ NEW

        if not session_id:
            return Response(
                {'detail': 'session_id is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 🔥 NEW: Ensure video exists (Cloudinary)
        if not video_url:
            return Response(
                {'detail': 'video_url is required. Upload video first.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        polygons = request.data.get('polygons')

        # ✅ Accept string JSON
        if isinstance(polygons, str):
            try:
                polygons = json.loads(polygons)
            except json.JSONDecodeError:
                return Response({'detail': 'Invalid polygons JSON.'}, status=status.HTTP_400_BAD_REQUEST)

        if not polygons:
            return Response({'detail': 'Polygons data is required.'}, status=status.HTTP_400_BAD_REQUEST)

        if not isinstance(polygons, list):
            return Response({'detail': '"polygons" must be a list.'}, status=status.HTTP_400_BAD_REQUEST)

        # ✅ Validate structure
        for poly in polygons:
            if not isinstance(poly, list) or len(poly) < 3:
                return Response({'detail': 'Each polygon must have at least 3 points.'}, status=status.HTTP_400_BAD_REQUEST)

            for point in poly:
                if (
                    not isinstance(point, (list, tuple)) or
                    len(point) != 2 or
                    not isinstance(point[0], (int, float)) or
                    not isinstance(point[1], (int, float))
                ):
                    return Response({'detail': 'Each point must be [x, y] numeric.'}, status=status.HTTP_400_BAD_REQUEST)

        # ✅ Local storage ONLY for polygons (safe)
        session_dir = os.path.join(settings.MEDIA_ROOT, 'parking_uploads', session_id)
        os.makedirs(session_dir, exist_ok=True)

        polygons_path = os.path.join(session_dir, 'polygons.json')

        display_width = float(request.data.get('display_width') or 0)
        display_height = float(request.data.get('display_height') or 0)

        payload = {
            'polygons': polygons,
            'display_width': display_width,
            'display_height': display_height,
        }

        try:
            with open(polygons_path, 'w', encoding='utf-8') as f:
                json.dump(payload, f, indent=2)
        except OSError as e:
            return Response(
                {'detail': f'Failed to write polygons: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # Upload polygons.json to Cloudinary as a raw file
        polygon_url = None
        try:
            upload_result = cloudinary.uploader.upload(
                polygons_path,
                resource_type='raw',
                folder=f'parking_uploads/{session_id}',
                public_id='polygons',
                overwrite=True,
            )
            polygon_url = upload_result.get('secure_url')
            print(f'☁️ Polygons uploaded to Cloudinary: {polygon_url}')
        except Exception as e:
            print(f'⚠️ Cloudinary polygon upload failed (local fallback active): {e}')

        return Response({
            'success': True,
            'session_id': session_id,
            'message': 'Polygons saved successfully',
            'count': len(polygons),
            'polygon_url': polygon_url,
        }, status=status.HTTP_200_OK)
        
class ParkingSlotActivateEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsAdminUserType]

    def post(self, request, slot_id):
        slot = get_object_or_404(ParkingSlot, id=slot_id)
        slot.is_active = True
        slot.save(update_fields=['is_active'])
        notify_slot_update(slot.space_id, reason='slot_activated')
        return Response({'message': 'Parking slot activated.', 'parking_slot_id': slot.id, 'is_active': slot.is_active}, status=status.HTTP_200_OK)


class ParkingSlotDeactivateEndpoint(APIView):
    permission_classes = [IsAuthenticated, IsAdminUserType]

    def post(self, request, slot_id):
        slot = get_object_or_404(ParkingSlot, id=slot_id)
        slot.is_active = False
        slot.save(update_fields=['is_active'])
        notify_slot_update(slot.space_id, reason='slot_deactivated')
        return Response({'message': 'Parking slot deactivated.', 'parking_slot_id': slot.id, 'is_active': slot.is_active}, status=status.HTTP_200_OK)


class UserViewSet(viewsets.ModelViewSet):
    queryset = User.objects.select_related('assigned_parking_space').all().order_by('-date_joined')
    serializer_class = UserSerializer

    def get_permissions(self):
        if self.action in ['list', 'retrieve', 'create', 'update', 'partial_update', 'destroy', 'approve', 'reject']:
            return [IsAuthenticated(), IsAdminUserType()]
        return [IsAuthenticated()]

    def get_serializer_class(self):
        if self.action in ['create', 'update', 'partial_update']:
            return AdminUserSerializer
        return UserSerializer

    def get_queryset(self):
        queryset = User.objects.select_related('assigned_parking_space').all().order_by('-date_joined')
        user_type = self.request.query_params.get('user_type')
        status_filter = self.request.query_params.get('status')
        search = self.request.query_params.get('search')

        if user_type:
            queryset = queryset.filter(user_type=user_type)
        if status_filter == 'pending':
            queryset = queryset.filter(is_active=False)
        elif status_filter == 'active':
            queryset = queryset.filter(is_active=True)
        if search:
            queryset = queryset.filter(
                Q(username__icontains=search) |
                Q(email__icontains=search) |
                Q(first_name__icontains=search) |
                Q(last_name__icontains=search) |
                Q(company_name__icontains=search)
            )
        return queryset

    def perform_create(self, serializer):
        user = serializer.save()
        _notify_admins(
            "User Created",
            f"{user.username} was created as {user.user_type}.",
            'system',
        )

    @action(detail=False, methods=['get'])
    def profile(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)

    @action(detail=True, methods=['post'])
    def approve(self, request, pk=None):
        user = self.get_object()
        user.is_active = True
        user.save(update_fields=['is_active'])
        Notification.objects.create(
            user=user,
            title='Account Approved',
            message='Your ParkAI account has been approved by an administrator.',
            notification_type='system',
        )
        try:
            notify_user(user.id, 'Account Approved', 'Your ParkAI account has been approved.', 'system')
        except Exception:
            pass
        return Response(UserSerializer(user).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def reject(self, request, pk=None):
        user = self.get_object()
        reason = request.data.get('reason', '').strip() or 'Account rejected by administrator.'
        user.is_active = False
        user.save(update_fields=['is_active'])
        Notification.objects.create(user=user, title='Account Rejected', message=reason, notification_type='system')
        try:
            notify_user(user.id, 'Account Rejected', reason, 'system')
        except Exception:
            pass
        return Response(UserSerializer(user).data, status=status.HTTP_200_OK)


@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    serializer = UserRegistrationSerializer(data=request.data, context={'request': request})
    if serializer.is_valid():
        user = serializer.save()
        _notify_admins(
            "New User Registered",
            f"{user.username} registered as {user.user_type}.",
            'system',
        )
        return Response({'message': 'User registered successfully', 'user': UserSerializer(user).data}, status=status.HTTP_201_CREATED)
    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(['GET'])
@permission_classes([AllowAny])
def get_parking_spaces_for_security(request):
    """Get all active parking spaces for security personnel registration"""
    parking_spaces = ParkingSpace.objects.filter(is_active=True).select_related('vendor')
    serializer = ParkingSpaceSerializer(parking_spaces, many=True)
    return Response(serializer.data)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminUserType])
def admin_metrics(request):
    settings_obj, _ = SystemSetting.objects.get_or_create(pk=1)
    total_users = User.objects.count()
    total_customers = User.objects.filter(user_type='customer').count()
    total_vendors = User.objects.filter(user_type='vendor').count()
    total_security = User.objects.filter(user_type='security').count()
    total_admins = User.objects.filter(user_type='admin').count()

    space_counts = ParkingSpace.objects.aggregate(
        total_spaces=Count('id'),
        active_spaces=Count('id', filter=Q(is_active=True)),
        inactive_spaces=Count('id', filter=Q(is_active=False)),
    )

    slot_counts = ParkingSlot.objects.aggregate(
        total_slots=Count('id'),
        active_slots=Count('id', filter=Q(is_active=True)),
        occupied_slots=Count('id', filter=Q(is_occupied=True)),
    )

    reservation_counts = Reservation.objects.aggregate(
        total_reservations=Count('id'),
        active_reservations=Count('id', filter=Q(status__in=[
            Reservation.STATUS_PENDING_BOOKING_PAYMENT,
            Reservation.STATUS_RESERVED,
            Reservation.STATUS_CHECKED_IN,
        ])),
        completed_reservations=Count('id', filter=Q(status=Reservation.STATUS_COMPLETED)),
        pending_reservations=Count('id', filter=Q(status=Reservation.STATUS_PENDING_BOOKING_PAYMENT)),
        total_revenue=Sum('amount', filter=Q(is_paid=True)),
    )

    vendor_pending_documents = User.objects.filter(
        user_type='vendor'
    ).filter(
        Q(land_tax_receipt__isnull=True) |
        Q(license_document__isnull=True) |
        Q(government_id__isnull=True)
    ).count()
    pending_users = User.objects.filter(is_active=False).count()
    cancelled_reservations = Reservation.objects.filter(status=Reservation.STATUS_CANCELLED).count()

    total_revenue = reservation_counts['total_revenue'] or 0
    commission_amount = (Decimal(total_revenue) * settings_obj.commission_percentage / Decimal('100')).quantize(Decimal('0.01'))
    return Response({
        'total_users': total_users,
        'total_customers': total_customers,
        'total_vendors': total_vendors,
        'total_security': total_security,
        'total_admins': total_admins,
        'total_spaces': space_counts['total_spaces'],
        'active_spaces': space_counts['active_spaces'],
        'inactive_spaces': space_counts['inactive_spaces'],
        'total_slots': slot_counts['total_slots'],
        'active_slots': slot_counts['active_slots'],
        'occupied_slots': slot_counts['occupied_slots'],
        'total_reservations': reservation_counts['total_reservations'],
        'active_reservations': reservation_counts['active_reservations'],
        'completed_reservations': reservation_counts['completed_reservations'],
        'pending_reservations': reservation_counts['pending_reservations'],
        'total_revenue': f"{total_revenue:.2f}",
        'commission_percentage': f"{settings_obj.commission_percentage:.2f}",
        'commission_amount': f"{commission_amount:.2f}",
        'vendor_pending_documents': vendor_pending_documents,
        'pending_users': pending_users,
        'cancelled_reservations': cancelled_reservations,
    }, status=status.HTTP_200_OK)


@api_view(['GET', 'PATCH'])
@permission_classes([IsAuthenticated, IsAdminUserType])
def admin_settings(request):
    settings_obj, _ = SystemSetting.objects.get_or_create(pk=1)
    if request.method == 'PATCH':
        serializer = SystemSettingSerializer(settings_obj, data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_200_OK)
    return Response(SystemSettingSerializer(settings_obj).data, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def dashboard_summary(request):
    return Response(_dashboard_payload(request.user), status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated, IsAdminUserType])
def analytics_app_revenue(request):
    start, end = _analytics_date_range(request)
    payments = _filter_payments_by_date(PaymentRecord.objects.all(), start, end)
    totals = _payment_totals(payments)
    settings_obj, _ = SystemSetting.objects.get_or_create(pk=1)
    commission_amount = (
        totals['total_revenue'] * settings_obj.commission_percentage / Decimal('100')
    ).quantize(Decimal('0.01'))
    return Response({
        'date_range': {
            'start_date': start.isoformat() if start else None,
            'end_date': end.isoformat() if end else None,
        },
        'total_revenue': _money(totals['total_revenue']),
        'booking_revenue': _money(totals['booking_revenue']),
        'final_revenue': _money(totals['final_revenue']),
        'commission_percentage': _money(settings_obj.commission_percentage),
        'commission_amount': _money(commission_amount),
        'payments_count': payments.count(),
        'daily_revenue': _daily_revenue(payments),
    }, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def analytics_vendor_revenue(request, vendor_id):
    payload = _vendor_revenue_payload(request, vendor_id)
    if payload is None:
        return Response({'detail': 'You do not have permission to view this vendor revenue.'}, status=status.HTTP_403_FORBIDDEN)
    return Response(payload, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def analytics_customer_spend(request, customer_id):
    payload = _customer_spend_payload(request, customer_id)
    if payload is None:
        return Response({'detail': 'You do not have permission to view this customer spend.'}, status=status.HTTP_403_FORBIDDEN)
    return Response(payload, status=status.HTTP_200_OK)


@api_view(['GET'])
@permission_classes([IsAuthenticated])
def analytics_overview(request):
    return Response(_analytics_payload(request), status=status.HTTP_200_OK)


class ParkingSpaceViewSet(viewsets.ModelViewSet):
    queryset = ParkingSpace.objects.select_related('vendor').all()
    serializer_class = ParkingSpaceSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy', 'create_space']:
            return [IsAuthenticated(), IsVendorOrAdmin()]
        return [IsAuthenticated()]

    def get_queryset(self):
        return _visible_spaces_for_user(self.request.user)

    @action(detail=False, methods=['get'], url_path='dashboard-summary')
    def dashboard_summary(self, request):
        return Response(_dashboard_payload(request.user), status=status.HTTP_200_OK)

    @action(
        detail=False,
        methods=['post'],
        url_path='create-space',
        parser_classes=[MultiPartParser, FormParser, JSONParser],
        permission_classes=[IsAuthenticated, IsVendorOrAdmin],
    )
    def create_space(self, request):
        return _create_space_and_slots(request)


class ParkingSlotViewSet(viewsets.ModelViewSet):
    queryset = ParkingSlot.objects.select_related('space').all()
    serializer_class = ParkingSlotSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAuthenticated(), IsVendorOrAdmin()]
        return [IsAuthenticated()]

    def get_queryset(self):
        queryset = _visible_slots_for_user(self.request.user)
        space_id = self.request.query_params.get('space')

        if space_id:
            queryset = queryset.filter(space_id=space_id)

        active_reservations = Reservation.objects.filter(
            slot=OuterRef('pk'),
            status__in=ACTIVE_RESERVATION_STATUSES,
        )
        return queryset.annotate(reserved_active=Exists(active_reservations))

    @action(detail=True, methods=['post'])
    def reserve(self, request, pk=None):
        slot = self.get_object()
        return _create_pending_reservation(request.user, slot)
class ReservationViewSet(viewsets.ModelViewSet):
    queryset = Reservation.objects.select_related('slot', 'slot__space', 'user').all()
    serializer_class = ReservationSerializer

    def get_queryset(self):
        return _visible_reservations_for_user(self.request.user)

    @action(detail=False, methods=['get'], url_path='dashboard-summary')
    def dashboard_summary(self, request):
        return Response(_dashboard_payload(request.user), status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='scan')
    def scan(self, request):
        qr_data = request.data.get('qr_code', '').strip()
        if not qr_data:
            return Response({'error': 'qr_code is required.'}, status=status.HTTP_400_BAD_REQUEST)

        parts = qr_data.split('|')
        if len(parts) != 3 or parts[0] != 'BOOKING':
            return Response({'error': 'Invalid QR code format.'}, status=status.HTTP_400_BAD_REQUEST)

        reservation_id = parts[2]
        try:
            reservation = Reservation.objects.select_related('slot', 'slot__space', 'user').get(
                reservation_id=reservation_id
            )
        except Reservation.DoesNotExist:
            return Response({'error': 'Reservation not found.'}, status=status.HTTP_404_NOT_FOUND)

        if reservation.status == Reservation.STATUS_RESERVED:
            reservation.checkin_time = timezone.now()
            reservation.start_time = reservation.checkin_time
            reservation.status = Reservation.STATUS_CHECKED_IN
            reservation.save(update_fields=['checkin_time', 'start_time', 'status'])
            notify_slot_update(reservation.slot.space_id, reason='checked_in')
            if reservation.slot.space.vendor:
                msg_v = f"Vehicle {reservation.vehicle_number} checked in to {reservation.slot.space.name} ({reservation.slot.label})."
                Notification.objects.create(user=reservation.slot.space.vendor, title="Vehicle Checked In", message=msg_v, notification_type='space')
                try: notify_user(reservation.slot.space.vendor.id, "Vehicle Checked In", msg_v, 'space')
                except: pass
            return Response({
                'action': 'checkin',
                'message': 'Check-in successful.',
                'reservation': self.get_serializer(reservation).data,
            }, status=status.HTTP_200_OK)

        if reservation.status == Reservation.STATUS_CHECKED_IN:
            reservation.checkout_time = timezone.now()
            reservation.end_time = reservation.checkout_time
            duration_seconds = max((reservation.checkout_time - reservation.checkin_time).total_seconds(), 60)
            duration_hours = Decimal(str(duration_seconds / 3600)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            final_fee = (duration_hours * reservation.hourly_rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
            reservation.final_fee = final_fee
            reservation.amount = final_fee
            reservation.status = Reservation.STATUS_CHECKED_OUT
            reservation.save(update_fields=['checkout_time', 'end_time', 'final_fee', 'amount', 'status'])
            reservation.slot.is_occupied = False
            reservation.slot.save(update_fields=['is_occupied'])
            notify_slot_update(reservation.slot.space_id, reason='checked_out')
            
            # Notify vendor
            if reservation.slot.space.vendor:
                msg_v = f"Vehicle {reservation.vehicle_number} checked out of {reservation.slot.space.name} ({reservation.slot.label}). Fee: ₹{final_fee}"
                Notification.objects.create(user=reservation.slot.space.vendor, title="Vehicle Checked Out", message=msg_v, notification_type='space')
                try:
                    notify_user(reservation.slot.space.vendor.id, "Vehicle Checked Out", msg_v, 'space')
                except:
                    pass
            
            # Notify customer
            msg_c = f"Your parking session at {reservation.slot.space.name} (Slot {reservation.slot.label}) is complete. Duration: {duration_hours} hours. Total fee: ₹{final_fee}"
            Notification.objects.create(
                user=reservation.user,
                title="Parking Completed",
                message=msg_c,
                notification_type='booking'
            )
            try:
                notify_user(reservation.user.id, "Parking Completed", msg_c, 'booking')
            except:
                pass
            
            return Response({
                'action': 'checkout',
                'message': 'Check-out successful.',
                'reservation': self.get_serializer(reservation).data,
            }, status=status.HTTP_200_OK)

        return Response({
            'error': f'No action available for reservation status: {reservation.status}.',
            'reservation': self.get_serializer(reservation).data,
        }, status=status.HTTP_400_BAD_REQUEST)

    @action(detail=True, methods=['get'], url_path='qr')
    def qr(self, request, pk=None):
        reservation = self.get_object()
        if not reservation.qr_image:
            return Response({'detail': 'QR image not generated yet.'}, status=status.HTTP_404_NOT_FOUND)
        url = request.build_absolute_uri(reservation.qr_image.url)
        return Response({'reservation_id': reservation.reservation_id, 'qr_image_url': url})

    @action(detail=True, methods=['post'])
    def pay_booking(self, request, pk=None):
        reservation = self.get_object()
        if reservation.status != Reservation.STATUS_PENDING_BOOKING_PAYMENT:
            return Response({'error': 'Booking payment is not allowed at current reservation stage.'}, status=status.HTTP_400_BAD_REQUEST)

        if reservation.booking_fee_paid:
            return Response({'error': 'Booking payment already completed.'}, status=status.HTTP_400_BAD_REQUEST)

        others = Reservation.objects.filter(
            slot=reservation.slot,
            status__in=[Reservation.STATUS_RESERVED, Reservation.STATUS_CHECKED_IN],
        ).exclude(id=reservation.id)
        if others.exists():
            return Response({'error': 'Slot is no longer available for booking.'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            reservation.booking_fee_paid = True
            reservation.status = Reservation.STATUS_RESERVED
            reservation.qr_code = f"BOOKING|{reservation.slot.slot_id}|{reservation.reservation_id}"
            _generate_qr_image(reservation)
            reservation.save(update_fields=['booking_fee_paid', 'status', 'qr_code', 'qr_image'])

            reservation.slot.is_occupied = True
            reservation.slot.save(update_fields=['is_occupied'])

            user = reservation.user
            slot = reservation.slot
            PaymentRecord.objects.create(
                reservation=reservation,
                user=user,
                user_full_name=f"{user.first_name} {user.last_name}".strip() or user.username,
                user_email=user.email,
                user_phone=user.phone,
                slot_id=slot.slot_id,
                slot_label=slot.label,
                parking_space_name=slot.space.name,
                parking_space_location=slot.space.location,
                payment_type=PaymentRecord.PAYMENT_TYPE_BOOKING,
                amount=reservation.booking_fee,
                transaction_ref=f"BKG-{reservation.reservation_id}",
            )

        notify_slot_update(reservation.slot.space_id, reason='booking_paid')
        msg_c = f"Your booking for {reservation.slot.space.name} ({reservation.slot.label}) was successful."
        Notification.objects.create(user=user, title="Booking Confirmed", message=msg_c, notification_type='booking')
        try: notify_user(user.id, "Booking Confirmed", msg_c, 'booking')
        except: pass
        if reservation.slot.space.vendor:
            msg_v = f"New booking received for {reservation.slot.space.name} ({reservation.slot.label})."
            Notification.objects.create(user=reservation.slot.space.vendor, title="New Booking", message=msg_v, notification_type='booking')
            try: notify_user(reservation.slot.space.vendor.id, "New Booking", msg_v, 'booking')
            except: pass
        _notify_admins(
            "New Booking",
            f"{user.username} booked {reservation.slot.space.name} ({reservation.slot.label}).",
            'booking',
        )
        return Response(ReservationSerializer(reservation).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def checkin(self, request, pk=None):
        reservation = self.get_object()
        if reservation.status != Reservation.STATUS_RESERVED:
            return Response({'error': 'Check-in is allowed only after booking payment.'}, status=status.HTTP_400_BAD_REQUEST)

        reservation.checkin_time = timezone.now()
        reservation.start_time = reservation.checkin_time
        reservation.status = Reservation.STATUS_CHECKED_IN
        reservation.save(update_fields=['checkin_time', 'start_time', 'status'])
        notify_slot_update(reservation.slot.space_id, reason='checked_in')
        return Response(self.get_serializer(reservation).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def checkout(self, request, pk=None):
        reservation = self.get_object()
        if reservation.status != Reservation.STATUS_CHECKED_IN:
            return Response({'error': 'Checkout is allowed only after check-in.'}, status=status.HTTP_400_BAD_REQUEST)

        reservation.checkout_time = timezone.now()
        reservation.end_time = reservation.checkout_time

        duration_seconds = max((reservation.checkout_time - reservation.checkin_time).total_seconds(), 60)
        duration_hours = Decimal(str(duration_seconds / 3600)).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)
        final_fee = (duration_hours * reservation.hourly_rate).quantize(Decimal('0.01'), rounding=ROUND_HALF_UP)

        reservation.final_fee = final_fee
        reservation.amount = final_fee
        reservation.status = Reservation.STATUS_CHECKED_OUT
        reservation.save(update_fields=['checkout_time', 'end_time', 'final_fee', 'amount', 'status'])

        reservation.slot.is_occupied = False
        reservation.slot.save(update_fields=['is_occupied'])
        notify_slot_update(reservation.slot.space_id, reason='checked_out')

        return Response(self.get_serializer(reservation).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def pay_final(self, request, pk=None):
        reservation = self.get_object()
        if reservation.status != Reservation.STATUS_CHECKED_OUT:
            return Response({'error': 'Final payment is allowed only after checkout.'}, status=status.HTTP_400_BAD_REQUEST)

        if reservation.final_fee is None:
            return Response({'error': 'Final fee has not been generated yet.'}, status=status.HTTP_400_BAD_REQUEST)

        if reservation.final_fee_paid:
            return Response({'error': 'Final fee is already paid.'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            reservation.final_fee_paid = True
            reservation.is_paid = True
            reservation.amount = reservation.final_fee
            reservation.status = Reservation.STATUS_COMPLETED
            reservation.save(update_fields=['final_fee_paid', 'is_paid', 'amount', 'status'])

            user = reservation.user
            slot = reservation.slot
            PaymentRecord.objects.create(
                reservation=reservation,
                user=user,
                user_full_name=f"{user.first_name} {user.last_name}".strip() or user.username,
                user_email=user.email,
                user_phone=user.phone,
                slot_id=slot.slot_id,
                slot_label=slot.label,
                parking_space_name=slot.space.name,
                parking_space_location=slot.space.location,
                payment_type=PaymentRecord.PAYMENT_TYPE_FINAL,
                amount=reservation.final_fee,
                transaction_ref=f"FIN-{reservation.reservation_id}",
            )

        return Response(ReservationSerializer(reservation).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def cancel(self, request, pk=None):
        reservation = self.get_object()

        # Only the reservation owner can cancel
        if reservation.user_id != request.user.id and request.user.user_type not in ('admin',) and not request.user.is_staff:
            return Response({'error': 'You do not have permission to cancel this reservation.'}, status=status.HTTP_403_FORBIDDEN)

        cancellable = [
            Reservation.STATUS_PENDING_BOOKING_PAYMENT,
            Reservation.STATUS_RESERVED,
            Reservation.STATUS_CHECKED_IN,
        ]
        if reservation.status not in cancellable:
            return Response(
                {'error': f'Cannot cancel a reservation with status "{reservation.status}".'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        # Get cancellation reason from request
        cancellation_reason = request.data.get('cancellation_reason', '').strip()
        if not cancellation_reason:
            cancellation_reason = 'Cancelled by user'

        with transaction.atomic():
            # Free the slot if it was occupied
            if reservation.status in (Reservation.STATUS_RESERVED, Reservation.STATUS_CHECKED_IN):
                reservation.slot.is_occupied = False
                reservation.slot.save(update_fields=['is_occupied'])

            reservation.status = Reservation.STATUS_CANCELLED
            reservation.cancellation_reason = cancellation_reason
            reservation.save(update_fields=['status', 'cancellation_reason'])

        # Notify customer
        msg_c = f"Your reservation {reservation.reservation_id} has been cancelled. Reason: {cancellation_reason}"
        Notification.objects.create(
            user=reservation.user,
            title="Reservation Cancelled",
            message=msg_c,
            notification_type='cancellation'
        )
        try:
            notify_user(reservation.user.id, "Reservation Cancelled", msg_c, 'cancellation')
        except:
            pass

        # Notify vendor if slot exists
        if reservation.slot and reservation.slot.space.vendor:
            msg_v = f"Reservation {reservation.reservation_id} for slot {reservation.slot.label} has been cancelled. Reason: {cancellation_reason}"
            Notification.objects.create(
                user=reservation.slot.space.vendor,
                title="Reservation Cancelled",
                message=msg_v,
                notification_type='cancellation'
            )
            try:
                notify_user(reservation.slot.space.vendor.id, "Reservation Cancelled", msg_v, 'cancellation')
            except:
                pass

        _notify_admins(
            "Booking Cancelled",
            f"Reservation {reservation.reservation_id} was cancelled. Reason: {cancellation_reason}",
            'cancellation',
        )
        notify_slot_update(reservation.slot.space_id, reason='reservation_cancelled')
        return Response(ReservationSerializer(reservation).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def pay(self, request, pk=None):
        # Backward-compatible alias for booking payment.
        return self.pay_booking(request, pk)


def _get_or_create_wallet(user):
    wallet, _ = Wallet.objects.get_or_create(user=user)
    return wallet


class WalletViewSet(viewsets.GenericViewSet):
    permission_classes = [IsAuthenticated]
    serializer_class = WalletSerializer

    def _wallet(self):
        return _get_or_create_wallet(self.request.user)

    @action(detail=False, methods=['get'])
    def me(self, request):
        return Response(WalletSerializer(self._wallet()).data)

    @action(detail=False, methods=['post'], url_path='topup')
    def topup(self, request):
        try:
            amount = Decimal(str(request.data.get('amount', '0'))).quantize(Decimal('0.01'))
        except Exception:
            return Response({'error': 'Invalid amount.'}, status=status.HTTP_400_BAD_REQUEST)

        if amount <= 0:
            return Response({'error': 'Amount must be greater than zero.'}, status=status.HTTP_400_BAD_REQUEST)
        if amount > Decimal('50000'):
            return Response({'error': 'Maximum top-up per transaction is Rs 50,000.'}, status=status.HTTP_400_BAD_REQUEST)

        with transaction.atomic():
            wallet = _get_or_create_wallet(request.user)
            wallet.balance += amount
            wallet.save(update_fields=['balance', 'updated_at'])
            WalletTransaction.objects.create(
                wallet=wallet,
                transaction_type=WalletTransaction.TYPE_TOPUP,
                amount=amount,
                description=f'Wallet top-up of Rs {amount}',
            )

        msg_c = f"Your wallet was successfully recharged with Rs {amount}."
        Notification.objects.create(user=request.user, title="Wallet Recharge", message=msg_c, notification_type='wallet')
        try: notify_user(request.user.id, "Wallet Recharge", msg_c, 'wallet')
        except: pass

        return Response(WalletSerializer(wallet).data, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='pay-booking/(?P<reservation_pk>[^/.]+)')
    def pay_booking_wallet(self, request, reservation_pk=None):
        reservation = get_object_or_404(Reservation, pk=reservation_pk, user=request.user)

        if reservation.status != Reservation.STATUS_PENDING_BOOKING_PAYMENT:
            return Response({'error': 'Booking payment not applicable at this stage.'}, status=status.HTTP_400_BAD_REQUEST)
        if reservation.booking_fee_paid:
            return Response({'error': 'Booking fee already paid.'}, status=status.HTTP_400_BAD_REQUEST)

        others = Reservation.objects.filter(
            slot=reservation.slot,
            status__in=[Reservation.STATUS_RESERVED, Reservation.STATUS_CHECKED_IN],
        ).exclude(id=reservation.id)
        if others.exists():
            return Response({'error': 'Slot is no longer available.'}, status=status.HTTP_400_BAD_REQUEST)

        wallet = _get_or_create_wallet(request.user)
        fee = reservation.booking_fee
        if wallet.balance < fee:
            return Response(
                {'error': f'Insufficient wallet balance. Required Rs {fee}, available Rs {wallet.balance}.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            wallet.balance -= fee
            wallet.save(update_fields=['balance', 'updated_at'])
            WalletTransaction.objects.create(
                wallet=wallet,
                transaction_type=WalletTransaction.TYPE_DEBIT,
                amount=fee,
                description=f'Booking fee for reservation {reservation.reservation_id}',
                reservation=reservation,
            )

            reservation.booking_fee_paid = True
            reservation.status = Reservation.STATUS_RESERVED
            reservation.qr_code = f"BOOKING|{reservation.slot.slot_id}|{reservation.reservation_id}"
            _generate_qr_image(reservation)
            reservation.save(update_fields=['booking_fee_paid', 'status', 'qr_code', 'qr_image'])

            reservation.slot.is_occupied = True
            reservation.slot.save(update_fields=['is_occupied'])

            user = reservation.user
            slot = reservation.slot
            PaymentRecord.objects.create(
                reservation=reservation,
                user=user,
                user_full_name=f"{user.first_name} {user.last_name}".strip() or user.username,
                user_email=user.email,
                user_phone=user.phone,
                slot_id=slot.slot_id,
                slot_label=slot.label,
                parking_space_name=slot.space.name,
                parking_space_location=slot.space.location,
                payment_type=PaymentRecord.PAYMENT_TYPE_BOOKING,
                amount=fee,
                transaction_ref=f"WBKG-{reservation.reservation_id}",
            )


        notify_slot_update(reservation.slot.space_id, reason='booking_paid_wallet')
        msg_c = f"Booking confirmed! Rs {fee} deducted from your wallet."
        Notification.objects.create(user=request.user, title="Booking Paid (Wallet)", message=msg_c, notification_type='wallet')
        try: notify_user(request.user.id, "Booking Paid (Wallet)", msg_c, 'wallet')
        except: pass
        if reservation.slot.space.vendor:
            msg_v = f"New booking received for {reservation.slot.space.name} ({reservation.slot.label}). Paid via wallet."
            Notification.objects.create(user=reservation.slot.space.vendor, title="New Booking", message=msg_v, notification_type='booking')
            try: notify_user(reservation.slot.space.vendor.id, "New Booking", msg_v, 'booking')
            except: pass
        _notify_admins(
            "New Booking",
            f"{request.user.username} booked {reservation.slot.space.name} ({reservation.slot.label}) using wallet.",
            'booking',
        )
        
        return Response(ReservationSerializer(reservation).data, status=status.HTTP_200_OK)

    @action(detail=False, methods=['post'], url_path='pay-final/(?P<reservation_pk>[^/.]+)')
    def pay_final_wallet(self, request, reservation_pk=None):
        reservation = get_object_or_404(Reservation, pk=reservation_pk, user=request.user)

        if reservation.status != Reservation.STATUS_CHECKED_OUT:
            return Response({'error': 'Final payment only allowed after checkout.'}, status=status.HTTP_400_BAD_REQUEST)
        if reservation.final_fee is None:
            return Response({'error': 'Final fee not yet calculated.'}, status=status.HTTP_400_BAD_REQUEST)
        if reservation.final_fee_paid:
            return Response({'error': 'Final fee already paid.'}, status=status.HTTP_400_BAD_REQUEST)

        wallet = _get_or_create_wallet(request.user)
        fee = reservation.final_fee
        if wallet.balance < fee:
            return Response(
                {'error': f'Insufficient wallet balance. Required Rs {fee}, available Rs {wallet.balance}.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            wallet.balance -= fee
            wallet.save(update_fields=['balance', 'updated_at'])
            WalletTransaction.objects.create(
                wallet=wallet,
                transaction_type=WalletTransaction.TYPE_DEBIT,
                amount=fee,
                description=f'Final fee for reservation {reservation.reservation_id}',
                reservation=reservation,
            )

            reservation.final_fee_paid = True
            reservation.is_paid = True
            reservation.amount = fee
            reservation.status = Reservation.STATUS_COMPLETED
            reservation.save(update_fields=['final_fee_paid', 'is_paid', 'amount', 'status'])

            user = reservation.user
            slot = reservation.slot
            PaymentRecord.objects.create(
                reservation=reservation,
                user=user,
                user_full_name=f"{user.first_name} {user.last_name}".strip() or user.username,
                user_email=user.email,
                user_phone=user.phone,
                slot_id=slot.slot_id,
                slot_label=slot.label,
                parking_space_name=slot.space.name,
                parking_space_location=slot.space.location,
                payment_type=PaymentRecord.PAYMENT_TYPE_FINAL,
                amount=fee,
                transaction_ref=f"WFIN-{reservation.reservation_id}",
            )

        return Response(ReservationSerializer(reservation).data, status=status.HTTP_200_OK)


class GateViewSet(viewsets.ModelViewSet):
    queryset = Gate.objects.all()
    serializer_class = GateSerializer

    @action(detail=True, methods=['post'])
    def access(self, request, pk=None):
        gate = self.get_object()
        gate.last_access = timezone.now()
        gate.access_count += 1
        gate.save()

        serializer = self.get_serializer(gate)
        return Response(serializer.data)


class CCTVFeedViewSet(viewsets.ModelViewSet):
    queryset = CCTVFeed.objects.all()
    serializer_class = CCTVFeedSerializer


class VehicleLogViewSet(viewsets.ModelViewSet):
    queryset = VehicleLog.objects.select_related('space', 'slot', 'user').all()
    serializer_class = VehicleLogSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        queryset = VehicleLog.objects.select_related('space', 'slot', 'user').all().order_by('-check_in_time')
        user = self.request.user

        # Admin can see all logs
        if user.user_type == 'admin' or user.is_staff:
            return queryset

        # Security and vendor can see logs for their assigned spaces
        if user.user_type == 'security':
            space_id = user.assigned_parking_space_id
            if space_id:
                return queryset.filter(space_id=space_id)
            return VehicleLog.objects.none()

        if user.user_type == 'vendor':
            return queryset.filter(space__vendor=user)

        # Customers can only see their own logs
        return queryset.filter(user=user)

    @action(detail=False, methods=['get'], url_path='space/(?P<space_id>[^/.]+)')
    def by_space(self, request, space_id=None):
        """Get vehicle logs for a specific parking space"""
        queryset = self.get_queryset().filter(space_id=space_id)
        paginator = self.paginator if self.paginator else None
        if paginator:
            page = paginator.paginate_queryset(queryset, request)
            serializer = self.get_serializer(page, many=True)
            return paginator.get_paginated_response(serializer.data)
        serializer = self.get_serializer(queryset, many=True)
        return Response(serializer.data)

    @action(detail=False, methods=['post'])
    def check_in(self, request):
        """Record vehicle check-in"""
        serializer = self.get_serializer(data=request.data, partial=True)
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(serializer.data, status=status.HTTP_201_CREATED)

    @action(detail=True, methods=['post'])
    def check_out(self, request, pk=None):
        """Record vehicle check-out"""
        log = self.get_object()
        log.check_out_time = timezone.now()
        log.save(update_fields=['check_out_time', 'duration_minutes'])
        serializer = self.get_serializer(log)
        return Response(serializer.data)


class VehicleImageProcessEndpoint(APIView):
    """Process vehicle image to extract vehicle number and type using YOLO"""
    permission_classes = [IsAuthenticated]
    parser_classes = (MultiPartParser, FormParser)

    def post(self, request):
        image_file = request.FILES.get('image')
        if not image_file:
            return Response({'error': 'No image file provided'}, status=status.HTTP_400_BAD_REQUEST)

        try:
            import cv2
            import numpy as np
            from YOLO.process_image import process_vehicle_image
        except ImportError as e:
            return Response({'error': f'Missing dependency: {e}'}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)

        nparr = np.frombuffer(image_file.read(), np.uint8)
        frame = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if frame is None:
            return Response({'error': 'Invalid image format'}, status=status.HTTP_400_BAD_REQUEST)

        result = process_vehicle_image(frame)

        return Response({
            'vehicle_number': result['vehicle_number'],
            'vehicle_type': result['vehicle_type'],
            'debug': result.get('debug', ''),
            'status': 'success'
        })


class CustomTokenObtainPairView(TokenObtainPairView):
    serializer_class = CustomTokenObtainPairSerializer


class PaymentRecordViewSet(viewsets.ReadOnlyModelViewSet):
    """Read-only endpoint. Customers see their own payments; admin/vendor see all."""
    serializer_class = PaymentRecordSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        user = self.request.user
        qs = PaymentRecord.objects.select_related('reservation', 'user').all()
        if user.user_type in ('admin',) or user.is_staff:
            return qs
        if user.user_type == 'vendor':
            return qs.filter(reservation__slot__space__vendor=user)
        if user.user_type == 'security':
            if user.assigned_parking_space_id:
                return qs.filter(reservation__slot__space_id=user.assigned_parking_space_id)
            return qs.none()
        return qs.filter(user=user)

from .models import Notification
from .serializers import NotificationSerializer

class NotificationViewSet(viewsets.ModelViewSet):
    serializer_class = NotificationSerializer
    permission_classes = [IsAuthenticated]

    def get_queryset(self):
        return Notification.objects.filter(user=self.request.user)

    @action(detail=True, methods=['post'])
    def mark_read(self, request, pk=None):
        notification = self.get_object()
        notification.is_read = True
        notification.save(update_fields=['is_read'])
        return Response({'status': 'Notification marked as read'})


class FAQViewSet(viewsets.ModelViewSet):
    queryset = FAQ.objects.filter(is_active=True)
    serializer_class = FAQSerializer
    permission_classes = [AllowAny]  # Allow anyone to read FAQs


class ChatbotAPIView(APIView):
    permission_classes = [AllowAny]  # Allow anyone to use chatbot

    def post(self, request):
        message = request.data.get('message', '').strip()
        if not message:
            return Response({'error': 'Message is required'}, status=status.HTTP_400_BAD_REQUEST)

        # Find FAQ that matches the message (case insensitive)
        faq = FAQ.objects.filter(
            is_active=True,
            question__iexact=message
        ).first()

        if faq:
            return Response({
                'type': 'faq',
                'question': faq.question,
                'answer': faq.answer
            })
        else:
            return Response({
                'type': 'contact',
                'message': "I'm sorry, I couldn't find an answer to your question. Please contact us for more help.",
                'contact_suggestion': True
            })









