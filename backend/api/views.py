from decimal import Decimal, ROUND_HALF_UP
from datetime import timedelta
import io
import json
import os
import uuid
from concurrent.futures import ThreadPoolExecutor

from django.conf import settings
from django.core.files.base import ContentFile
from django.db import transaction
from django.db.models import Count, Q, Sum
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework import status, viewsets
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.parsers import FormParser, JSONParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView
from rest_framework_simplejwt.views import TokenObtainPairView
from rest_framework import status
from concurrent.futures import ThreadPoolExecutor
import qrcode

from .models import CCTVFeed, Gate, ParkingSlot, ParkingSpace, Reservation, User, VehicleLog
from .permissions import IsAdminUserType, IsVendorOrAdmin
from .realtime import notify_slot_update
from .serializers import (
    CCTVFeedSerializer,
    CustomTokenObtainPairSerializer,
    GateSerializer,
    ParkingSlotSerializer,
    ParkingSpaceCreateSerializer,
    ParkingSpaceSerializer,
    ReservationSerializer,
    UserRegistrationSerializer,
    UserSerializer,
    VehicleLogSerializer,
)

BOOKING_FEE = Decimal('1.00')
HOURLY_RATE = Decimal('2.40')


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


def _create_pending_reservation(user, slot, vehicle_number=None, vehicle_type=None):
    if user.user_type != 'customer':
        return Response({'detail': 'Only customers can create a booking reservation.'}, status=status.HTTP_403_FORBIDDEN)

    if not slot.space.is_active:
        return Response({'detail': 'Parking space is not active.'}, status=status.HTTP_400_BAD_REQUEST)

    if not slot.is_active:
        return Response({'detail': 'Parking slot is not active.'}, status=status.HTTP_400_BAD_REQUEST)

    if slot.is_occupied or _active_booking_exists(slot):
        return Response({'detail': 'Slot is not available for booking.'}, status=status.HTTP_400_BAD_REQUEST)

    now = timezone.now()
    reservation = Reservation.objects.create(
        user=user,
        slot=slot,
        reservation_id=f"PKG{now.strftime('%Y%m%d%H%M%S')}{user.id}{slot.id}",
        start_time=now,
        end_time=now,
        amount=Decimal('0.00'),
        is_paid=False,
        booking_fee=BOOKING_FEE,
        booking_fee_paid=False,
        hourly_rate=HOURLY_RATE,
        vehicle_number=vehicle_number or '',
        vehicle_type=vehicle_type or '',
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
        
        # Validate vehicle type
        valid_vehicle_types = ['suv', 'pickup', 'sedan', 'hatchback']
        if vehicle_type and vehicle_type not in valid_vehicle_types:
            return Response({'detail': 'Invalid vehicle type. Must be one of: suv, pickup, sedan, hatchback.'}, status=status.HTTP_400_BAD_REQUEST)
        
        return _create_pending_reservation(request.user, slot, vehicle_number, vehicle_type)


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

        # ✅ Generate unique session ID
        session_id = uuid.uuid4().hex

        # ✅ Base upload directory
        base_upload_dir = os.path.join(settings.MEDIA_ROOT, 'parking_uploads')
        os.makedirs(base_upload_dir, exist_ok=True)

        # ✅ Create session folder
        session_dir = os.path.join(base_upload_dir, session_id)
        os.makedirs(session_dir, exist_ok=True)

        # ✅ Preserve original extension
        ext = os.path.splitext(file_obj.name)[1] or ".mp4"

        video_filename = f"input{ext}"
        video_path = os.path.join(session_dir, video_filename)

        print("📁 Saving video to:", video_path)

        try:
            with open(video_path, 'wb+') as f:
                for chunk in file_obj.chunks():
                    f.write(chunk)
        except OSError as e:
            return Response(
                {'detail': f'Failed to save video: {str(e)}'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # ✅ Get file size safely
        size = os.path.getsize(video_path)

        return Response({
            'success': True,
            'session_id': session_id,
            'video_path': f"parking_uploads/{session_id}/{video_filename}",
            'size': size
        }, status=status.HTTP_200_OK)





class ParkingLotRunAnalysisEndpoint(APIView):
    """Run YOLO analysis using session_id (media folder based)."""
    permission_classes = []  # add IsAuthenticated if needed

    def post(self, request):
        session_id = request.data.get('session_id') or request.POST.get('session_id')

        if not session_id:
            return Response(
                {'success': False, 'error': 'session_id is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 📂 Session directory
        session_dir = os.path.join(settings.MEDIA_ROOT, 'parking_uploads', session_id)

        print("\n🚀 RUN ANALYSIS START")
        print("📌 Session ID:", session_id)
        print("📂 Session dir:", session_dir)

        if not os.path.exists(session_dir):
            return Response(
                {'success': False, 'error': 'Session folder not found.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        files = os.listdir(session_dir)
        print("📂 Files in session:", files)

        # ✅ Check video exists
        video_exists = any(f.lower().endswith(('.mp4', '.avi', '.mov')) for f in files)
        if not video_exists:
            return Response(
                {'success': False, 'error': 'No video file found in session.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # ✅ Check polygons
        if 'polygons.json' not in files:
            return Response(
                {'success': False, 'error': 'polygons.json not found.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        try:
            from .process_video import process_video

            print("⚙️ Starting YOLO processing...")

            # 🚀 Run processing (thread)
            with ThreadPoolExecutor(max_workers=1) as executor:
                future = executor.submit(process_video, session_id)
                result = future.result()

            print("📦 PROCESS RESULT:", result)

        except Exception as exc:
            import traceback
            traceback.print_exc()

            return Response(
                {'success': False, 'error': str(exc)},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        # ❌ If processing failed
        if not result.get("success"):
            return Response(result, status=status.HTTP_400_BAD_REQUEST)

        # ✅ 🔥 FIX: Get output directly from process_video
        output_path = result.get("output_path")
        output_url = result.get("output_url")

        print("📤 Output path:", output_path)
        print("🌐 Output URL:", output_url)

        # Extra safety (optional)
        if not output_path or not os.path.exists(output_path):
            return Response(
                {'success': False, 'error': 'Output video not found after processing.'},
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        return Response({
            'success': True,
            'occupied': result.get('occupied', 0),
            'free': result.get('free', 0),
            'total': result.get('total', 0),
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
        except (json.JSONDecodeError, OSError, ValueError):
            return Response({'polygons': []}, status=status.HTTP_200_OK)

        polygons = data.get('polygons', data) if isinstance(data, dict) else data
        return Response({'polygons': polygons}, status=status.HTTP_200_OK)

    def post(self, request):
        session_id = request.data.get('session_id')

        if not session_id:
            return Response(
                {'detail': 'session_id is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        polygons = request.data.get('polygons')

        # ✅ Accept string JSON
        if isinstance(polygons, str):
            try:
                polygons = json.loads(polygons)
            except json.JSONDecodeError:
                return Response(
                    {'detail': 'Invalid polygons JSON.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

        if not polygons:
            return Response(
                {'detail': 'Polygons data is required.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        if not isinstance(polygons, list):
            return Response(
                {'detail': '"polygons" must be a list.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # ✅ Validate structure
        for poly in polygons:
            if not isinstance(poly, list) or len(poly) < 3:
                return Response(
                    {'detail': 'Each polygon must have at least 3 points.'},
                    status=status.HTTP_400_BAD_REQUEST
                )

            for point in poly:
                if (
                    not isinstance(point, (list, tuple)) or
                    len(point) != 2 or
                    not isinstance(point[0], (int, float)) or
                    not isinstance(point[1], (int, float))
                ):
                    return Response(
                        {'detail': 'Each point must be [x, y] numeric.'},
                        status=status.HTTP_400_BAD_REQUEST
                    )

        # ✅ Session directory
        session_dir = os.path.join(settings.MEDIA_ROOT, 'parking_uploads', session_id)

        # 🔥 IMPORTANT: Ensure session exists
        if not os.path.exists(session_dir):
            return Response(
                {'detail': 'Session not found. Please upload video first.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        # 🔥 IMPORTANT: Ensure video exists
        video_exists = any(
            f.startswith("input") for f in os.listdir(session_dir)
        )

        if not video_exists:
            return Response(
                {'detail': 'Video not found in session. Save video first.'},
                status=status.HTTP_400_BAD_REQUEST
            )

        polygons_path = os.path.join(session_dir, 'polygons.json')

        print("📁 Saving polygons to:", polygons_path)

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

        return Response({
            'success': True,
            'session_id': session_id,
            'message': 'Polygons saved successfully',
            'path': f'parking_uploads/{session_id}/polygons.json',
            'count': len(polygons)
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
    queryset = User.objects.all()
    serializer_class = UserSerializer

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAuthenticated(), IsAdminUserType()]
        return [IsAuthenticated()]

    def get_serializer_class(self):
        if self.action == 'create':
            return UserRegistrationSerializer
        return UserSerializer

    @action(detail=False, methods=['get'])
    def profile(self, request):
        serializer = self.get_serializer(request.user)
        return Response(serializer.data)


@api_view(['POST'])
@permission_classes([AllowAny])
def register_user(request):
    serializer = UserRegistrationSerializer(data=request.data, context={'request': request})
    if serializer.is_valid():
        user = serializer.save()
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

    total_revenue = reservation_counts['total_revenue'] or 0
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
        'vendor_pending_documents': vendor_pending_documents,
    }, status=status.HTTP_200_OK)


class ParkingSpaceViewSet(viewsets.ModelViewSet):
    queryset = ParkingSpace.objects.all()
    serializer_class = ParkingSpaceSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy', 'create_space']:
            return [IsAuthenticated(), IsVendorOrAdmin()]
        return [IsAuthenticated()]

    def get_queryset(self):
        queryset = ParkingSpace.objects.all()
        user = self.request.user

        if user.user_type == 'vendor':
            return queryset.filter(vendor=user)

        if user.user_type == 'admin' or user.is_staff:
            return queryset

        return queryset.filter(is_active=True)

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
    queryset = ParkingSlot.objects.all()
    serializer_class = ParkingSlotSerializer
    permission_classes = [IsAuthenticated]

    def get_permissions(self):
        if self.action in ['create', 'update', 'partial_update', 'destroy']:
            return [IsAuthenticated(), IsVendorOrAdmin()]
        return [IsAuthenticated()]

    def get_queryset(self):
        queryset = ParkingSlot.objects.select_related('space').all()
        user = self.request.user
        space_id = self.request.query_params.get('space')

        if space_id:
            queryset = queryset.filter(space_id=space_id)

        if user.user_type == 'vendor':
            return queryset.filter(space__vendor=user)

        if user.user_type == 'admin' or user.is_staff:
            return queryset

        return queryset.filter(space__is_active=True, is_active=True)

    @action(detail=True, methods=['post'])
    def reserve(self, request, pk=None):
        slot = self.get_object()
        return _create_pending_reservation(request.user, slot)
class ReservationViewSet(viewsets.ModelViewSet):
    queryset = Reservation.objects.all()
    serializer_class = ReservationSerializer

    def get_queryset(self):
        user = self.request.user
        queryset = Reservation.objects.select_related('slot', 'slot__space', 'user').all()

        if user.user_type == 'admin' or user.is_staff:
            return queryset

        if user.user_type == 'vendor':
            return queryset.filter(slot__space__vendor=user)

        return queryset.filter(user=user)

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

        if reservation.slot.is_occupied or _active_booking_exists(reservation.slot):
            # allow current reservation itself
            others = Reservation.objects.filter(
                slot=reservation.slot,
                status__in=[Reservation.STATUS_RESERVED, Reservation.STATUS_CHECKED_IN],
            ).exclude(id=reservation.id)
            if others.exists():
                return Response({'error': 'Slot is no longer available for booking.'}, status=status.HTTP_400_BAD_REQUEST)

        reservation.booking_fee_paid = True
        reservation.status = Reservation.STATUS_RESERVED
        reservation.qr_code = f"BOOKING|{reservation.slot.slot_id}|{reservation.reservation_id}"
        _generate_qr_image(reservation)
        reservation.save(update_fields=['booking_fee_paid', 'status', 'qr_code', 'qr_image'])

        reservation.slot.is_occupied = True
        reservation.slot.save(update_fields=['is_occupied'])
        notify_slot_update(reservation.slot.space_id, reason='booking_paid')

        return Response(self.get_serializer(reservation).data, status=status.HTTP_200_OK)

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

        reservation.final_fee_paid = True
        reservation.is_paid = True
        reservation.status = Reservation.STATUS_COMPLETED
        reservation.save(update_fields=['final_fee_paid', 'is_paid', 'status'])

        return Response(self.get_serializer(reservation).data, status=status.HTTP_200_OK)

    @action(detail=True, methods=['post'])
    def pay(self, request, pk=None):
        # Backward-compatible alias for booking payment.
        return self.pay_booking(request, pk)


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









