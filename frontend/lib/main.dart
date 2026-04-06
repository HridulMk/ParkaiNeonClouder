import 'package:flutter/material.dart';
import 'screens/loading.dart';
import 'screens/welcome.dart';
import 'screens/login.dart';
import 'screens/dashboard.dart';
import 'screens/parking_list.dart';
import 'screens/home.dart';
import 'screens/vendor_home.dart';
import 'screens/security_home.dart';
import 'screens/admin_home.dart';
import 'screens/cctv_cameras.dart';
import 'screens/manage_pricing_screen.dart';
import 'screens/register.dart';
import 'screens/vendor_register.dart';
import 'screens/security_register.dart';
import 'screens/demo_working.dart';
import 'screens/terms_and_conditions.dart';
import 'screens/gate_camera.dart';
import 'services/auth_service.dart';

void main() => runApp(ParkingApp());

class ParkingApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parking Management',
      theme: ThemeData(primarySwatch: Colors.blue),
      initialRoute: '/loading',
      routes: {
        '/loading': (ctx) => LoadingScreen(
              nextScreen: const AuthWrapper(),
              displayDuration: const Duration(seconds: 2),
            ),
        '/': (ctx) => const AuthWrapper(),
        '/login': (ctx) => const LoginScreen(),
        '/dashboard': (ctx) => DashboardScreen(),
        '/parking': (ctx) => ParkingListScreen(),
        '/home': (ctx) => HomeScreen(),
        '/vendor-home': (ctx) => const VendorHomeScreen(),
        '/security-home': (ctx) => const SecurityHomeScreen(),
        '/admin-home': (ctx) => const AdminHomeScreen(),
        '/cctv-cameras': (ctx) => const CCTVCamerasScreen(),
        '/manage-spaces': (ctx) => const ManagePricingScreen(),
        '/register': (ctx) => const RegisterScreen(),
        '/vendor-register': (ctx) => const VendorRegisterScreen(),
        '/security-register': (ctx) => const SecurityRegisterScreen(),
        '/demo': (ctx) => const DemoWorkingScreen(),
        '/gate-camera': (ctx) => const GateCameraScreen(),
        '/terms-and-conditions': (ctx) => const TermsAndConditionsPage(),
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String? _userType;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    String? userType;
    if (isLoggedIn) {
      userType = await AuthService.getUserType();
    }
    setState(() {
      _isLoggedIn = isLoggedIn;
      _userType = userType;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_isLoggedIn) {
      // Redirect to appropriate home screen based on user type
      switch (_userType) {
        case 'vendor':
          return const VendorHomeScreen();
        case 'security':
          return const SecurityHomeScreen();
        case 'admin':
          return const AdminHomeScreen();
        case 'customer':
        default:
          return HomeScreen();
      }
    }

    // Not logged in, show welcome screen
    return const WelcomeScreen();
  }
}
