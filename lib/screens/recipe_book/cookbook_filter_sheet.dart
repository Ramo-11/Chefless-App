import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/extensions.dart';

class CookbookFilterResult {
  const CookbookFilterResult({
    required this.label,
    required this.dietary,
    required this.cuisine,
    required this.maxCookTimeMinutes,
  });

  final String? label;
  final String? dietary;
  final String? cuisine;
  final int? maxCookTimeMinutes;
}

class _CookTimeOption {
  const _CookTimeOption({required this.label, required this.value});
  final String label;
  final int value;
}

const List<_CookTimeOption> _cookTimeOptions = <_CookTimeOption>[
  _CookTimeOption(label: '≤15 min', value: 15),
  _CookTimeOption(label: '≤30 min', value: 30),
  _CookTimeOption(label: '≤60 min', value: 60),
  _CookTimeOption(label: '≤2 hrs', value: 120),
];

Future<CookbookFilterResult?> showCookbookFilterSheet({
  required BuildContext context,
  required Iterable<String> labels,
  required Iterable<String> dietaryTags,
  required Iterable<String> cuisineTags,
  String? initialLabel,
  String? initialDietary,
  String? initialCuisine,
  int? initialMaxCookTimeMinutes,
}) {
  return showModalBottomSheet<CookbookFilterResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppTheme.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return _CookbookFilterSheet(
        labels: labels.toList()..sort(),
        dietaryTags: dietaryTags.toList()..sort(),
        cuisineTags: cuisineTags.toList()..sort(),
        initialLabel: initialLabel,
        initialDietary: initialDietary,
        initialCuisine: initialCuisine,
        initialMaxCookTimeMinutes: initialMaxCookTimeMinutes,
      );
    },
  );
}

class _CookbookFilterSheet extends StatefulWidget {
  const _CookbookFilterSheet({
    required this.labels,
    required this.dietaryTags,
    required this.cuisineTags,
    this.initialLabel,
    this.initialDietary,
    this.initialCuisine,
    this.initialMaxCookTimeMinutes,
  });

  final List<String> labels;
  final List<String> dietaryTags;
  final List<String> cuisineTags;
  final String? initialLabel;
  final String? initialDietary;
  final String? initialCuisine;
  final int? initialMaxCookTimeMinutes;

  @override
  State<_CookbookFilterSheet> createState() => _CookbookFilterSheetState();
}

class _CookbookFilterSheetState extends State<_CookbookFilterSheet> {
  late String? _label = widget.initialLabel;
  late String? _dietary = widget.initialDietary;
  late String? _cuisine = widget.initialCuisine;
  late int? _maxCookTime = widget.initialMaxCookTimeMinutes;

  bool get _hasAnySelected =>
      _label != null ||
      _dietary != null ||
      _cuisine != null ||
      _maxCookTime != null;

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    final sections = <Widget>[
      _ChipGroup(
        title: 'Cook time',
        options: _cookTimeOptions.map((o) => o.label).toList(),
        selected: _cookTimeLabel(_maxCookTime),
        onSelected: (label) {
          setState(() {
            _maxCookTime = _cookTimeValue(label);
          });
        },
      ),
      if (widget.labels.isNotEmpty)
        _ChipGroup(
          title: 'Labels',
          options: widget.labels,
          selected: _label,
          onSelected: (value) => setState(() => _label = value),
        ),
      if (widget.dietaryTags.isNotEmpty)
        _ChipGroup(
          title: 'Dietary',
          options: widget.dietaryTags,
          selected: _dietary,
          onSelected: (value) => setState(() => _dietary = value),
        ),
      if (widget.cuisineTags.isNotEmpty)
        _ChipGroup(
          title: 'Cuisine',
          options: widget.cuisineTags,
          selected: _cuisine,
          onSelected: (value) => setState(() => _cuisine = value),
        ),
    ];

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing20,
                AppTheme.spacing4,
                AppTheme.spacing12,
                AppTheme.spacing8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Filter recipes',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryDeep,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppTheme.spacing20,
                  AppTheme.spacing4,
                  AppTheme.spacing20,
                  AppTheme.spacing20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < sections.length; i++) ...[
                      sections[i],
                      if (i < sections.length - 1)
                        const Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacing20),
                          child: Divider(height: 1),
                        ),
                    ],
                  ],
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppTheme.gray100)),
              ),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing12,
                AppTheme.spacing16,
                AppTheme.spacing16,
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _hasAnySelected
                            ? () {
                                setState(() {
                                  _label = null;
                                  _dietary = null;
                                  _cuisine = null;
                                  _maxCookTime = null;
                                });
                              }
                            : null,
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 18,
                        ),
                        label: const Text('Clear all'),
                      ),
                    ),
                    const SizedBox(width: AppTheme.spacing12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.accentPlayful,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(
                            CookbookFilterResult(
                              label: _label,
                              dietary: _dietary,
                              cuisine: _cuisine,
                              maxCookTimeMinutes: _maxCookTime,
                            ),
                          );
                        },
                        child: Text(_hasAnySelected ? 'Apply' : 'Done'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _cookTimeLabel(int? value) {
    if (value == null) return null;
    for (final opt in _cookTimeOptions) {
      if (opt.value == value) return opt.label;
    }
    return null;
  }

  int? _cookTimeValue(String? label) {
    if (label == null) return null;
    for (final opt in _cookTimeOptions) {
      if (opt.label == label) return opt.value;
    }
    return null;
  }
}

class _ChipGroup extends StatelessWidget {
  const _ChipGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> options;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryDeep,
          ),
        ),
        const SizedBox(height: AppTheme.spacing12),
        Wrap(
          spacing: AppTheme.spacing8,
          runSpacing: AppTheme.spacing8,
          children: options.map((option) {
            final isSelected = selected == option;
            return InkWell(
              borderRadius: AppTheme.borderRadiusFull,
              onTap: () => onSelected(isSelected ? null : option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.accentPlayful
                      : AppTheme.surfaceElevated,
                  borderRadius: AppTheme.borderRadiusFull,
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.accentPlayful
                        : AppTheme.gray200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                    ],
                    Text(
                      _titleCase(option),
                      style: context.textTheme.labelMedium?.copyWith(
                        color:
                            isSelected ? Colors.white : AppTheme.gray800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  String _titleCase(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return trimmed;
    if (trimmed.startsWith(RegExp(r'[^a-zA-Z]'))) return trimmed;
    return trimmed
        .split(RegExp(r'\s+'))
        .map((word) {
          if (word.isEmpty) return word;
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}
