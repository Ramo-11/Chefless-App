import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/extensions.dart';

/// Initial splash screen shown while the app initializes.
/// Shows connection errors with an option to change the server address.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final currentUser = ref.watch(currentUserProvider);
    final email = authState.valueOrNull?.email;

    final hasConnectionError =
        currentUser.hasError && authState.valueOrNull != null;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: hasConnectionError
              ? _ConnectionError(
                  error: currentUser.error.toString(),
                  onRetry: () => ref.invalidate(currentUserProvider),
                )
              : _LoadingState(email: email),
        ),
      ),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/images/logo.png',
          width: 120,
          height: 120,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: context.colorScheme.primary,
          ),
        ),
        if (email != null) ...[
          const SizedBox(height: 24),
          Text(
            'Signed in as $email',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _ConnectionError extends ConsumerStatefulWidget {
  const _ConnectionError({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  ConsumerState<_ConnectionError> createState() => _ConnectionErrorState();
}

class _ConnectionErrorState extends ConsumerState<_ConnectionError> {
  late final TextEditingController _urlController;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: AppConstants.apiBaseUrl);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;

    setState(() => _isRetrying = true);

    // Update the base URL and force a fresh ApiService + user fetch.
    AppConstants.apiBaseUrl = newUrl;
    ref.invalidate(apiServiceProvider);
    ref.invalidate(currentUserProvider);

    // Wait for the provider to actually resolve or fail.
    try {
      await ref.read(currentUserProvider.future);
    } catch (_) {
      // Error will be shown by the parent widget via currentUser.hasError.
    }
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 64,
            color: context.colorScheme.error,
          ),
          const SizedBox(height: AppTheme.spacingMd),
          Text(
            'Cannot connect to server',
            style: context.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: AppTheme.spacingSm),
          Text(
            widget.error.replaceFirst('Exception: ', ''),
            style: context.textTheme.bodyMedium?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          if (AppConstants.debugMode) ...[
            const SizedBox(height: AppTheme.spacingLg),
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                prefixIcon: Icon(Icons.dns_outlined),
                hintText: 'http://192.168.x.x:3000/api',
              ),
              keyboardType: TextInputType.url,
              autocorrect: false,
              onSubmitted: (_) => _retry(),
            ),
          ],
          const SizedBox(height: AppTheme.spacingLg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isRetrying ? null : _retry,
              icon: _isRetrying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
              label: Text(_isRetrying ? 'Connecting...' : 'Retry'),
            ),
          ),
        ],
      ),
    );
  }
}
