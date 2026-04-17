import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/onboarding_progress_bar.dart';
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
    // First try the MongoDB user (returning users resuming onboarding).
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user != null && user.fullName.isNotEmpty && mounted) {
      setState(() => _nameController.text = user.fullName);
      return;
    }

    // Fallback to Firebase displayName (new Google/Apple/email users).
    final firebaseUser = ref.read(authServiceProvider).currentUser;
    if (firebaseUser != null &&
        firebaseUser.displayName != null &&
        firebaseUser.displayName!.isNotEmpty &&
        mounted) {
      setState(() => _nameController.text = firebaseUser.displayName!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.lightImpact();
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
    HapticFeedback.lightImpact();

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

      // Upload profile picture if one was picked (non-blocking — warn on failure).
      if (_pickedImagePath != null) {
        final bytes = await File(_pickedImagePath!).readAsBytes();
        final ext = _pickedImagePath!.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

        final imageResult = await apiService.post(
          '/users/me/profile-picture',
          data: {'image': dataUri},
        );

        if (imageResult.isFailure && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Photo upload failed — you can add it later from your profile.',
              ),
            ),
          );
        }
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

  Future<void> _skip() async {
    HapticFeedback.selectionClick();
    // Must register the user in MongoDB even when skipping, otherwise
    // PATCH /users/me calls later in onboarding will 404.
    final existingUser = ref.read(currentUserProvider).valueOrNull;
    if (existingUser != null) {
      // Already registered — safe to skip.
      context.go('/onboarding/dietary');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authService = ref.read(authServiceProvider);
      final firebaseUser = authService.currentUser;
      if (firebaseUser == null) {
        if (mounted) context.go('/login');
        return;
      }

      final fullName = firebaseUser.displayName?.isNotEmpty == true
          ? firebaseUser.displayName!
          : (firebaseUser.email?.split('@').first ?? 'Chefless User');

      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/auth/register',
        data: {
          'fullName': fullName,
          'email': firebaseUser.email ?? '',
        },
      );

      if (!mounted) return;

      if (result.isFailure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.error ?? 'Failed to create account.'),
          ),
        );
        setState(() => _isSaving = false);
        return;
      }

      context.go('/onboarding/dietary');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('An unexpected error occurred.')),
      );
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        _nameController.text.isEmpty ? 'You' : _nameController.text;

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
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
            padding: EdgeInsets.zero,
            children: [
              const OnboardingProgressBar(current: 1),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppTheme.spacing8),

                    Text(
                      'Let\'s set up your profile',
                      style: AppTheme.displayTitleMedium(),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spacing10),
                    const Text(
                      'Add your name and a photo so others in shared kitchens can recognize you.',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                        color: AppTheme.gray600,
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppTheme.spacing40),

                    // Avatar picker with ripple feedback
                    Center(
                      child: SizedBox(
                        width: 124,
                        height: 124,
                        child: Stack(
                          clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: _pickImage,
                                splashColor:
                                    AppTheme.primaryColor.withValues(alpha: 0.12),
                                highlightColor:
                                    AppTheme.primaryColor.withValues(alpha: 0.05),
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: UserAvatar(
                                    fullName: displayName,
                                    profilePictureUrl: _pickedImagePath,
                                    size: 112,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  padding:
                                      const EdgeInsets.all(AppTheme.spacing8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppTheme.surfaceWarm,
                                      width: 3,
                                    ),
                                    boxShadow: AppTheme.shadowSm,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: AppTheme.spacing12),

                    Text(
                      _pickedImagePath == null
                          ? 'Tap to add a photo'
                          : 'Tap to change',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray500,
                        letterSpacing: -0.1,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: AppTheme.spacing32),

                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline_rounded),
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

                    const SizedBox(height: AppTheme.spacing32),

                    // Continue button
                    SizedBox(
                      height: 54,
                      child: FilledButton(
                        onPressed: _isSaving ? null : _saveAndContinue,
                        style: FilledButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: AppTheme.borderRadiusMedium,
                          ),
                        ),
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
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
