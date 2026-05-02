from decimal import Decimal
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

from .models import CCTVFeed, Gate, ParkingSlot, ParkingSpace, PaymentRecord, Reservation, SystemSetting, User, VehicleLog, Wallet, WalletTransaction, Notification, FAQ


class UserSerializer(serializers.ModelSerializer):
    assigned_parking_space_id = serializers.IntegerField(source='assigned_parking_space.id', read_only=True)
    assigned_parking_space_name = serializers.CharField(source='assigned_parking_space.name', read_only=True)
    full_name = serializers.SerializerMethodField()
    vendor_documents_complete = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id',
            'username',
            'email',
            'full_name',
            'first_name',
            'last_name',
            'phone',
            'user_type',
            'address',
            'company_name',
            'land_owner_name',
            'land_tax_receipt',
            'license_document',
            'government_id',
            'vendor_documents_complete',
            'assigned_parking_space_id',
            'assigned_parking_space_name',
            'is_active',
            'is_staff',
        ]
        read_only_fields = ['id', 'assigned_parking_space_id', 'assigned_parking_space_name']

    def get_full_name(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip() or obj.username

    def get_vendor_documents_complete(self, obj):
        if obj.user_type != 'vendor':
            return None
        return bool(obj.land_tax_receipt and obj.license_document and obj.government_id)


class AdminUserSerializer(serializers.ModelSerializer):
    full_name = serializers.CharField(write_only=True, required=False, allow_blank=True)
    password = serializers.CharField(write_only=True, required=False, min_length=6, allow_blank=True)
    assigned_parking_space = serializers.PrimaryKeyRelatedField(
        queryset=ParkingSpace.objects.all(),
        required=False,
        allow_null=True,
    )
    assigned_parking_space_id = serializers.IntegerField(source='assigned_parking_space.id', read_only=True)
    assigned_parking_space_name = serializers.CharField(source='assigned_parking_space.name', read_only=True)
    display_name = serializers.SerializerMethodField()
    vendor_documents_complete = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            'id', 'username', 'email', 'full_name', 'display_name', 'first_name', 'last_name',
            'phone', 'user_type', 'password', 'is_active', 'is_staff',
            'assigned_parking_space', 'assigned_parking_space_id', 'assigned_parking_space_name',
            'address', 'company_name', 'land_owner_name',
            'land_tax_receipt', 'license_document', 'government_id', 'vendor_documents_complete',
        ]
        read_only_fields = ['id', 'assigned_parking_space_id', 'assigned_parking_space_name']

    def get_display_name(self, obj):
        return f"{obj.first_name} {obj.last_name}".strip() or obj.username

    def get_vendor_documents_complete(self, obj):
        if obj.user_type != 'vendor':
            return None
        return bool(obj.land_tax_receipt and obj.license_document and obj.government_id)

    def validate(self, attrs):
        user_type = attrs.get('user_type', getattr(self.instance, 'user_type', 'customer'))
        assigned_space = attrs.get('assigned_parking_space', getattr(self.instance, 'assigned_parking_space', None))
        if user_type == 'security' and assigned_space is None:
            raise serializers.ValidationError({'assigned_parking_space': 'Security personnel must be assigned to a parking space.'})
        if user_type != 'security' and attrs.get('assigned_parking_space') is not None:
            raise serializers.ValidationError({'assigned_parking_space': 'Only security personnel can be assigned to parking spaces.'})
        return attrs

    def _apply_full_name(self, instance, full_name):
        if full_name is None:
            return
        name_parts = full_name.strip().split(' ', 1)
        instance.first_name = name_parts[0] if name_parts and name_parts[0] else ''
        instance.last_name = name_parts[1] if len(name_parts) > 1 else ''

    def create(self, validated_data):
        full_name = validated_data.pop('full_name', '')
        password = validated_data.pop('password', None)
        user = User(**validated_data)
        self._apply_full_name(user, full_name)
        if password:
            user.set_password(password)
        else:
            user.set_unusable_password()
        user.save()
        return user

    def update(self, instance, validated_data):
        full_name = validated_data.pop('full_name', None)
        password = validated_data.pop('password', None)
        self._apply_full_name(instance, full_name)
        for attr, value in validated_data.items():
            setattr(instance, attr, value)
        if password:
            instance.set_password(password)
        instance.save()
        return instance


class UserRegistrationSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    password_confirm = serializers.CharField(write_only=True)
    full_name = serializers.CharField(write_only=True)
    is_active = serializers.BooleanField(default=False)
    assigned_parking_space = serializers.IntegerField(required=False, allow_null=True)

    # Vendor-specific fields
    address = serializers.CharField(required=False, allow_blank=True)
    company_name = serializers.CharField(required=False, allow_blank=True)
    land_owner_name = serializers.CharField(required=False, allow_blank=True)
    land_tax_receipt = serializers.FileField(required=False, allow_null=True)
    license_document = serializers.FileField(required=False, allow_null=True)
    government_id = serializers.FileField(required=False, allow_null=True)

    class Meta:
        model = User
        fields = [
            'username', 'email', 'full_name', 'phone', 'user_type', 'password', 'password_confirm', 'is_active',
            'assigned_parking_space', 'address', 'company_name', 'land_owner_name',
            'land_tax_receipt', 'license_document', 'government_id'
        ]

    def validate(self, data):
        if data['password'] != data['password_confirm']:
            raise serializers.ValidationError('Passwords do not match')

        user_type = data.get('user_type', 'customer')
        assigned_parking_space = data.get('assigned_parking_space')

        if user_type == 'security':
            if assigned_parking_space is None:
                raise serializers.ValidationError('Security personnel must be assigned to a parking space')
            # Validate that the parking space exists and is active
            try:
                from .models import ParkingSpace
                parking_space = ParkingSpace.objects.get(id=assigned_parking_space, is_active=True)
            except ParkingSpace.DoesNotExist:
                raise serializers.ValidationError('Invalid or inactive parking space selected')
        elif assigned_parking_space is not None:
            raise serializers.ValidationError('Only security personnel can be assigned to parking spaces')

        # Validate vendor-specific fields
        if user_type == 'vendor':
            if not data.get('address', '').strip():
                raise serializers.ValidationError('Address is required for vendors')
            if not data.get('company_name', '').strip():
                raise serializers.ValidationError('Company name is required for vendors')
            if not data.get('land_owner_name', '').strip():
                raise serializers.ValidationError('Land owner name is required for vendors')

        return data

    def create(self, validated_data):
        validated_data.pop('password_confirm')
        full_name = validated_data.pop('full_name')
        assigned_parking_space_id = validated_data.pop('assigned_parking_space', None)

        # Extract vendor-specific fields
        address = validated_data.pop('address', '')
        company_name = validated_data.pop('company_name', '')
        land_owner_name = validated_data.pop('land_owner_name', '')
        land_tax_receipt = validated_data.pop('land_tax_receipt', None)
        license_document = validated_data.pop('license_document', None)
        government_id = validated_data.pop('government_id', None)

        name_parts = full_name.strip().split(' ', 1)
        first_name = name_parts[0]
        last_name = name_parts[1] if len(name_parts) > 1 else ''

        is_active = validated_data.pop('is_active', False)
        request = self.context.get('request')
        if not request or not request.user.is_authenticated or request.user.user_type != 'admin':
            is_active = False

        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            first_name=first_name,
            last_name=last_name,
            phone=validated_data.get('phone', ''),
            user_type=validated_data.get('user_type', 'customer'),
            password=validated_data['password'],
            is_active=is_active,
            # Vendor-specific fields
            address=address,
            company_name=company_name,
            land_owner_name=land_owner_name,
            land_tax_receipt=land_tax_receipt,
            license_document=license_document,
            government_id=government_id,
        )

        if assigned_parking_space_id:
            from .models import ParkingSpace
            parking_space = ParkingSpace.objects.get(id=assigned_parking_space_id)
            user.assigned_parking_space = parking_space
            user.save()

        return user


