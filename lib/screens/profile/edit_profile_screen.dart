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

/// All available dietary preference options.
const List<String> _dietaryOptions = [
  'Halal',
  'Vegan',
  'Vegetarian',
  'Gluten-Free',
  'Dairy-Free',
  'Nut-Free',
];

/// All available cuisine preference options.
const List<String> _cuisineOptions = [
  'Middle Eastern',
  'Italian',
  'Mexican',
  'Asian',
  'American',
  'Indian',
  'Mediterranean',
  'French',
  'Japanese',
  'Thai',
  'Korean',
  'Greek',
];

/// Edit profile form: name, bio, phone, photo, privacy, dietary and cuisine
/// preferences.
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _phoneController;

  late bool _isPublic;
  late Set<String> _selectedDietary;
  late Set<String> _selectedCuisine;
  String? _profilePictureUrl;
  bool _isSaving = false;
  String? _error;

  // Snapshot of original values for dirty-checking.
  String _originalName = '';
  String _originalBio = '';
  String _originalPhone = '';
  bool _originalIsPublic = true;
  Set<String> _originalDietary = {};
  Set<String> _originalCuisine = {};
  String? _originalProfilePicture;

  bool get _hasChanges {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return false;
    return _nameController.text.trim() != _originalName ||
        _bioController.text.trim() != _originalBio ||
        _phoneController.text.trim() != _originalPhone ||
        _isPublic != _originalIsPublic ||
        !_setEquals(_selectedDietary, _originalDietary) ||
        !_setEquals(_selectedCuisine, _originalCuisine) ||
        _profilePictureUrl != _originalProfilePicture;
  }

  static bool _setEquals(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _bioController = TextEditingController();
    _phoneController = TextEditingController();
    _isPublic = true;
    _selectedDietary = {};
    _selectedCuisine = {};

    // Pre-populate from current user once available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _populateFromUser();
    });
  }

  void _populateFromUser() {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    if (!mounted) return;
    setState(() {
      _nameController.text = user.fullName;
      _bioController.text = user.bio ?? '';
      _phoneController.text = user.phone ?? '';
      _isPublic = user.isPublic;
      _selectedDietary = user.dietaryPreferences.toSet();
      _selectedCuisine = user.cuisinePreferences.toSet();
      _profilePictureUrl = user.profilePicture;

      // Snapshot for dirty-checking.
      _originalName = user.fullName;
      _originalBio = user.bio ?? '';
      _originalPhone = user.phone ?? '';
      _originalIsPublic = user.isPublic;
      _originalDietary = user.dietaryPreferences.toSet();
      _originalCuisine = user.cuisinePreferences.toSet();
      _originalProfilePicture = user.profilePicture;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _phoneController.dispose();
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
    if (source == null) return;

    final pickedFile = await picker.pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (pickedFile == null || !mounted) return;

    // Show the local preview immediately while uploading
    setState(() {
      _profilePictureUrl = pickedFile.path;
      _isSaving = true;
    });

    try {
      final bytes = await File(pickedFile.path).readAsBytes();
      final ext = pickedFile.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.post(
        '/users/me/profile-picture',
        data: {'image': dataUri},
      );

      if (!mounted) return;

      if (result.isSuccess && result.data != null) {
        final userData = result.data!['user'];
        if (userData is Map<String, dynamic>) {
          setState(() {
            _profilePictureUrl = userData['profilePicture'] as String?;
          });
          ref.invalidate(currentUserProvider);
        }
      } else {
        setState(() {
          _profilePictureUrl =
              ref.read(currentUserProvider).valueOrNull?.profilePicture;
          _error = result.error ?? 'Failed to upload photo.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profilePictureUrl =
            ref.read(currentUserProvider).valueOrNull?.profilePicture;
        _error = 'Failed to upload photo.';
      });
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.patch(
        '/users/me',
        data: {
          'fullName': _nameController.text.trim(),
          'bio': _bioController.text.trim(),
          'phone': _phoneController.text.trim().isEmpty
              ? null
              : _phoneController.text.trim(),
          'isPublic': _isPublic,
          'dietaryPreferences': _selectedDietary.toList(),
          'cuisinePreferences': _selectedCuisine.toList(),
        },
      );

      if (!mounted) return;

      if (result.isFailure) {
        setState(() {
          _error = result.error ?? 'Failed to save profile.';
          _isSaving = false;
        });
        return;
      }

      // Refresh profile data and wait for it before navigating back.
      ref.invalidate(currentUserProvider);
      await ref.read(currentUserProvider.future);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
        context.go(_profileRouteForCurrentBranch(context));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'An unexpected error occurred.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        actions: [
          TextButton(
            onPressed: _isSaving || !_hasChanges ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(AppTheme.spacingLg),
                children: [
                  // Profile picture
                  Center(
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        children: [
                          UserAvatar(
                            fullName:
                                _nameController.text.isEmpty
                                    ? user.fullName
                                    : _nameController.text,
                            profilePictureUrl: _profilePictureUrl,
                            size: 96,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(AppTheme.spacing6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Error message
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: AppTheme.errorLight,
                        borderRadius: AppTheme.borderRadiusMedium,
                        border: Border.all(
                          color: AppTheme.error.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 18,
                            color: AppTheme.error,
                          ),
                          const SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: context.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                  ],

                  // Section label
                  _SectionLabel(label: 'Personal Information'),
                  const SizedBox(height: AppTheme.spacing12),

                  // Full name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                    ),
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) {
                      if (mounted) setState(() {});
                    },
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Name is required.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: AppTheme.spacingMd),

                  // Bio
                  TextFormField(
                    controller: _bioController,
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      counterText:
                          '${_bioController.text.length}/150',
                    ),
                    maxLength: 150,
                    maxLines: 3,
                    onChanged: (_) {
                      if (mounted) setState(() {});
                    },
                  ),

                  const SizedBox(height: AppTheme.spacingMd),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone (optional)',
                    ),
                    onChanged: (_) {
                      if (mounted) setState(() {});
                    },
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Privacy toggle
                  _SectionLabel(label: 'Privacy'),
                  const SizedBox(height: AppTheme.spacing12),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.gray50,
                      borderRadius: AppTheme.borderRadiusMedium,
                      border: Border.all(color: AppTheme.gray200),
                    ),
                    child: SwitchListTile(
                      title: Text(
                        'Public Account',
                        style: context.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          color: AppTheme.gray900,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: AppTheme.spacing4),
                        child: Text(
                          _isPublic
                              ? 'Anyone can see your profile and shared recipes.'
                              : 'Only approved followers can see your profile and shared recipes.',
                          style: context.textTheme.bodySmall?.copyWith(
                            color: AppTheme.gray500,
                          ),
                        ),
                      ),
                      value: _isPublic,
                      onChanged: (value) {
                        if (mounted) setState(() => _isPublic = value);
                      },
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                        vertical: AppTheme.spacing4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppTheme.borderRadiusMedium,
                      ),
                    ),
                  ),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Dietary preferences
                  _SectionLabel(label: 'Dietary Preferences'),
                  const SizedBox(height: AppTheme.spacing12),
                  Wrap(
                    spacing: AppTheme.spacingSm,
                    runSpacing: AppTheme.spacingSm,
                    children: _dietaryOptions.map((option) {
                      final selected = _selectedDietary.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (value) {
                          if (!mounted) return;
                          setState(() {
                            if (value) {
                              _selectedDietary.add(option);
                            } else {
                              _selectedDietary.remove(option);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Cuisine preferences
                  _SectionLabel(label: 'Cuisine Preferences'),
                  const SizedBox(height: AppTheme.spacing12),
                  Wrap(
                    spacing: AppTheme.spacingSm,
                    runSpacing: AppTheme.spacingSm,
                    children: _cuisineOptions.map((option) {
                      final selected = _selectedCuisine.contains(option);
                      return FilterChip(
                        label: Text(option),
                        selected: selected,
                        onSelected: (value) {
                          if (!mounted) return;
                          setState(() {
                            if (value) {
                              _selectedCuisine.add(option);
                            } else {
                              _selectedCuisine.remove(option);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: AppTheme.spacingXl),
                ],
              ),
            ),
    );
  }

  String _profileRouteForCurrentBranch(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    const branchRoots = [
      '/home',
      '/schedule',
      '/recipes',
      '/shopping',
      '/kitchen',
    ];

    for (final root in branchRoots) {
      if (location.startsWith('$root/profile')) {
        return '$root/profile';
      }
    }

    return '/home/profile';
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: context.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppTheme.gray700,
        letterSpacing: -0.1,
      ),
    );
  }
}
