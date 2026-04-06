import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:async';
import 'package:http/http.dart' as http;  // For http exceptions
import '../utils/responsive_utils.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  final String userType;
  final String userTitle;

  const LoginScreen({
    super.key,
    this.userType = 'customer',
    this.userTitle = 'Customer',
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String _selectedRegisterType = 'customer';
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String _getUserFriendlyError(String? rawError, [String? errorCode]) {
    if (errorCode != null) {
      switch (errorCode) {
        case 'AUTH_001':
          return 'Invalid username or password. Please try again.';
        case 'NET_001':
          return 'Backend is temporarily down. Check your connection and retry.';
        case 'NET_002':
          return 'Network timeout. Please check your internet.';
        default:
          return rawError ?? 'An unexpected error occurred.';
      }
    }
    switch (rawError?.toLowerCase()) {
      case 'invalid credentials':
      case 'unauthorized':
        return 'Invalid username or password. Please try again.';
      case 'backend unavailable':
      case 'service unavailable':
        return 'Backend is down. Please try again later.';
      case 'network error':
      case 'connection failed':
      case 'no internet':
        return 'Backend is unreachable. Please check your connection.';  // Enhanced for backend down
      default:
        return rawError ?? 'Login failed. Please try again.';
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      debugPrint('Starting login...');  // Debug: Track flow
      final result = await AuthService.login(
        username: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      debugPrint('Auth result: $result');  // Debug: See response

      if (!mounted) return;

      if (result['success']) {
        // Get user type and redirect accordingly
        final userType = await AuthService.getUserType();

        String routeName;
        switch (userType) {
          case 'vendor':
            routeName = '/vendor-home';
            break;
          case 'security':
            routeName = '/security-home';
            break;
          case 'admin':
            routeName = '/admin-home';
            break;
          case 'customer':
          default:
            routeName = '/home';
        }

        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            routeName,
            (route) => false,
          );
        }
      } else {
        // Handle auth-specific errors (including network from response)
        final errorMsg = _getUserFriendlyError(
          result['error'],
          result['errorCode'],
        );
        _showErrorSnackBar(errorMsg);
        debugPrint('Login error from response: $errorMsg');
      }
    } on TimeoutException {
      // Request timeout
      if (mounted) {
        _showErrorSnackBar('Backend is taking too long to respond. Please check your connection.');
      }
      debugPrint('TimeoutException: Backend slow/unreachable');
    } on http.ClientException {
      // http package network errors (e.g., DNS failure)
      if (mounted) {
        _showErrorSnackBar('Backend is unreachable. Please check your connection.');
      }
      debugPrint('ClientException: Backend/network issue');
    } on SocketException {
      // Low-level socket failure (no connection)
      if (mounted) {
        _showErrorSnackBar('Backend is unreachable. Please check your connection.');
      }
      debugPrint('SocketException: Backend down');
    } on IOException {
      // Broader IO errors (covers most network fails)
      if (mounted) {
        _showErrorSnackBar('Backend is down or unreachable. Please check your connection and retry.');
      }
      debugPrint('IOException: General backend/network failure');
    } on FormatException {
      // Malformed response (e.g., invalid JSON from server)
      if (mounted) {
        _showErrorSnackBar('Server response error. Please try again.');
      }
      debugPrint('FormatException: Invalid server response');
    } catch (e) {
      // Generic catch-all (log type for debugging)
      if (mounted) {
        _showErrorSnackBar('Something went wrong. Please try again later.');
      }
      debugPrint('Unexpected login error: $e (type: ${e.runtimeType})');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleBackPress() {
    final canPop = Navigator.of(context).canPop();
    if (canPop) {
      Navigator.pop(context);  // Standard back navigation
    } else {
      // If root screen, show exit confirmation
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Exit App?'),
          content: const Text('Are you sure you want to leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),  // Cancel
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();  // Close dialog
                SystemNavigator.pop();  // Exit app (Android/iOS)
              },
              child: const Text('Exit', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final horizontalPadding = ResponsiveUtils.responsivePadding(
      context,
      mobile: 20,
      tablet: 36,
      desktop: 48,
    );
    final welcomeFontSize = ResponsiveUtils.responsiveFontSize(
      context,
      mobile: 32,
      tablet: 40,
      desktop: 42,
    );
    final subtitleFontSize = ResponsiveUtils.responsiveFontSize(
      context,
      mobile: 14,
      tablet: 15,
      desktop: 16,
    );

    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? const [Color(0xFF0F172A), Color(0xFF1E293B)]
                    : const [Color(0xFFF8FAFC), Color(0xFFE2E8F0)],
              ),
            ),
          ),

          SafeArea(
            child: Stack(
              children: [
                // Back button with enhanced handling
                Positioned(
                  top: 8,
                  left: 8,
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(50),  // For ripple effect
                      onTap: () => _handleBackPress(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.arrow_back_ios_new,
                          color: isDark
                              ? Colors.white70
                              : Colors.grey[700],
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                // Main content
                SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: ResponsiveUtils.getContentWidth(context,
                              maxWidth: 420)),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 40,
                                      tablet: 50,
                                      desktop: 60)),

                              // User type badge
                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 16,
                                      tablet: 18,
                                      desktop: 20)),
                              // Logo / App name with nice animation
                              Hero(
                                tag: 'app-logo',
                                child: Text(
                                  'Welcome',
                                  style: TextStyle(
                                    fontSize: welcomeFontSize,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1.2,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Sign in to continue',
                                style: TextStyle(
                                  fontSize: subtitleFontSize,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 36,
                                      tablet: 44,
                                      desktop: 48)),

                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    // Email field
                                    _ModernTextField(
                                      controller: _emailController,
                                      label: 'Email',
                                      hint: 'hello@example.com',
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if (v == null || v.isEmpty)
                                          return 'Required';
                                        if (!RegExp(
                                                r'^.+@[a-zA-Z]+\.{1}[a-zA-Z]+(\.{0,1}[a-zA-Z]+)$')
                                            .hasMatch(v)) {
                                          return 'Invalid email';
                                        }
                                        return null;
                                      },
                                      prefixIcon: Icons.alternate_email_rounded,
                                    ),

                                    SizedBox(
                                        height:
                                            ResponsiveUtils.responsivePadding(
                                                context,
                                                mobile: 16,
                                                tablet: 18,
                                                desktop: 20)),

                                    // Password field
                                    _ModernTextField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      obscureText: _obscurePassword,
                                      validator: (v) {
                                        if (v == null || v.isEmpty)
                                          return 'Required';
                                        if (v.length < 6)
                                          return 'At least 6 characters';
                                        return null;
                                      },
                                      prefixIcon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_outlined
                                              : Icons.visibility_off_outlined,
                                          color: theme
                                              .colorScheme.onSurfaceVariant,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscurePassword =
                                                !_obscurePassword),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    // Navigator.pushNamed(context, '/forgot-password');
                                  },
                                  child: const Text('Forgot password?'),
                                ),
                              ),

                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 24,
                                      tablet: 28,
                                      desktop: 32)),

                              // Animated gradient button
                              _GradientButton(
                                isLoading: _isLoading,
                                onPressed: _isLoading ? null : _handleLogin,
                              ),

                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 28,
                                      tablet: 32,
                                      desktop: 36)),

                              // Register type picker
                              Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        "Register as ",
                                        style: TextStyle(
                                            color:
                                                theme.colorScheme.onSurfaceVariant,
                                            fontSize: subtitleFontSize),
                                      ),
                                      const SizedBox(width: 8),
                                      DropdownButton<String>(
                                        value: _selectedRegisterType,
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'customer',
                                            child: Text('Customer'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'vendor',
                                            child: Text('Slot Vendor'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'security',
                                            child: Text('Security Personnel'),
                                          ),
                                        ],
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedRegisterType = value;
                                            });
                                          }
                                        },
                                      ),
                                      const SizedBox(width: 12),
                                      TextButton(
                                        onPressed: () {
                                          String route;
                                          switch (_selectedRegisterType) {
                                            case 'vendor':
                                              route = '/vendor-register';
                                              break;
                                            case 'security':
                                              route = '/security-register';
                                              break;
                                            default:
                                              route = '/register';
                                          }
                                          Navigator.pushNamed(context, route);
                                        },
                                        child: const Text('Continue'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 24,
                                      tablet: 32,
                                      desktop: 40)),

                              // Terms and Conditions link
                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/terms-and-conditions'),
                                  child: Text(
                                    'Terms and Conditions',
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: ResponsiveUtils.responsiveFontSize(
                                        context,
                                        mobile: 14,
                                        tablet: 16,
                                        desktop: 16,
                                      ),
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),

                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 16,
                                      tablet: 20,
                                      desktop: 24)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Reusable modern text field
// ──────────────────────────────────────────────
class _ModernTextField extends StatelessWidget {
  const _ModernTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final FormFieldValidator<String>? validator;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 22) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: theme.colorScheme.error,
            width: 1.5,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Animated gradient button
// ──────────────────────────────────────────────
class _GradientButton extends StatelessWidget {
  const _GradientButton({
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : const Text(
                    'Sign In',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}