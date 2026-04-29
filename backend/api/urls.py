from django.urls import include, path, re_path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenRefreshView  # pyright: ignore[reportMissingImports]

from . import views
from .views import CustomTokenObtainPairView

router = DefaultRouter()
router.register(r'users', views.UserViewSet)
router.register(r'spaces', views.ParkingSpaceViewSet)
router.register(r'slots', views.ParkingSlotViewSet)
router.register(r'reservations', views.ReservationViewSet)
router.register(r'gates', views.GateViewSet)
router.register(r'cctv', views.CCTVFeedViewSet)
router.register(r'vehicle-logs', views.VehicleLogViewSet)
router.register(r'payments', views.PaymentRecordViewSet, basename='payments')
router.register(r'notifications', views.NotificationViewSet, basename='notifications')
router.register(r'wallet', views.WalletViewSet, basename='wallet')

urlpatterns = [
    path('', include(router.urls)),


    # re_path(r'^spaces/create-space/?$', views.ParkingSpaceCreateEndpoint.as_view(), name='spaces_create_space_explicit'),
    # re_path(r'^spaces/(?P<space_id>\d+)/slots/(?P<slot_id>\d+)/book/?$', views.CustomerSlotBookingEndpoint.as_view(), name='customer_slot_book'),
    # re_path(r'^spaces/(?P<space_id>\d+)/upload-cctv-video/?$', views.ParkingSpaceCCTVUploadEndpoint.as_view(), name='spaces_upload_cctv_video'),

    # # re_path(r'^parking-lot/process-video/?$', views.ParkingLotRunAnalysisEndpoint.as_view(), name='parking_lot_process_video'),
    # re_path(r'^parking-lot/save-video/?$', views.ParkingLotSaveVideoEndpoint.as_view(), name='parking_lot_save_video'),
    # re_path(r'^parking-lot/run-analysis/?$', views.ParkingLotRunAnalysisEndpoint.as_view(), name='parking_lot_run_analysis'),
    # re_path(r'^parking-lot/polygons/?$', views.ParkingLotPolygonsEndpoint.as_view(), name='parking_lot_polygons'),
    
   path('spaces/create-space/',
         views.ParkingSpaceCreateEndpoint.as_view(),
         name='spaces_create_space_explicit'),

    path('spaces/<int:space_id>/slots/<int:slot_id>/book/',
         views.CustomerSlotBookingEndpoint.as_view(),
         name='customer_slot_book'),

    path('spaces/<int:space_id>/upload-cctv-video/',
         views.ParkingSpaceCCTVUploadEndpoint.as_view(),
         name='spaces_upload_cctv_video'),

    path('parking-lot/save-video/',
         views.ParkingLotSaveVideoEndpoint.as_view(),
         name='parking_lot_save_video'),

    path('parking-lot/run-analysis/',
         views.ParkingLotRunAnalysisEndpoint.as_view(),
         name='parking_lot_run_analysis'),

    path('parking-lot/polygons/',
         views.ParkingLotPolygonsEndpoint.as_view(),
         name='parking_lot_polygons'),

    re_path(r'^spaces/(?P<space_id>\d+)/delete/?$', views.ParkingSpaceDeleteEndpoint.as_view(), name='spaces_delete'),
    re_path(r'^spaces/(?P<space_id>\d+)/slots/delete/?$', views.ParkingSpaceSlotsDeleteEndpoint.as_view(), name='spaces_slots_delete'),
    re_path(r'^slots/(?P<slot_id>\d+)/delete/?$', views.ParkingSlotDeleteEndpoint.as_view(), name='slot_delete'),

    re_path(r'^spaces/(?P<space_id>\d+)/activate/?$', views.ParkingSpaceActivateEndpoint.as_view(), name='spaces_activate'),
    re_path(r'^spaces/(?P<space_id>\d+)/deactivate/?$', views.ParkingSpaceDeactivateEndpoint.as_view(), name='spaces_deactivate'),
    re_path(r'^slots/(?P<slot_id>\d+)/activate/?$', views.ParkingSlotActivateEndpoint.as_view(), name='slots_activate'),
    re_path(r'^slots/(?P<slot_id>\d+)/deactivate/?$', views.ParkingSlotDeactivateEndpoint.as_view(), name='slots_deactivate'),

    re_path(r'^reservations/scan/?$', views.ReservationViewSet.as_view({'post': 'scan'}), name='reservation_scan'),
    re_path(r'^reservations/(?P<pk>\d+)/qr/?$', views.ReservationViewSet.as_view({'get': 'qr'}), name='reservation_qr'),
    re_path(r'^reservations/(?P<pk>\d+)/pay_booking/?$', views.ReservationViewSet.as_view({'post': 'pay_booking'}), name='reservation_pay_booking_explicit'),
    re_path(r'^reservations/(?P<pk>\d+)/checkin/?$', views.ReservationViewSet.as_view({'post': 'checkin'}), name='reservation_checkin_explicit'),
    re_path(r'^reservations/(?P<pk>\d+)/checkout/?$', views.ReservationViewSet.as_view({'post': 'checkout'}), name='reservation_checkout_explicit'),
    re_path(r'^reservations/(?P<pk>\d+)/pay_final/?$', views.ReservationViewSet.as_view({'post': 'pay_final'}), name='reservation_pay_final_explicit'),

    path('auth/token/', CustomTokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/register/', views.register_user, name='register_user'),
    path('auth/parking-spaces-for-security/', views.get_parking_spaces_for_security, name='parking_spaces_for_security'),
    path('auth/admin/metrics/', views.admin_metrics, name='admin_metrics'),
    path('auth/admin/settings/', views.admin_settings, name='admin_settings'),
    path('dashboard/summary/', views.dashboard_summary, name='dashboard_summary'),
    path('analytics/overview/', views.analytics_overview, name='analytics_overview'),
    path('analytics/app-revenue/', views.analytics_app_revenue, name='analytics_app_revenue'),
    path('analytics/vendors/<int:vendor_id>/revenue/', views.analytics_vendor_revenue, name='analytics_vendor_revenue'),
    path('analytics/customers/<int:customer_id>/spend/', views.analytics_customer_spend, name='analytics_customer_spend'),

    path('vehicle/process-image/', views.VehicleImageProcessEndpoint.as_view(), name='vehicle_process_image'),
]
