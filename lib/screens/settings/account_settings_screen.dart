import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';

/// Account settings screen showing email, sign-in method, password change,
/// and account information.
class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (user == null || firebaseUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final providerId = firebaseUser.providerData.isNotEmpty
        ? firebaseUser.providerData.first.providerId
        : 'password';
    final isEmailUser = providerId == 'password';

    return Scaffold(
      appBar: AppBar(title: const Text('Account Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppTheme.spacing48),
        children: [
          // ── Email ──────────────────────────────────────────
          const _SectionHeader(title: 'EMAIL'),
          _SettingsGroup(
            children: [
              _InfoRow(
                icon: Icons.email_outlined,
                label: 'Email address',
                value: user.email,
                valueIsBold: true,
              ),
            ],
          ),

          // ── Sign-in Method ─────────────────────────────────
          const _SectionHeader(title: 'SIGN-IN METHOD'),
          _SettingsGroup(
            children: [
              _SignInMethodRow(providerId: providerId),
            ],
          ),

          // ── Security ───────────────────────────────────────
          if (isEmailUser) ...[
            const _SectionHeader(title: 'SECURITY'),
            _SettingsGroup(
              children: [
                _ActionRow(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your account password',
                  onTap: () => _showChangePasswordSheet(context, ref),
                ),
              ],
            ),
          ],

          // ── Account Info ───────────────────────────────────
          const _SectionHeader(title: 'ACCOUNT INFO'),
          _SettingsGroup(
            children: [
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Member since',
                value: DateFormat.yMMMM().format(user.createdAt),
              ),
              const _GroupDivider(),
              _InfoRow(
                icon: Icons.update_outlined,
                label: 'Last active',
                value: _formatRelativeDate(user.lastActiveAt),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat.yMMMd().format(date);
  }

  void _showChangePasswordSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _ChangePasswordSheet(ref: ref),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacing20,
        right: AppTheme.spacing20,
        top: AppTheme.spacing32,
        bottom: AppTheme.spacing8,
      ),
      child: Text(
        title,
        style: context.textTheme.labelSmall?.copyWith(
          color: AppTheme.gray400,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Settings Group ───────────────────────────────────────────────────────────

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(color: AppTheme.gray200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

// ── Group Divider ────────────────────────────────────────────────────────────

class _GroupDivider extends StatelessWidget {
  const _GroupDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppTheme.spacing16 + 32 + AppTheme.spacing12,
      ),
      child: Container(height: 1, color: AppTheme.gray100),
    );
  }
}

// ── Info Row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueIsBold = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool valueIsBold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.gray600.withValues(alpha: 0.08),
              borderRadius: AppTheme.borderRadiusSmall,
            ),
            child: Icon(icon, size: 18, color: AppTheme.gray600),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          Flexible(
            child: Text(
              value,
              style: context.textTheme.bodyMedium?.copyWith(
                fontWeight: valueIsBold ? FontWeight.w600 : FontWeight.w400,
                color: AppTheme.gray900,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sign-in Method Row ───────────────────────────────────────────────────────

class _SignInMethodRow extends StatelessWidget {
  const _SignInMethodRow({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (providerId) {
      'google.com' => (Icons.g_mobiledata, 'Google'),
      'apple.com' => (Icons.apple, 'Apple'),
      _ => (Icons.email_outlined, 'Email & Password'),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing12,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.gray600.withValues(alpha: 0.08),
              borderRadius: AppTheme.borderRadiusSmall,
            ),
            child: Icon(icon, size: 18, color: AppTheme.gray600),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(
              'Signed in with',
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing12,
              vertical: AppTheme.spacing4,
            ),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: AppTheme.borderRadiusFull,
            ),
            child: Text(
              label,
              style: context.textTheme.labelMedium?.copyWith(
                color: AppTheme.primaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Action Row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing16,
            vertical: AppTheme.spacing12,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.gray600.withValues(alpha: 0.08),
                  borderRadius: AppTheme.borderRadiusSmall,
                ),
                child: Icon(icon, size: 18, color: AppTheme.gray600),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: context.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppTheme.gray900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: AppTheme.gray500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppTheme.gray300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Change Password Bottom Sheet ─────────────────────────────────────────────

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_ChangePasswordSheet> createState() =>
      _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authService = ref.read(authServiceProvider);
    final result = await authService.changePassword(
      currentPassword: _currentPasswordController.text,
      newPassword: _newPasswordController.text,
    );

    if (!mounted) return;

    if (result.success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated successfully.')),
      );
    } else {
      setState(() {
        _error = result.error;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppTheme.spacingLg,
        right: AppTheme.spacingLg,
        top: AppTheme.spacingSm,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLg,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Change Password',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              'Enter your current password and choose a new one.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Error message
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingMd),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: AppTheme.borderRadiusSmall,
                  border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 18,
                      color: AppTheme.error,
                    ),
                    const SizedBox(width: AppTheme.spacing8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: context.textTheme.bodySmall?.copyWith(
                          color: AppTheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.spacingMd),
            ],

            // Current password
            TextFormField(
              controller: _currentPasswordController,
              obscureText: _obscureCurrent,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Current Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureCurrent
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter your current password.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // New password
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock_reset_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureNew
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Enter a new password.';
                }
                if (value.length < 8) {
                  return 'Password must be at least 8 characters.';
                }
                if (value == _currentPasswordController.text) {
                  return 'New password must be different from current.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Confirm new password
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm New Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (value) {
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match.';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Update Password'),
            ),
            const SizedBox(height: AppTheme.spacingSm),
          ],
        ),
      ),
    );
  }
}
