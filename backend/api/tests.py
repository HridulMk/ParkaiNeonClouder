from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from rest_framework import status
from rest_framework.test import APITestCase

from .models import ParkingSlot, ParkingSpace, User


class UserRegistrationTestCase(APITestCase):
    def test_user_registration_success(self):
        url = reverse('register_user')
        data = {
            'username': 'testuser',
            'email': 'test@example.com',
            'full_name': 'John Doe',
            'phone': '+1234567890',
            'user_type': 'customer',
            'password': 'testpass123',
            'password_confirm': 'testpass123',
        }

        response = self.client.post(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertIn('message', response.data)
        self.assertIn('user', response.data)

        user = User.objects.get(username='testuser')
        self.assertEqual(user.email, 'test@example.com')
        self.assertEqual(user.first_name, 'John')
        self.assertEqual(user.last_name, 'Doe')
        self.assertEqual(user.phone, '+1234567890')
        self.assertEqual(user.user_type, 'customer')
        self.assertTrue(user.check_password('testpass123'))

    def test_user_registration_password_mismatch(self):
        url = reverse('register_user')
        data = {
            'username': 'testuser2',
            'email': 'test2@example.com',
            'full_name': 'Jane Doe',
            'phone': '+1234567891',
            'user_type': 'vendor',
            'password': 'testpass123',
            'password_confirm': 'differentpass',
        }

        response = self.client.post(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('non_field_errors', response.data)

    def test_user_registration_duplicate_username(self):
        User.objects.create_user(
            username='testuser3',
            email='test3@example.com',
            password='testpass123',
        )

        url = reverse('register_user')
        data = {
            'username': 'testuser3',
            'email': 'test4@example.com',
            'full_name': 'Bob Smith',
            'phone': '+1234567892',
            'user_type': 'customer',
            'password': 'testpass123',
            'password_confirm': 'testpass123',
        }

        response = self.client.post(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_400_BAD_REQUEST)
        self.assertIn('username', response.data)

    def test_user_registration_minimal_data(self):
        url = reverse('register_user')
        data = {
            'username': 'minimaluser',
            'email': 'minimal@example.com',
            'full_name': 'Minimal User',
            'password': 'testpass123',
            'password_confirm': 'testpass123',
        }

        response = self.client.post(url, data, format='json')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)

        user = User.objects.get(username='minimaluser')
        self.assertEqual(user.user_type, 'customer')
        self.assertEqual(user.phone, '')


class ParkingSpaceCreateApiTestCase(APITestCase):
    def setUp(self):
        self.vendor = User.objects.create_user(
            username='vendor1',
            email='vendor1@example.com',
            password='pass12345',
            user_type='vendor',
            is_active=True,
        )
        self.admin_user = User.objects.create_user(
            username='admin1',
            email='admin1@example.com',
            password='pass12345',
            user_type='admin',
            is_active=True,
        )
        self.customer = User.objects.create_user(
            username='customer1',
            email='customer1@example.com',
            password='pass12345',
            user_type='customer',
            is_active=True,
        )
        self.url = '/api/spaces/create-space/'

    def test_vendor_can_create_parking_space_and_slots(self):
        self.client.force_authenticate(user=self.vendor)
        payload = {
            'name': 'Vendor Plaza',
            'number_of_slots': 3,
            'location': 'MG Road, Bengaluru',
            'open_time': '08:00:00',
            'close_time': '22:00:00',
            'google_map_link': 'https://maps.google.com/?q=12.97,77.59',
            'cctv_video': SimpleUploadedFile('cam.mp4', b'fake-video-bytes', content_type='video/mp4'),
        }

        response = self.client.post(self.url, payload, format='multipart')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        space = ParkingSpace.objects.get(name='Vendor Plaza')
        self.assertEqual(space.vendor, self.vendor)
        self.assertEqual(space.total_slots, 3)
        self.assertEqual(space.location, 'MG Road, Bengaluru')
        self.assertEqual(ParkingSlot.objects.filter(space=space).count(), 3)

    def test_admin_can_create_space_without_vendor(self):
        self.client.force_authenticate(user=self.admin_user)
        payload = {
            'name': 'Admin Plaza',
            'number_of_slots': 2,
            'location': 'Koramangala',
            'open_time': '09:00:00',
            'close_time': '21:00:00',
            'google_map_link': 'https://maps.google.com/?q=12.93,77.62',
        }

        response = self.client.post(self.url, payload, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        space = ParkingSpace.objects.get(name='Admin Plaza')
        self.assertEqual(space.vendor, self.admin_user)

    def test_customer_cannot_create_space(self):
        self.client.force_authenticate(user=self.customer)
        payload = {
            'name': 'Blocked Plaza',
            'number_of_slots': 2,
            'location': 'Indiranagar',
            'open_time': '09:00:00',
            'close_time': '21:00:00',
            'google_map_link': 'https://maps.google.com/?q=12.97,77.64',
        }

        response = self.client.post(self.url, payload, format='multipart')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class ParkingDeleteApiTestCase(APITestCase):
    def setUp(self):
        self.vendor1 = User.objects.create_user(
            username='vendor-delete-1',
            email='vendor-delete-1@example.com',
            password='pass12345',
            user_type='vendor',
            is_active=True,
        )
        self.vendor2 = User.objects.create_user(
            username='vendor-delete-2',
            email='vendor-delete-2@example.com',
            password='pass12345',
            user_type='vendor',
            is_active=True,
        )
        self.admin_user = User.objects.create_user(
            username='admin-delete',
            email='admin-delete@example.com',
            password='pass12345',
            user_type='admin',
            is_active=True,
        )

        self.space = ParkingSpace.objects.create(
            name='Delete Test Space',
            vendor=self.vendor1,
            address='Test Address',
            location='Test Address',
            total_slots=2,
        )
        self.slot1 = ParkingSlot.objects.create(space=self.space, slot_id='D-001', label='Delete Slot 1')
        self.slot2 = ParkingSlot.objects.create(space=self.space, slot_id='D-002', label='Delete Slot 2')

    def test_vendor_can_delete_own_space_and_slots(self):
        self.client.force_authenticate(user=self.vendor1)
        response = self.client.delete(f'/api/spaces/{self.space.id}/delete/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(ParkingSpace.objects.filter(id=self.space.id).exists())
        self.assertEqual(ParkingSlot.objects.filter(id__in=[self.slot1.id, self.slot2.id]).count(), 0)

    def test_vendor_cannot_delete_other_vendor_space(self):
        self.client.force_authenticate(user=self.vendor2)
        response = self.client.delete(f'/api/spaces/{self.space.id}/delete/')

        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)
        self.assertTrue(ParkingSpace.objects.filter(id=self.space.id).exists())

    def test_vendor_can_delete_all_slots_of_owned_space(self):
        self.client.force_authenticate(user=self.vendor1)
        response = self.client.delete(f'/api/spaces/{self.space.id}/slots/delete/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertEqual(ParkingSlot.objects.filter(space=self.space).count(), 0)
        self.space.refresh_from_db()
        self.assertEqual(self.space.total_slots, 0)

    def test_admin_can_delete_any_parking_space(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.delete(f'/api/spaces/{self.space.id}/delete/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(ParkingSpace.objects.filter(id=self.space.id).exists())
        self.assertEqual(ParkingSlot.objects.filter(id__in=[self.slot1.id, self.slot2.id]).count(), 0)

    def test_admin_can_delete_any_single_slot(self):
        self.client.force_authenticate(user=self.admin_user)
        response = self.client.delete(f'/api/slots/{self.slot1.id}/delete/')

        self.assertEqual(response.status_code, status.HTTP_200_OK)
        self.assertFalse(ParkingSlot.objects.filter(id=self.slot1.id).exists())

class ParkingActivationApiTestCase(APITestCase):
    def setUp(self):
        self.admin_user = User.objects.create_user(
            username='admin-activate',
            email='admin-activate@example.com',
            password='pass12345',
            user_type='admin',
            is_active=True,
        )
        self.vendor = User.objects.create_user(
            username='vendor-activate',
            email='vendor-activate@example.com',
            password='pass12345',
            user_type='vendor',
            is_active=True,
        )

        self.space = ParkingSpace.objects.create(
            name='Activation Space',
            vendor=self.vendor,
            address='Activation Address',
            location='Activation Address',
            total_slots=1,
            is_active=True,
        )
        self.slot = ParkingSlot.objects.create(
            space=self.space,
            slot_id='A-001',
            label='Activation Slot',
            is_active=True,
        )

    def test_admin_can_deactivate_and_activate_space(self):
        self.client.force_authenticate(user=self.admin_user)

        deactivate_response = self.client.post(f'/api/spaces/{self.space.id}/deactivate/')
        self.assertEqual(deactivate_response.status_code, status.HTTP_200_OK)
        self.space.refresh_from_db()
        self.assertFalse(self.space.is_active)

        activate_response = self.client.post(f'/api/spaces/{self.space.id}/activate/')
        self.assertEqual(activate_response.status_code, status.HTTP_200_OK)
        self.space.refresh_from_db()
        self.assertTrue(self.space.is_active)

    def test_admin_can_deactivate_and_activate_slot(self):
        self.client.force_authenticate(user=self.admin_user)

        deactivate_response = self.client.post(f'/api/slots/{self.slot.id}/deactivate/')
        self.assertEqual(deactivate_response.status_code, status.HTTP_200_OK)
        self.slot.refresh_from_db()
        self.assertFalse(self.slot.is_active)

        activate_response = self.client.post(f'/api/slots/{self.slot.id}/activate/')
        self.assertEqual(activate_response.status_code, status.HTTP_200_OK)
        self.slot.refresh_from_db()
        self.assertTrue(self.slot.is_active)

    def test_vendor_cannot_toggle_activation(self):
        self.client.force_authenticate(user=self.vendor)

        response = self.client.post(f'/api/spaces/{self.space.id}/deactivate/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)

        response = self.client.post(f'/api/slots/{self.slot.id}/deactivate/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class VehicleLogApiTestCase(APITestCase):
    def setUp(self):
        self.security_user = User.objects.create_user(
            username='security-logs',
            email='security-logs@example.com',
            password='pass12345',
            user_type='security',
            is_active=True,
        )
        self.vendor = User.objects.create_user(
            username='vendor-logs',
            email='vendor-logs@example.com',
            password='pass12345',
            user_type='vendor',
            is_active=True,
        )
        self.admin_user = User.objects.create_user(
            username='admin-logs',
            email='admin-logs@example.com',
            password='pass12345',
            user_type='admin',
            is_active=True,
        )

        self.space = ParkingSpace.objects.create(
            name='Log Space',
            vendor=self.vendor,
            address='Log Address',
            location='Log Location',
            total_slots=1,
            is_active=True,
        )
        self.security_user.assigned_parking_space = self.space
        self.security_user.save()

        self.slot = ParkingSlot.objects.create(
            space=self.space,
            slot_id='L-001',
            label='Log Slot',
            is_active=True,
        )

    def test_create_vehicle_log(self):
        from django.utils import timezone
        self.client.force_authenticate(user=self.security_user)
        
        now = timezone.now()
        payload = {
            'space': self.space.id,
            'slot': self.slot.id,
            'vehicle_number': 'ABC123',
            'vehicle_type': 'Car',
            'check_in_time': now.isoformat(),
        }

        response = self.client.post('/api/vehicle-logs/', payload, format='json')
        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['vehicle_number'], 'ABC123')

    def test_security_can_view_own_space_logs(self):
        from django.utils import timezone
        from .models import VehicleLog
        
        VehicleLog.objects.create(
            space=self.space,
            slot=self.slot,
            vehicle_number='ABC123',
            vehicle_type='Car',
            check_in_time=timezone.now(),
            user=self.security_user,
        )

        self.client.force_authenticate(user=self.security_user)
        response = self.client.get('/api/vehicle-logs/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Handle both paginated and non-paginated responses
        data = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        self.assertEqual(len(data), 1)

    def test_admin_can_view_all_logs(self):
        from django.utils import timezone
        from .models import VehicleLog
        
        VehicleLog.objects.create(
            space=self.space,
            slot=self.slot,
            vehicle_number='ABC123',
            vehicle_type='Car',
            check_in_time=timezone.now(),
            user=self.security_user,
        )

        self.client.force_authenticate(user=self.admin_user)
        response = self.client.get('/api/vehicle-logs/')
        
        self.assertEqual(response.status_code, status.HTTP_200_OK)
        # Handle both paginated and non-paginated responses
        data = response.data.get('results', response.data) if isinstance(response.data, dict) else response.data
        self.assertGreater(len(data), 0)
class CustomerBookingApiTestCase(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username='customer-book',
            email='customer-book@example.com',
            password='pass12345',
            user_type='customer',
            is_active=True,
        )
        self.vendor = User.objects.create_user(
            username='vendor-book',
            email='vendor-book@example.com',
            password='pass12345',
            user_type='vendor',
            is_active=True,
        )

        self.space = ParkingSpace.objects.create(
            name='Booking Space',
            vendor=self.vendor,
            address='Booking Address',
            location='Booking Address',
            total_slots=2,
            is_active=True,
        )
        self.slot = ParkingSlot.objects.create(
            space=self.space,
            slot_id='B-001',
            label='Booking Slot 1',
            is_active=True,
            is_occupied=False,
        )

    def test_customer_can_book_slot_by_space_and_slot_id(self):
        self.client.force_authenticate(user=self.customer)
        response = self.client.post(f'/api/spaces/{self.space.id}/slots/{self.slot.id}/book/')

        self.assertEqual(response.status_code, status.HTTP_201_CREATED)
        self.assertEqual(response.data['status'], 'pending_booking_payment')
        self.slot.refresh_from_db()
        self.assertFalse(self.slot.is_occupied)
    def test_customer_cannot_book_mismatched_space_slot(self):
        other_space = ParkingSpace.objects.create(
            name='Other Space',
            vendor=self.vendor,
            address='Other Address',
            location='Other Address',
            total_slots=1,
            is_active=True,
        )

        self.client.force_authenticate(user=self.customer)
        response = self.client.post(f'/api/spaces/{other_space.id}/slots/{self.slot.id}/book/')
        self.assertEqual(response.status_code, status.HTTP_404_NOT_FOUND)

    def test_non_customer_cannot_book_slot(self):
        self.client.force_authenticate(user=self.vendor)
        response = self.client.post(f'/api/spaces/{self.space.id}/slots/{self.slot.id}/book/')
        self.assertEqual(response.status_code, status.HTTP_403_FORBIDDEN)


class TwoStagePaymentFlowApiTestCase(APITestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            username='customer-stage',
            email='customer-stage@example.com',
            password='pass12345',
            user_type='customer',
            is_active=True,
        )
        self.vendor = User.objects.create_user(
            username='vendor-stage',
            email='vendor-stage@example.com',
            password='pass12345',
            user_type='vendor',
            is_active=True,
        )
        self.space = ParkingSpace.objects.create(
            name='Stage Space',
            vendor=self.vendor,
            address='Stage Address',
            location='Stage Address',
            total_slots=1,
            is_active=True,
        )
        self.slot = ParkingSlot.objects.create(
            space=self.space,
            slot_id='S-201',
            label='Stage Slot',
            is_active=True,
            is_occupied=False,
        )

    def test_two_stage_payment_checkout_and_final_payment(self):
        self.client.force_authenticate(user=self.customer)

        create_res = self.client.post(f'/api/spaces/{self.space.id}/slots/{self.slot.id}/book/')
        self.assertEqual(create_res.status_code, status.HTTP_201_CREATED)
        reservation_id = create_res.data['id']

        pay_booking_res = self.client.post(f'/api/reservations/{reservation_id}/pay_booking/')
        self.assertEqual(pay_booking_res.status_code, status.HTTP_200_OK)
        self.assertEqual(pay_booking_res.data['status'], 'reserved')

        self.slot.refresh_from_db()
        self.assertTrue(self.slot.is_occupied)

        checkin_res = self.client.post(f'/api/reservations/{reservation_id}/checkin/')
        self.assertEqual(checkin_res.status_code, status.HTTP_200_OK)
        self.assertEqual(checkin_res.data['status'], 'checked_in')

        checkout_res = self.client.post(f'/api/reservations/{reservation_id}/checkout/')
        self.assertEqual(checkout_res.status_code, status.HTTP_200_OK)
        self.assertEqual(checkout_res.data['status'], 'checked_out')
        self.assertIsNotNone(checkout_res.data['final_fee'])

        self.slot.refresh_from_db()
        self.assertFalse(self.slot.is_occupied)

        pay_final_res = self.client.post(f'/api/reservations/{reservation_id}/pay_final/')
        self.assertEqual(pay_final_res.status_code, status.HTTP_200_OK)
        self.assertEqual(pay_final_res.data['status'], 'completed')
        self.assertTrue(pay_final_res.data['is_paid'])
        self.assertTrue(pay_final_res.data['final_fee_paid'])

