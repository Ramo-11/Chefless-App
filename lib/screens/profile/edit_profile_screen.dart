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

    // In a production flow this would upload to an API route which then
    // uploads to Cloudinary and returns the URL. For now we store the local
    // path as a placeholder.
    setState(() {
      _profilePictureUrl = pickedFile.path;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final result = await apiService.put(
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

      // Refresh profile data.
      ref.invalidate(currentUserProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated.')),
        );
        context.pop();
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
            onPressed: _isSaving ? null : _save,
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: context.colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                size: 16,
                                color: context.colorScheme.onPrimary,
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
                        color: context.colorScheme.errorContainer,
                        borderRadius: AppTheme.borderRadiusSmall,
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: context.colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacingMd),
                  ],

                  // Full name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                    ),
                    textCapitalization: TextCapitalization.words,
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
                      // Force rebuild so the counter updates.
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
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Privacy toggle
                  SwitchListTile(
                    title: const Text('Public Account'),
                    subtitle: Text(
                      _isPublic
                          ? 'Anyone can see your profile and shared recipes.'
                          : 'Only approved followers can see your profile and shared recipes.',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    value: _isPublic,
                    onChanged: (value) {
                      if (mounted) setState(() => _isPublic = value);
                    },
                    contentPadding: EdgeInsets.zero,
                  ),

                  const SizedBox(height: AppTheme.spacingLg),

                  // Dietary preferences
                  Text(
                    'Dietary Preferences',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
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
                  Text(
                    'Cuisine Preferences',
                    style: context.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
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
}
