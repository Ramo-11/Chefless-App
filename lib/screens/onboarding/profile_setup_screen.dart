import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../utils/extensions.dart';
import '../../widgets/user_avatar.dart';

/// Onboarding step: set up display name and optional profile picture.
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() =>
      _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _pickedImagePath;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillName();
    });
  }

  void _prefillName() {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null && mounted) {
      setState(() {
        _nameController.text = user.fullName;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile == null || !mounted) return;

    setState(() {
      _pickedImagePath = pickedFile.path;
    });
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final fullName = _nameController.text.trim();

      // Check if the user already exists in the API.
      final existingUser = ref.read(currentUserProvider).valueOrNull;

      if (existingUser == null) {
        // First time — register the user in MongoDB.
        final authService = ref.read(authServiceProvider);
        final firebaseUser = authService.currentUser;

        if (firebaseUser == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Not signed in. Please sign in first.')),
          );
          setState(() => _isSaving = false);
          return;
        }

        final registerResult = await apiService.post(
          '/auth/register',
          data: {
            'fullName': fullName,
            'email': firebaseUser.email ?? '',
          },
        );

        if (!mounted) return;

        if (registerResult.isFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(registerResult.error ?? 'Failed to create account.'),
            ),
          );
          setState(() => _isSaving = false);
          return;
        }
      } else {
        // User exists — just update the name.
        final result = await apiService.patch(
          '/users/me',
          data: {'fullName': fullName},
        );

        if (!mounted) return;

        if (result.isFailure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(result.error ?? 'Failed to save name.')),
          );
          setState(() => _isSaving = false);
          return;
        }
      }

      // Upload profile picture if one was picked.
      if (_pickedImagePath != null) {
        final bytes = await File(_pickedImagePath!).readAsBytes();
        final ext = _pickedImagePath!.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

        await apiService.post(
          '/users/me/profile-picture',
          data: {'image': dataUri},
        );
      }

      // Don't invalidate currentUserProvider here — it triggers the router
      // redirect which sends us back to /onboarding/profile while reloading.
      // The provider will be refreshed at the end of onboarding.
      if (mounted) context.go('/onboarding/dietary');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
      setState(() => _isSaving = false);
    }
  }

  void _skip() {
    context.go('/onboarding/dietary');
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        _nameController.text.isEmpty ? 'You' : _nameController.text;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _skip,
            child: const Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            children: [
              const SizedBox(height: AppTheme.spacingMd),

              // Heading
              Text(
                'Let\'s set up your profile',
                style: context.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spacingSm),
              Text(
                'Tell us your name and add a photo so others can recognize you.',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spacingXl),

              // Avatar picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      UserAvatar(
                        fullName: displayName,
                        profilePictureUrl: _pickedImagePath,
                        size: 110,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: context.colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.colorScheme.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: context.colorScheme.onPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: AppTheme.spacingXl),

              // Name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: (_) {
                  if (mounted) setState(() {});
                },
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your name.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: AppTheme.spacingXl),

              // Continue button
              FilledButton(
                onPressed: _isSaving ? null : _saveAndContinue,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
