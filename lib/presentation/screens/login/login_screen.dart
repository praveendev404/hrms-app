import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/custom_text_field.dart';
import '../../widgets/common/loading_widget.dart';
import '../../widgets/common/logo_widget.dart';
import '../dashboard/dashboard_screen.dart';

/// Login screen for user authentication
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final success = await ref.read(authProvider.notifier).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (success && mounted) {
      final authState = ref.read(authProvider);
      
      // Check if password change is required
      if (authState.status == AuthStatus.requiresPasswordChange) {
        // TODO: Navigate to change password screen
        // Navigator.of(context).pushReplacement(
        //   MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
        // );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password change is required'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isLoading = authState.status == AuthStatus.loading;

    // Show error snackbar
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        ref.read(authProvider.notifier).clearError();
      }
    });

    return Scaffold(
      body: LoadingOverlay(
        isLoading: isLoading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 48),

                      // Logo and Title
                      _buildHeader(context),
                      const SizedBox(height: 16),

                      // Login Form
                      _buildLoginForm(context),
                      const SizedBox(height: 8),

                      // Login Button
                      _buildLoginButton(context, isLoading),
                      const SizedBox(height: 8),

                      // Footer
                      _buildFooter(context),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Info Quest Logo
        const LogoWidget(
          width: 120,
          height: 120,
          showText: false,
        ),
        const SizedBox(height: 24),

        // App Name
        Text(
          'HRMS App',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF1A1D1F),
                letterSpacing: -0.3,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),

        // Welcome Text
        // Text(
        //   AppStrings.welcomeBack,
        //   style: Theme.of(context).textTheme.titleLarge?.copyWith(
        //         fontWeight: FontWeight.w600,
        //         color: const Color(0xFF1A1D1F),
        //       ),
        //   textAlign: TextAlign.center,
        // ),
        const SizedBox(height: 4),

        // Subtitle
        Text(
          AppStrings.loginSubtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey.shade600,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Column(
      children: [
        // Email Field
        CustomTextField(
          controller: _emailController,
          labelText: 'Email',
          hintText: 'Enter your email',
          prefixIcon: Icons.email_outlined,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
          validator: Validators.validateEmail,
        ),
        const SizedBox(height: 16),

        // Password Field
        CustomTextField(
          controller: _passwordController,
          labelText: AppStrings.password,
          hintText: 'Enter your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _handleLogin(),
          validator: Validators.validatePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.textSecondaryLight,
            ),
            onPressed: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton(BuildContext context, bool isLoading) {
    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: isLoading ? null : _handleLogin,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(AppStrings.login),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        // Powered By Info Quest
        // Row(
        //   mainAxisAlignment: MainAxisAlignment.center,
        //   children: [
        //     // Text(
        //     //   AppStrings.poweredBy,
        //     //   style: Theme.of(context).textTheme.bodySmall?.copyWith(
        //     //         color: Colors.grey.shade500,
        //     //         fontSize: 12,
        //     //       ),
        //     // ),
        //     // const SizedBox(width: 6),
        //     // const LogoWidget(
        //     //   width: 80,
        //     //   height: 32,
        //     //   showText: true,
        //     // ),
        //   ],
        // ),
        const SizedBox(height: 16),
        Text(
          'Version 1.0.0',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade400,
                fontSize: 11,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '© ${DateTime.now().year} Hrms. All rights reserved.',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade400,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}