class ParkingSpaceSerializer(serializers.ModelSerializer):
    vendor_name = serializers.CharField(source='vendor.username', read_only=True)

    class Meta:
        model = ParkingSpace
        fields = [
            'id', 'name', 'vendor', 'vendor_name', 'address', 'location',
            'total_slots', 'open_time', 'close_time', 'google_map_link',
            'parking_image', 'cctv_video', 'is_active',
            'hourly_rate', 'booking_fee',
            'created_at',
        ]


class ParkingSpaceCreateSerializer(serializers.ModelSerializer):
    number_of_slots = serializers.IntegerField(min_value=1, write_only=True)
    location = serializers.CharField()

    class Meta:
        model = ParkingSpace
        fields = [
            'id',
            'name',
            'number_of_slots',
            'location',
            'open_time',
            'close_time',
            'hourly_rate',
            'booking_fee',
            'google_map_link',
            'parking_image',
            'cctv_video',
            'vendor',
            'total_slots',
            'address',
            'created_at',
        ]
        read_only_fields = ['id', 'total_slots', 'address', 'created_at']
        extra_kwargs = {'vendor': {'required': False}}

    def validate(self, attrs):
        open_time = attrs.get('open_time')
        close_time = attrs.get('close_time')
        if open_time and close_time and open_time == close_time:
            raise serializers.ValidationError({'close_time': 'Close time must be different from open time.'})
        return attrs


class SystemSettingSerializer(serializers.ModelSerializer):
    class Meta:
        model = SystemSetting
        fields = ['commission_percentage', 'updated_at']


class ParkingSlotSerializer(serializers.ModelSerializer):
    space_name = serializers.CharField(source='space.name', read_only=True)
    is_reserved = serializers.SerializerMethodField()

    class Meta:
        model = ParkingSlot
        fields = ['id', 'space', 'space_name', 'slot_id', 'label', 'is_occupied', 'is_reserved', 'is_active', 'created_at']

    def get_is_reserved(self, obj):
        annotated_value = getattr(obj, 'reserved_active', None)
        if annotated_value is not None:
            return bool(annotated_value)

        return Reservation.objects.filter(
            slot=obj,
            status__in=[
                Reservation.STATUS_PENDING_BOOKING_PAYMENT,
                Reservation.STATUS_RESERVED,
                Reservation.STATUS_CHECKED_IN,
            ],
        ).exists()


class ReservationSerializer(serializers.ModelSerializer):
    user_name = serializers.CharField(source='user.username', read_only=True)
    user_full_name = serializers.SerializerMethodField()
    user_email = serializers.CharField(source='user.email', read_only=True)
    user_phone = serializers.CharField(source='user.phone', read_only=True)
    slot_label = serializers.CharField(source='slot.label', read_only=True)
    slot_identifier = serializers.CharField(source='slot.slot_id', read_only=True)
    parking_space_id = serializers.IntegerField(source='slot.space.id', read_only=True)
    parking_space_name = serializers.CharField(source='slot.space.name', read_only=True)
    parking_space_location = serializers.CharField(source='slot.space.location', read_only=True)
    duration_hours = serializers.SerializerMethodField()
    total_charged = serializers.SerializerMethodField()

    class Meta:
        model = Reservation
        fields = [
            'id', 'reservation_id',
            'user', 'user_name', 'user_full_name', 'user_email', 'user_phone',
            'slot', 'slot_label', 'slot_identifier',
            'parking_space_id', 'parking_space_name', 'parking_space_location',
            'vehicle_number', 'vehicle_type',
            'start_time', 'end_time', 'checkin_time', 'checkout_time',
            'duration_hours',
            'booking_fee', 'booking_fee_paid',
            'hourly_rate',
            'final_fee', 'final_fee_paid',
            'amount', 'is_paid',
            'total_charged',
            'status', 'qr_code', 'qr_image',
            'created_at',  'cancellation_reason'
        ]

    def get_user_full_name(self, obj):
        name = f"{obj.user.first_name} {obj.user.last_name}".strip()
        return name or obj.user.username

    def get_duration_hours(self, obj):
        if obj.checkin_time and obj.checkout_time:
            delta = obj.checkout_time - obj.checkin_time
            return round(delta.total_seconds() / 3600, 2)
        return None

    def get_total_charged(self, obj):
        total = Decimal('0.00')
        if obj.booking_fee_paid:
            total += obj.booking_fee
        if obj.final_fee_paid and obj.final_fee:
            total += obj.final_fee
        return str(total)


