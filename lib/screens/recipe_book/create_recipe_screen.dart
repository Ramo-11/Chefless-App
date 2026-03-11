import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/constants.dart';
import '../../utils/extensions.dart';

/// System-defined recipe labels.
const _systemLabels = [
  'Breakfast',
  'Lunch',
  'Dinner',
  'Snack',
  'Dessert',
  'Drink',
];

/// Dietary tag options.
const _dietaryOptions = [
  'Halal',
  'Vegan',
  'Vegetarian',
  'Gluten-Free',
  'Dairy-Free',
  'Nut-Free',
  'Keto',
  'Paleo',
];

/// Cuisine tag options.
const _cuisineOptions = [
  'Middle Eastern',
  'Italian',
  'Mexican',
  'Indian',
  'Chinese',
  'Japanese',
  'Thai',
  'Korean',
  'French',
  'Mediterranean',
  'American',
  'African',
];

/// Difficulty levels.
const _difficultyOptions = ['easy', 'medium', 'hard'];

/// Cost estimate options.
const _costOptions = ['budget', 'moderate', 'expensive'];

/// Recipe creation form with title, description, photos, ingredients, steps,
/// labels, tags, and metadata fields.
class CreateRecipeScreen extends ConsumerStatefulWidget {
  const CreateRecipeScreen({super.key});

  @override
  ConsumerState<CreateRecipeScreen> createState() =>
      _CreateRecipeScreenState();
}

