from django.contrib import admin
from .models import User, ParkingSpace, ParkingSlot, Reservation, Gate, CCTVFeed, SystemSetting

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ['username', 'email', 'first_name', 'last_name', 'phone', 'user_type', 'is_active']
    list_filter = ['user_type', 'is_active']
    actions = [
        'activate_users',
        'deactivate_users',
        'make_customers',
        'make_vendors',
        'make_security',
        'make_admins',
    ]

    @admin.action(description='Activate selected users')
    def activate_users(self, request, queryset):
        queryset.update(is_active=True)

    @admin.action(description='Deactivate selected users')
    def deactivate_users(self, request, queryset):
        queryset.update(is_active=False)

    @admin.action(description='Change selected users to Customer')
    def make_customers(self, request, queryset):
        updated = queryset.update(user_type='customer')
        self.message_user(request, f"{updated} user(s) were updated to Customer.")

    @admin.action(description='Change selected users to Slot Vendor')
    def make_vendors(self, request, queryset):
        updated = queryset.update(user_type='vendor')
        self.message_user(request, f"{updated} user(s) were updated to Slot Vendor.")

    @admin.action(description='Change selected users to Security')
    def make_security(self, request, queryset):
        updated = queryset.update(user_type='security')
        self.message_user(request, f"{updated} user(s) were updated to Security.")

    @admin.action(description='Change selected users to Admin')
    def make_admins(self, request, queryset):
        updated = queryset.update(user_type='admin')
        self.message_user(request, f"{updated} user(s) were updated to Admin.")

@admin.register(ParkingSpace)
class ParkingSpaceAdmin(admin.ModelAdmin):
    list_display = ['name', 'vendor', 'total_slots', 'is_active']
    list_filter = ['is_active', 'vendor']
    actions = ['activate_spaces', 'deactivate_spaces']

    @admin.action(description='Activate selected parking spaces')
    def activate_spaces(self, request, queryset):
        queryset.update(is_active=True)

    @admin.action(description='Deactivate selected parking spaces')
    def deactivate_spaces(self, request, queryset):
        queryset.update(is_active=False)

@admin.register(ParkingSlot)
class ParkingSlotAdmin(admin.ModelAdmin):
    list_display = ['slot_id', 'label', 'space', 'is_occupied', 'is_active']
    list_filter = ['is_occupied', 'space', 'is_active']
    actions = ['activate_slots', 'deactivate_slots']

    @admin.action(description='Activate selected slots')
    def activate_slots(self, request, queryset):
        queryset.update(is_active=True)

    @admin.action(description='Deactivate selected slots')
    def deactivate_slots(self, request, queryset):
        queryset.update(is_active=False)

@admin.register(Reservation)
class ReservationAdmin(admin.ModelAdmin):
    list_display = ['reservation_id', 'user', 'slot', 'is_paid', 'amount']

@admin.register(Gate)
class GateAdmin(admin.ModelAdmin):
    list_display = ['name', 'space', 'is_active', 'access_count']

@admin.register(CCTVFeed)
class CCTVFeedAdmin(admin.ModelAdmin):
    list_display = ['name', 'space', 'camera_id', 'is_active']


@admin.register(SystemSetting)
class SystemSettingAdmin(admin.ModelAdmin):
    list_display = ['commission_percentage', 'updated_at']