class PaymentRecordSerializer(serializers.ModelSerializer):
    class Meta:
        model = PaymentRecord
        fields = [
            'id', 'reservation', 'user', 'user_full_name', 'user_email', 'user_phone',
            'slot_id', 'slot_label', 'parking_space_name', 'parking_space_location',
            'payment_type', 'amount', 'paid_at', 'transaction_ref',
        ]
        read_only_fields = fields


class GateSerializer(serializers.ModelSerializer):
    space_name = serializers.CharField(source='space.name', read_only=True)

    class Meta:
        model = Gate
        fields = ['id', 'name', 'space', 'space_name', 'is_active', 'last_access', 'access_count']


class CCTVFeedSerializer(serializers.ModelSerializer):
    space_name = serializers.CharField(source='space.name', read_only=True)

    class Meta:
        model = CCTVFeed
        fields = ['id', 'space', 'space_name', 'camera_id', 'name', 'stream_url', 'is_active']


class CustomTokenObtainPairSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        username = attrs.get(self.username_field)
        if username and '@' in username:
            try:
                user = User.objects.get(email=username)
                attrs[self.username_field] = user.username
            except User.DoesNotExist:
                pass
                
        username_val = attrs.get(self.username_field)
        password_val = attrs.get('password')
        if username_val and password_val:
            try:
                user = User.objects.get(username=username_val)
                if not user.is_active and user.check_password(password_val):
                    from rest_framework.exceptions import AuthenticationFailed
                    raise AuthenticationFailed('Your account is pending admin approval. Please wait for an administrator to activate your account.')
            except User.DoesNotExist:
                pass

        return super().validate(attrs)


class VehicleLogSerializer(serializers.ModelSerializer):
    space_name = serializers.CharField(source='space.name', read_only=True)
    slot_label = serializers.CharField(source='slot.label', read_only=True, allow_null=True)
    user_name = serializers.CharField(source='user.username', read_only=True, allow_null=True)
    duration_hours = serializers.SerializerMethodField()

    class Meta:
        model = VehicleLog
        fields = [
            'id',
            'space',
            'space_name',
            'slot',
            'slot_label',
            'vehicle_number',
            'vehicle_type',
            'check_in_time',
            'check_out_time',
            'duration_minutes',
            'duration_hours',
            'user',
            'user_name',
            'created_at',
        ]

    def get_duration_hours(self, obj):
        if obj.duration_minutes:
            return round(obj.duration_minutes / 60, 2)
        return None


class WalletSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)
    transactions = serializers.SerializerMethodField()

    def get_transactions(self, obj):
        return WalletTransactionSerializer(obj.transactions.all(), many=True).data

    class Meta:
        model = Wallet
        fields = ['id', 'user', 'username', 'balance', 'updated_at', 'transactions']


class WalletTransactionSerializer(serializers.ModelSerializer):
    wallet_username = serializers.CharField(source='wallet.user.username', read_only=True)

    class Meta:
        model = WalletTransaction
        fields = [
            'id',
            'wallet',
            'wallet_username',
            'transaction_type',
            'amount',
            'description',
            'reservation',
            'created_at',
        ]


class NotificationSerializer(serializers.ModelSerializer):
    username = serializers.CharField(source='user.username', read_only=True)

    class Meta:
        model = Notification
        fields = [
            'id',
            'user',
            'username',
            'title',
            'message',
            'notification_type',
            'is_read',
            'created_at',
        ]


class FAQSerializer(serializers.ModelSerializer):
    class Meta:
        model = FAQ
        fields = ['id', 'question', 'answer', 'is_active', 'created_at']

