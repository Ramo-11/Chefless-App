import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_theme.dart';
import '../../models/recipe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../utils/constants.dart';
import '../../utils/extensions.dart';

const _systemLabels = [
  'Breakfast',
  'Lunch',
  'Dinner',
  'Snack',
  'Dessert',
  'Drink',
];

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

const _difficultyOptions = ['easy', 'medium', 'hard'];
const _costOptions = ['budget', 'moderate', 'expensive'];

/// Edit recipe form, pre-populated with existing recipe data.
class EditRecipeScreen extends ConsumerStatefulWidget {
  const EditRecipeScreen({
    super.key,
    required this.recipeId,
  });

  final String recipeId;

  @override
  ConsumerState<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends ConsumerState<EditRecipeScreen> {
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

  final List<_IngredientEntry> _ingredients = [];
  final List<_StepEntry> _steps = [];
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
  bool _isInitialized = false;

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

  void _populateFields(Recipe recipe) {
    if (_isInitialized) return;
    _isInitialized = true;

    _titleController.text = recipe.title;
    _descriptionController.text = recipe.description ?? '';
    _storyController.text = recipe.story ?? '';
    _photoUrls.addAll(recipe.photos);
    _selectedLabels.addAll(recipe.labels);
    _selectedDietaryTags.addAll(recipe.dietaryTags);
    _selectedCuisineTags.addAll(recipe.cuisineTags);
    _selectedDifficulty = recipe.difficulty;
    _selectedCostEstimate = recipe.costEstimate;
    _isPrivate = recipe.isPrivate;
    _showSignature = recipe.showSignature;

    if (recipe.prepTime != null) {
      _prepTimeController.text = recipe.prepTime.toString();
    }
    if (recipe.cookTime != null) {
      _cookTimeController.text = recipe.cookTime.toString();
    }
    if (recipe.servings != null) {
      _servingsController.text = recipe.servings.toString();
    }
    _baseServingsController.text = recipe.baseServings.toString();
    if (recipe.calories != null) {
      _caloriesController.text = recipe.calories.toString();
    }

    if (recipe.ingredients.isNotEmpty) {
      for (final ingredient in recipe.ingredients) {
        final entry = _IngredientEntry();
        entry.nameController.text = ingredient.name;
        entry.quantityController.text = ingredient.quantity.toString();
        entry.unitController.text = ingredient.unit;
        entry.groupController.text = ingredient.group ?? '';
        _ingredients.add(entry);
      }
    } else {
      _ingredients.add(_IngredientEntry());
    }

    if (recipe.steps.isNotEmpty) {
      final sorted = List<RecipeStep>.from(recipe.steps)
        ..sort((a, b) => a.order.compareTo(b.order));
      for (final step in sorted) {
        final entry = _StepEntry();
        entry.instructionController.text = step.instruction;
        entry.photoUrl = step.photo;
        _steps.add(entry);
      }
    } else {
      _steps.add(_StepEntry());
    }
  }

  Future<void> _pickPhoto() async {
    final remaining = AppConstants.maxRecipePhotos - _photoUrls.length;
    if (remaining <= 0) {
      _showMessage('Maximum ${AppConstants.maxRecipePhotos} photos allowed.');
      return;
    }

    final picker = ImagePicker();
    final images = await picker.pickMultiImage(
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
      limit: remaining,
    );

    if (images.isEmpty || !mounted) return;

    setState(() => _isUploadingPhoto = true);

    final apiService = await ref.read(apiServiceProvider.future);

    for (final image in images) {
      if (!mounted) return;

      try {
        final bytes = await File(image.path).readAsBytes();
        final ext = image.path.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        final dataUri = 'data:$mime;base64,${base64Encode(bytes)}';

        final result = await apiService.post(
          '/recipes/upload-photo',
          data: {'image': dataUri},
        );

        if (!mounted) return;

        if (result.isSuccess && result.data != null) {
          final url = result.data!['secureUrl'] as String;
          setState(() => _photoUrls.add(url));
        } else {
          _showMessage(result.error ?? 'Failed to upload photo.');
        }
      } catch (e) {
        if (mounted) _showMessage('Failed to upload photo.');
      }
    }

    if (mounted) setState(() => _isUploadingPhoto = false);
  }

  void _removePhoto(int index) {
    if (mounted) setState(() => _photoUrls.removeAt(index));
  }

  void _addIngredient() {
    if (mounted) setState(() => _ingredients.add(_IngredientEntry()));
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
    if (mounted) setState(() => _steps.add(_StepEntry()));
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

    final validIngredients = _ingredients
        .where((i) => i.nameController.text.trim().isNotEmpty)
        .toList();
    if (validIngredients.isEmpty) {
      _showMessage('Please add at least one ingredient.');
      return;
    }

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
      'baseServings':
          int.tryParse(_baseServingsController.text.trim()) ?? 1,
      'isPrivate': _isPrivate,
    };

    final recipe = await ref
        .read(recipeActionProvider.notifier)
        .update(widget.recipeId, data);

    if (!mounted) return;

    if (recipe != null) {
      context.pop();
      _showMessage('Recipe updated!');
    } else {
      final error = ref.read(recipeActionProvider);
      debugPrint('[EditRecipe] Update failed: ${error.error}');
      setState(() => _isSaving = false);
      _showMessage(
        error.error?.toString().replaceFirst('Exception: ', '') ??
            'Failed to update recipe. Please try again.',
      );
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
    final recipeAsync = ref.watch(recipeDetailProvider(widget.recipeId));
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final hasSignature =
        currentUser?.signature != null && currentUser!.signature!.isNotEmpty;

    return recipeAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Edit Recipe')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacingLg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48, color: context.colorScheme.error),
                const SizedBox(height: AppTheme.spacingMd),
                Text('Failed to load recipe',
                    style: context.textTheme.titleMedium),
                const SizedBox(height: AppTheme.spacingMd),
                ElevatedButton(
                  onPressed: () =>
                      ref.invalidate(recipeDetailProvider(widget.recipeId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (recipe) {
        _populateFields(recipe);

        return GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Scaffold(
          appBar: AppBar(
            title: const Text('Edit Recipe'),
            actions: [
              TextButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
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
                const _SectionHeader(
                    title:
                        'Photos (up to ${AppConstants.maxRecipePhotos})'),
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
                                  setState(
                                      () => _selectedLabels.remove(label));
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
                      label:
                          Text(d[0].toUpperCase() + d.substring(1)),
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

                // Details
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacingSm),
                    Expanded(
                      child: TextFormField(
                        controller: _baseServingsController,
                        decoration: const InputDecoration(
                          labelText: 'Base Servings',
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
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
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
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
                                  child: Text(c[0].toUpperCase() +
                                      c.substring(1)),
                                ))
                            .toList(),
                        onChanged: (value) {
                          if (mounted) {
                            setState(
                                () => _selectedCostEstimate = value);
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
                    subtitle:
                        const Text('Your signature on the recipe photo'),
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
        ),
        );
      },
    );
  }

  Widget _buildPhotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 130,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._photoUrls.asMap().entries.map((entry) {
                final index = entry.key;
                final isMain = index == 0;
                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spacingSm),
                  child: GestureDetector(
                    onLongPress: _photoUrls.length > 1
                        ? () => _showReorderSheet()
                        : null,
                    child: SizedBox(
                      width: 110,
                      height: 130,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: AppTheme.borderRadiusMedium,
                            child: Image.network(
                              entry.value,
                              width: 110,
                              height: 130,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                width: 110,
                                height: 130,
                                color: context
                                    .colorScheme.surfaceContainerHighest,
                                child:
                                    const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                          ),
                          if (isMain)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Main',
                                  style: TextStyle(
                                    color: context.colorScheme.onPrimary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removePhoto(index),
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
                    ),
                  ),
                );
              }),
              if (_photoUrls.length < AppConstants.maxRecipePhotos)
                GestureDetector(
                  onTap: _isUploadingPhoto ? null : _pickPhoto,
                  child: Container(
                    width: 110,
                    height: 130,
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
        ),
        if (_photoUrls.length > 1) ...[
          const SizedBox(height: AppTheme.spacingXs),
          Text(
            'Long-press a photo to reorder',
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  void _showReorderSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacingMd,
                      AppTheme.spacingSm,
                      AppTheme.spacingMd,
                      AppTheme.spacingSm,
                    ),
                    child: Text(
                      'Reorder Photos',
                      style: context.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                    ),
                    child: Text(
                      'The first photo is the main photo.',
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingSm),
                  SizedBox(
                    height: 200,
                    child: ReorderableListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMd,
                      ),
                      itemCount: _photoUrls.length,
                      onReorder: (oldIndex, newIndex) {
                        if (newIndex > oldIndex) newIndex--;
                        setState(() {
                          final url = _photoUrls.removeAt(oldIndex);
                          _photoUrls.insert(newIndex, url);
                        });
                        setSheetState(() {});
                      },
                      proxyDecorator: (child, index, animation) {
                        return Material(
                          elevation: 8,
                          borderRadius: AppTheme.borderRadiusMedium,
                          clipBehavior: Clip.antiAlias,
                          child: child,
                        );
                      },
                      itemBuilder: (ctx, index) {
                        final isMain = index == 0;
                        return Padding(
                          key: ValueKey(_photoUrls[index]),
                          padding: const EdgeInsets.only(
                            right: AppTheme.spacingSm,
                          ),
                          child: SizedBox(
                            width: 140,
                            height: 200,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: AppTheme.borderRadiusMedium,
                                  child: Image.network(
                                    _photoUrls[index],
                                    width: 140,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                if (isMain)
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: context.colorScheme.primary,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Main',
                                        style: TextStyle(
                                          color:
                                              context.colorScheme.onPrimary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingMd,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacingMd),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildIngredientFields() {
    return _ingredients.asMap().entries.map((entry) {
      final index = entry.key;
      final ingredient = entry.value;

      return Padding(
        padding: const EdgeInsets.only(bottom: AppTheme.spacingMd),
        child: Column(
          children: [
            // Row 1: Name + Quantity + Remove button
            Row(
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
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: ingredient.quantityController,
                    decoration: const InputDecoration(
                      hintText: 'Quantity',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
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
            const SizedBox(height: AppTheme.spacingXs),
            // Row 2: Unit + Group
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: ingredient.unitController,
                    decoration: const InputDecoration(
                      hintText: 'Unit (e.g. cups, g)',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.none,
                  ),
                ),
                const SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: TextFormField(
                    controller: ingredient.groupController,
                    decoration: const InputDecoration(
                      hintText: 'Group (optional)',
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                ),
              ],
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

class _StepEntry {
  final instructionController = TextEditingController();
  String? photoUrl;

  void dispose() {
    instructionController.dispose();
  }
}