class _CreateRecipeScreenState extends ConsumerState<CreateRecipeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _storyController = TextEditingController();
  final _customLabelController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  final _baseServingsController = TextEditingController();
  final _caloriesController = TextEditingController();

  final List<_IngredientEntry> _ingredients = [_IngredientEntry()];
  final List<_StepEntry> _steps = [_StepEntry()];
  final List<String> _photoUrls = [];
  final Set<String> _selectedLabels = {};
  final Set<String> _selectedDietaryTags = {};
  final Set<String> _selectedCuisineTags = {};
  String? _selectedDifficulty;
  String? _selectedCostEstimate;
  bool _isPrivate = false;
  bool _showSignature = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _storyController.dispose();
    _customLabelController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _baseServingsController.dispose();
    _caloriesController.dispose();
    for (final ingredient in _ingredients) {
      ingredient.dispose();
    }
    for (final step in _steps) {
      step.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    if (_photoUrls.length >= AppConstants.maxRecipePhotos) {
      _showMessage('Maximum ${AppConstants.maxRecipePhotos} photos allowed.');
      return;
    }

    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null || !mounted) return;

    if (mounted) setState(() => _isUploadingPhoto = true);

    try {
      final apiService = await ref.read(apiServiceProvider.future);
      final bytes = await image.readAsBytes();
      final fileName = image.name;

      // Upload via API route (not direct to Cloudinary).
      final result = await apiService.post(
        '/recipes/upload-photo',
        data: {
          'file': bytes.toList(),
          'fileName': fileName,
        },
      );

      if (!mounted) return;

      if (result.isSuccess && result.data != null) {
        final url = result.data!['url'] as String;
        setState(() {
          _photoUrls.add(url);
          _isUploadingPhoto = false;
        });
      } else {
        setState(() => _isUploadingPhoto = false);
        _showMessage(result.error ?? 'Failed to upload photo.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
        _showMessage('Failed to upload photo.');
      }
    }
  }

  void _removePhoto(int index) {
    if (mounted) {
      setState(() => _photoUrls.removeAt(index));
    }
  }

  void _addIngredient() {
    if (mounted) {
      setState(() => _ingredients.add(_IngredientEntry()));
    }
  }

  void _removeIngredient(int index) {
    if (_ingredients.length <= 1) return;
    if (mounted) {
      setState(() {
        _ingredients[index].dispose();
        _ingredients.removeAt(index);
      });
    }
  }

  void _addStep() {
    if (mounted) {
      setState(() => _steps.add(_StepEntry()));
    }
  }

  void _removeStep(int index) {
    if (_steps.length <= 1) return;
    if (mounted) {
      setState(() {
        _steps[index].dispose();
        _steps.removeAt(index);
      });
    }
  }

  void _reorderSteps(int oldIndex, int newIndex) {
    if (mounted) {
      setState(() {
        if (newIndex > oldIndex) newIndex--;
        final step = _steps.removeAt(oldIndex);
        _steps.insert(newIndex, step);
      });
    }
  }

  void _addCustomLabel() {
    final label = _customLabelController.text.trim();
    if (label.isEmpty) return;
    if (mounted) {
      setState(() {
        _selectedLabels.add(label);
        _customLabelController.clear();
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate at least one ingredient has a name.
    final validIngredients = _ingredients
        .where((i) => i.nameController.text.trim().isNotEmpty)
        .toList();
    if (validIngredients.isEmpty) {
      _showMessage('Please add at least one ingredient.');
      return;
    }

    // Validate at least one step has an instruction.
    final validSteps = _steps
        .where((s) => s.instructionController.text.trim().isNotEmpty)
        .toList();
    if (validSteps.isEmpty) {
      _showMessage('Please add at least one step.');
      return;
    }

    if (mounted) setState(() => _isSaving = true);

    final ingredients = validIngredients.map((i) {
      return {
        'name': i.nameController.text.trim(),
        'quantity':
            double.tryParse(i.quantityController.text.trim()) ?? 0,
        'unit': i.unitController.text.trim().isEmpty
            ? 'pieces'
            : i.unitController.text.trim(),
        if (i.groupController.text.trim().isNotEmpty)
          'group': i.groupController.text.trim(),
      };
    }).toList();

    final steps = <Map<String, dynamic>>[];
    for (var i = 0; i < validSteps.length; i++) {
      steps.add({
        'order': i + 1,
        'instruction': validSteps[i].instructionController.text.trim(),
        if (validSteps[i].photoUrl != null) 'photo': validSteps[i].photoUrl,
      });
    }

    final data = <String, dynamic>{
      'title': _titleController.text.trim(),
      if (_descriptionController.text.trim().isNotEmpty)
        'description': _descriptionController.text.trim(),
      if (_storyController.text.trim().isNotEmpty)
        'story': _storyController.text.trim(),
      'photos': _photoUrls,
      'showSignature': _showSignature,
      'labels': _selectedLabels.toList(),
      'dietaryTags': _selectedDietaryTags.toList(),
      'cuisineTags': _selectedCuisineTags.toList(),
      if (_selectedDifficulty != null) 'difficulty': _selectedDifficulty,
      'ingredients': ingredients,
      'steps': steps,
      if (_prepTimeController.text.trim().isNotEmpty)
        'prepTime': int.tryParse(_prepTimeController.text.trim()),
      if (_cookTimeController.text.trim().isNotEmpty)
        'cookTime': int.tryParse(_cookTimeController.text.trim()),
      if (_servingsController.text.trim().isNotEmpty)
        'servings': int.tryParse(_servingsController.text.trim()),
      if (_caloriesController.text.trim().isNotEmpty)
        'calories': int.tryParse(_caloriesController.text.trim()),
      if (_selectedCostEstimate != null)
        'costEstimate': _selectedCostEstimate,
      'baseServings': int.tryParse(_baseServingsController.text.trim()) ?? 1,
      'isPrivate': _isPrivate,
    };

    final recipe =
        await ref.read(createRecipeProvider.notifier).create(data);

    if (!mounted) return;

    if (recipe != null) {
      context.pop();
      _showMessage('Recipe created!');
    } else {
      setState(() => _isSaving = false);
      _showMessage('Failed to create recipe. Please try again.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final hasSignature =
        currentUser?.signature != null && currentUser!.signature!.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Recipe'),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingMd),
          children: [
            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Recipe Title',
                hintText: 'e.g. Mom\'s Biryani',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Title is required';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'A brief description of your recipe',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 3,
            ),
            const SizedBox(height: AppTheme.spacingMd),

            // Story
            TextFormField(
              controller: _storyController,
              decoration: const InputDecoration(
                labelText: 'Story (optional)',
                hintText:
                    'Share the story behind this recipe — its origin, memories, or what makes it special',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 6,
              minLines: 3,
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Photos
            const _SectionHeader(title: 'Photos (up to ${AppConstants.maxRecipePhotos})'),
            const SizedBox(height: AppTheme.spacingSm),
            _buildPhotoSection(),
            const SizedBox(height: AppTheme.spacingLg),

            // Ingredients
            const _SectionHeader(title: 'Ingredients'),
            const SizedBox(height: AppTheme.spacingSm),
            ..._buildIngredientFields(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addIngredient,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Ingredient'),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Steps
            const _SectionHeader(title: 'Steps'),
            const SizedBox(height: AppTheme.spacingSm),
            _buildStepsSection(),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addStep,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add Step'),
              ),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Labels
            const _SectionHeader(title: 'Labels'),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: _systemLabels.map((label) {
                final isSelected = _selectedLabels.contains(label);
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (mounted) {
                      setState(() {
                        if (selected) {
                          _selectedLabels.add(label);
                        } else {
                          _selectedLabels.remove(label);
                        }
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingSm),
            // Custom label input
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _customLabelController,
                    decoration: const InputDecoration(
                      hintText: 'Add custom label',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.words,
                    onFieldSubmitted: (_) => _addCustomLabel(),
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                IconButton(
                  onPressed: _addCustomLabel,
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add custom label',
                ),
              ],
            ),
            // Show custom labels that aren't system labels
            if (_selectedLabels
                .where((l) => !_systemLabels.contains(l))
                .isNotEmpty) ...[
              const SizedBox(height: AppTheme.spacingSm),
              Wrap(
                spacing: AppTheme.spacingSm,
                runSpacing: AppTheme.spacingSm,
                children: _selectedLabels
                    .where((l) => !_systemLabels.contains(l))
                    .map((label) => Chip(
                          label: Text(label),
                          onDeleted: () {
                            if (mounted) {
                              setState(() => _selectedLabels.remove(label));
                            }
                          },
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: AppTheme.spacingLg),

            // Dietary tags
            const _SectionHeader(title: 'Dietary Tags'),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: _dietaryOptions.map((tag) {
                final isSelected = _selectedDietaryTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (mounted) {
                      setState(() {
                        if (selected) {
                          _selectedDietaryTags.add(tag);
                        } else {
                          _selectedDietaryTags.remove(tag);
                        }
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Cuisine tags
            const _SectionHeader(title: 'Cuisine Tags'),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: AppTheme.spacingSm,
              runSpacing: AppTheme.spacingSm,
              children: _cuisineOptions.map((tag) {
                final isSelected = _selectedCuisineTags.contains(tag);
                return FilterChip(
                  label: Text(tag),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (mounted) {
                      setState(() {
                        if (selected) {
                          _selectedCuisineTags.add(tag);
                        } else {
                          _selectedCuisineTags.remove(tag);
                        }
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Difficulty
            const _SectionHeader(title: 'Difficulty'),
            const SizedBox(height: AppTheme.spacingSm),
            Wrap(
              spacing: AppTheme.spacingSm,
              children: _difficultyOptions.map((d) {
                final isSelected = _selectedDifficulty == d;
                return ChoiceChip(
                  label: Text(d[0].toUpperCase() + d.substring(1)),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (mounted) {
                      setState(() {
                        _selectedDifficulty = selected ? d : null;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Time & nutrition
            const _SectionHeader(title: 'Details'),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _prepTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Prep (min)',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: TextFormField(
                    controller: _cookTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Cook (min)',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _servingsController,
                    decoration: const InputDecoration(
                      labelText: 'Servings',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: TextFormField(
                    controller: _baseServingsController,
                    decoration: const InputDecoration(
                      labelText: 'Base Servings',
                      isDense: true,
                      hintText: 'For scaling',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingSm),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _caloriesController,
                    decoration: const InputDecoration(
                      labelText: 'Calories',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCostEstimate,
                    decoration: const InputDecoration(
                      labelText: 'Cost',
                      isDense: true,
                    ),
                    items: _costOptions
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(
                                  c[0].toUpperCase() + c.substring(1)),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (mounted) {
                        setState(() => _selectedCostEstimate = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingLg),

            // Privacy toggle
            SwitchListTile(
              title: const Text('Private Recipe'),
              subtitle: const Text('Only visible to you'),
              value: _isPrivate,
              onChanged: (value) {
                if (mounted) setState(() => _isPrivate = value);
              },
              contentPadding: EdgeInsets.zero,
            ),

            // Signature toggle
            if (hasSignature)
              SwitchListTile(
                title: const Text('Show Signature'),
                subtitle: const Text('Your signature on the recipe photo'),
                value: _showSignature,
                onChanged: (value) {
                  if (mounted) setState(() => _showSignature = value);
                },
                contentPadding: EdgeInsets.zero,
              ),

            const SizedBox(height: AppTheme.spacingXl),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return SizedBox(
      height: 100,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ..._photoUrls.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(right: AppTheme.spacingSm),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: AppTheme.borderRadiusMedium,
                    child: Image.network(
                      entry.value,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        width: 100,
                        height: 100,
                        color: context.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removePhoto(entry.key),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (_photoUrls.length < AppConstants.maxRecipePhotos)
            GestureDetector(
              onTap: _isUploadingPhoto ? null : _pickPhoto,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: context.colorScheme.outlineVariant,
                    width: 2,
                  ),
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
                child: Center(
                  child: _isUploadingPhoto
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 32,
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildIngredientFields() {
    return _ingredients.asMap().entries.map((entry) {
      final index = entry.key;
      final ingredient = entry.value;

      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: ingredient.nameController,
                decoration: InputDecoration(
                  hintText: 'Ingredient ${index + 1}',
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: AppTheme.spacingXs),
            Expanded(
              flex: 1,
              child: TextFormField(
                controller: ingredient.quantityController,
                decoration: const InputDecoration(
                  hintText: 'Qty',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
            ),
            const SizedBox(width: AppTheme.spacingXs),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: ingredient.unitController,
                decoration: const InputDecoration(
                  hintText: 'Unit',
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.none,
              ),
            ),
            const SizedBox(width: AppTheme.spacingXs),
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: ingredient.groupController,
                decoration: const InputDecoration(
                  hintText: 'Group',
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
            if (_ingredients.length > 1)
              IconButton(
                onPressed: () => _removeIngredient(index),
                icon: Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: context.colorScheme.error,
                ),
                tooltip: 'Remove ingredient',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildStepsSection() {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _steps.length,
      onReorder: _reorderSteps,
      itemBuilder: (context, index) {
        final step = _steps[index];
        return Padding(
          key: ValueKey(step),
          padding: const EdgeInsets.only(bottom: AppTheme.spacingSm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(
                    Icons.drag_handle,
                    size: 20,
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingXs),
              Container(
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: context.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: context.textTheme.labelSmall?.copyWith(
                    color: context.colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: TextFormField(
                  controller: step.instructionController,
                  decoration: InputDecoration(
                    hintText: 'Step ${index + 1} instructions',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              if (_steps.length > 1)
                IconButton(
                  onPressed: () => _removeStep(index),
                  icon: Icon(
                    Icons.remove_circle_outline,
                    size: 20,
                    color: context.colorScheme.error,
                  ),
                  tooltip: 'Remove step',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: context.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

/// Manages the text controllers for a single ingredient row.
class _IngredientEntry {
  final nameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final groupController = TextEditingController();

  void dispose() {
    nameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    groupController.dispose();
  }
}

/// Manages the text controller for a single step.
class _StepEntry {
  final instructionController = TextEditingController();
  String? photoUrl;

  void dispose() {
    instructionController.dispose();
  }
}
