import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';
import '../../utils/validators.dart';

/// Account creation screen with email/password and social sign-in options.
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.signUpWithEmail(
      email: _emailController.text,
      password: _passwordController.text,
      fullName: _fullNameController.text,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success && result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.signInWithGoogle();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success && result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);

    final authService = ref.read(authServiceProvider);
    final result = await authService.signInWithApple();

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (!result.success && result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/welcome'),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing32,
              vertical: AppTheme.spacing24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Image.asset(
                      'assets/images/logo.png',
                      width: 80,
                      height: 80,
                    ),
                    const SizedBox(height: AppTheme.spacing16),
                    Text(
                      'Create Account',
                      textAlign: TextAlign.center,
                      style: context.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing6),
                    Text(
                      'Join Chefless and start cooking',
                      textAlign: TextAlign.center,
                      style: context.textTheme.bodyLarge?.copyWith(
                        color: AppTheme.gray500,
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing40),

                    // ── Full Name Field ─────────────────────────────────
                    TextFormField(
                      controller: _fullNameController,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter your full name.';
                        }
                        if (value.trim().length < 2) {
                          return 'Name must be at least 2 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.spacing16),

                    // ── Email Field ─────────────────────────────────────
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: validateEmail,
                    ),
                    const SizedBox(height: AppTheme.spacing16),

                    // ── Password Field ──────────────────────────────────
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signUpWithEmail(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outlined),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          tooltip: _obscurePassword
                              ? 'Show password'
                              : 'Hide password',
                          onPressed: () {
                            setState(
                                () => _obscurePassword = !_obscurePassword);
                          },
                        ),
                      ),
                      validator: (value) => validatePassword(value, requireStrength: true),
                    ),
                    const SizedBox(height: AppTheme.spacing32),

                    // ── Create Account Button ───────────────────────────
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signUpWithEmail,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusMedium,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Create Account'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing32),

                    // ── Divider ─────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(child: Divider(color: AppTheme.gray200)),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppTheme.spacing16),
                          child: Text(
                            'or',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: AppTheme.gray400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: AppTheme.gray200)),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing32),

                    // ── Google Sign-In ───────────────────────────────────
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _isLoading ? null : _signInWithGoogle,
                        icon: const Icon(Icons.g_mobiledata, size: 24),
                        label: const Text('Continue with Google'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusFull,
                          ),
                          side: BorderSide(color: AppTheme.gray200),
                          foregroundColor: AppTheme.gray800,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),

                    // ── Apple Sign-In (iOS only) ────────────────────────
                    if (Platform.isIOS) ...[
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _signInWithApple,
                          icon: const Icon(Icons.apple, size: 24),
                          label: const Text('Continue with Apple'),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: AppTheme.borderRadiusFull,
                            ),
                            side: BorderSide(color: AppTheme.gray200),
                            foregroundColor: AppTheme.gray800,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppTheme.spacing12),
                    ],

                    const SizedBox(height: AppTheme.spacing16),

                    // ── Sign In Link ────────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: context.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.gray500,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              _isLoading ? null : () => context.go('/login'),
                          child: Text(
                            'Sign In',
                            style: context.textTheme.bodyMedium?.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
