import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../utils/responsive_utils.dart';
import '../services/auth_service.dart';
import '../models/parking_space.dart';

class SecurityRegisterScreen extends StatefulWidget {
  const SecurityRegisterScreen({super.key});

  @override
  State<SecurityRegisterScreen> createState() => _SecurityRegisterScreenState();
}

class _SecurityRegisterScreenState extends State<SecurityRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  int? _selectedParkingSpaceId;
  List<ParkingSpace> _parkingSpaces = [];

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isLoadingSpaces = true;
  bool _acceptTerms = false;
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
    _loadParkingSpaces();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _loadParkingSpaces() async {
    try {
      final spaces = await AuthService.getParkingSpacesForSecurity();
      setState(() {
        _parkingSpaces = spaces;
        _isLoadingSpaces = false;
      });
    } catch (e) {
      setState(() => _isLoadingSpaces = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load parking spaces: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedParkingSpaceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a parking space'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await AuthService.registerSecurity(
        username: _emailController.text.trim(),
        email: _emailController.text.trim(),
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        parkingSpaceId: _selectedParkingSpaceId!,
        password: _passwordController.text,
        passwordConfirm: _confirmPasswordController.text,
      );

      debugPrint('Security register result: $result');
      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Security registration successful! Please login.')),
        );
        Navigator.pop(context); // Go back to login
      } else {
        String errorMessage = 'Registration failed';
        if (result['errors'] != null && result['errors'] is Map) {
          final errors = result['errors'] as Map<String, dynamic>;
          if (errors.containsKey('username')) {
            errorMessage = 'Username already exists';
          } else if (errors.containsKey('email')) {
            errorMessage = 'Email already exists';
          } else if (errors.containsKey('non_field_errors')) {
            errorMessage = errors['non_field_errors'][0];
          }
        } else if (result['error'] != null) {
          errorMessage = result['error'];
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Network error. Please check your connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
    final titleFontSize = ResponsiveUtils.responsiveFontSize(
      context,
      mobile: 28,
      tablet: 36,
      desktop: 38,
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
                // Back button positioned at top-left
                Positioned(
                  top: 8,
                  left: 8,
                  child: IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new,
                      color: isDark ? Colors.white : Colors.black87,
                      size: 20,
                    ),
                    onPressed: () {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                  ),
                ),
                SingleChildScrollView(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                          maxWidth: ResponsiveUtils.getContentWidth(context,
                              maxWidth: 500)),
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 40,
                                      tablet: 50,
                                      desktop: 60)),
                              Text(
                                'Security Registration',
                                style: TextStyle(
                                  fontSize: titleFontSize,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.0,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Register as security personnel for parking space management',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 32,
                                      tablet: 40,
                                      desktop: 48)),
                              Form(
                                key: _formKey,
                                child: Column(
                                  children: [
                                    _ModernTextField(
                                      controller: _nameController,
                                      label: 'Full Name',
                                      prefixIcon: Icons.person_outline_rounded,
                                      validator: (v) => v?.isEmpty == true
                                          ? 'Required'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    _ModernTextField(
                                      controller: _emailController,
                                      label: 'Email',
                                      keyboardType: TextInputType.emailAddress,
                                      prefixIcon: Icons.alternate_email_rounded,
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
                                    ),
                                    const SizedBox(height: 16),
                                    _ModernTextField(
                                      controller: _phoneController,
                                      label: 'Phone Number',
                                      keyboardType: TextInputType.phone,
                                      prefixIcon: Icons.phone_android_rounded,
                                      validator: (v) => v?.isEmpty == true
                                          ? 'Required'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    // Parking Space Selection
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.06)
                                            : Colors.black.withValues(alpha: 0.04),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: DropdownButtonFormField<int>(
                                        initialValue: _selectedParkingSpaceId,
                                        items: _parkingSpaces.map((space) {
                                          return DropdownMenuItem<int>(
                                            value: space.id,
                                            child: Text(
                                              '${space.name} - ${space.address}',
                                              style: TextStyle(
                                                color: isDark ? Colors.white : Colors.black87,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                        onChanged: _isLoadingSpaces
                                            ? null
                                            : (val) => setState(() => _selectedParkingSpaceId = val),
                                        decoration: const InputDecoration(
                                          labelText: 'Assigned Parking Space',
                                          prefixIcon: Icon(Icons.location_on_outlined, size: 22),
                                          border: InputBorder.none,
                                          contentPadding: EdgeInsets.symmetric(vertical: 18),
                                        ),
                                        validator: (v) => v == null ? 'Please select a parking space' : null,
                                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      ),
                                    ),
                                    if (_isLoadingSpaces)
                                      const Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: Center(child: CircularProgressIndicator()),
                                      ),
                                    const SizedBox(height: 16),
                                    _ModernTextField(
                                      controller: _passwordController,
                                      label: 'Password',
                                      obscureText: _obscurePassword,
                                      prefixIcon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                      validator: (v) => (v != null && v.length < 6)
                                          ? 'Min 6 characters'
                                          : null,
                                    ),
                                    const SizedBox(height: 16),
                                    _ModernTextField(
                                      controller: _confirmPasswordController,
                                      label: 'Confirm Password',
                                      obscureText: _obscureConfirmPassword,
                                      prefixIcon: Icons.lock_outline_rounded,
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscureConfirmPassword
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined),
                                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                      ),
                                      validator: (v) {
                                        if (v != _passwordController.text)
                                          return 'Passwords do not match';
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 24,
                                      tablet: 32,
                                      desktop: 40)),
                              Row(
                                children: [
                                  Checkbox(
                                    value: _acceptTerms,
                                    onChanged: (value) {
                                      setState(() => _acceptTerms = value ?? false);
                                    },
                                    activeColor: theme.colorScheme.primary,
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () => setState(() => _acceptTerms = !_acceptTerms),
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: ResponsiveUtils.responsiveFontSize(
                                              context,
                                              mobile: 14,
                                              tablet: 16,
                                              desktop: 16,
                                            ),
                                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                                          ),
                                          children: [
                                            const TextSpan(text: 'I agree to the '),
                                            TextSpan(
                                              text: 'Terms and Conditions',
                                              style: TextStyle(
                                                color: theme.colorScheme.primary,
                                                fontWeight: FontWeight.w500,
                                                decoration: TextDecoration.underline,
                                              ),
                                              recognizer: TapGestureRecognizer()
                                                ..onTap = () => Navigator.pushNamed(
                                                    context, '/terms-and-conditions'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (!_acceptTerms)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    'Please accept the terms and conditions to continue',
                                    style: TextStyle(
                                      color: Colors.red[400],
                                      fontSize: ResponsiveUtils.responsiveFontSize(
                                        context,
                                        mobile: 12,
                                        tablet: 14,
                                        desktop: 14,
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
                              _GradientButton(
                                isLoading: _isLoading,
                                onPressed: (_isLoading || _isLoadingSpaces || !_acceptTerms) ? null : _handleRegister,
                                label: 'Register as Security',
                              ),
                              SizedBox(
                                  height: ResponsiveUtils.responsivePadding(
                                      context,
                                      mobile: 16,
                                      tablet: 20,
                                      desktop: 24)),
                              // Terms and Conditions link at bottom
                              Center(
                                child: TextButton(
                                  onPressed: () => Navigator.pushNamed(context, '/terms-and-conditions'),
                                  child: Text(
                                    'View Terms and Conditions',
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
                                      mobile: 24,
                                      tablet: 32,
                                      desktop: 40)),
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

class _ModernTextField extends StatelessWidget {
  const _ModernTextField({
    required this.controller,
    required this.label,
    this.keyboardType,
    this.validator,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
  });

  final TextEditingController controller;
  final String label;
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
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 22) : null,
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  const _GradientButton(
      {required this.isLoading, required this.onPressed, required this.label});

  final bool isLoading;
  final VoidCallback? onPressed;
  final String label;

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
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35),
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
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4)),
          ),
        ),
      ),
    );
  }
}