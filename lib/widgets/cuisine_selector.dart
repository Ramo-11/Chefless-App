import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme.dart';
import '../utils/cuisine_data.dart';
import '../utils/extensions.dart';
import 'animated_selectable_chip.dart';

/// A searchable dropdown for selecting cuisine tags.
///
/// Shows quick picks at the top, then all cuisines grouped by region.
/// Selected cuisines appear as chips below the trigger button.
class CuisineSelector extends StatelessWidget {
  const CuisineSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  void _openSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CuisinePickerSheet(
        selected: Set<String>.from(selected),
        onDone: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => _openSheet(context),
          borderRadius: AppTheme.borderRadiusMedium,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
              vertical: AppTheme.spacing12,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.gray200),
              borderRadius: AppTheme.borderRadiusMedium,
              color: AppTheme.surfaceElevated,
            ),
            child: Row(
              children: [
                const Icon(Icons.public_rounded, size: 20, color: AppTheme.gray500),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Text(
                    selected.isEmpty
                        ? 'Select cuisines...'
                        : '${selected.length} selected',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: selected.isEmpty
                          ? AppTheme.gray400
                          : AppTheme.textPrimaryDeep,
                    ),
                  ),
                ),
                const Icon(
                  Icons.expand_more_rounded,
                  size: 20,
                  color: AppTheme.gray400,
                ),
              ],
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: AppTheme.spacing8),
          Wrap(
            spacing: AppTheme.spacing6,
            runSpacing: AppTheme.spacing6,
            children: selected.map((name) {
              final flag = flagForCuisine(name);
              return Chip(
                label: Text(
                  flag != null ? '$flag $name' : name,
                  style: const TextStyle(fontSize: 13),
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: () {
                  final updated = Set<String>.from(selected)..remove(name);
                  onChanged(updated);
                },
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: AppTheme.accentPlayfulLight,
                side: BorderSide(
                  color: AppTheme.accentPlayful.withValues(alpha: 0.2),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _CuisinePickerSheet extends StatefulWidget {
  const _CuisinePickerSheet({
    required this.selected,
    required this.onDone,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onDone;

  @override
  State<_CuisinePickerSheet> createState() => _CuisinePickerSheetState();
}

class _CuisinePickerSheetState extends State<_CuisinePickerSheet> {
  late final Set<String> _selected;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _selected = widget.selected;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggle(String name) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_selected.contains(name)) {
        _selected.remove(name);
      } else {
        _selected.add(name);
      }
    });
  }

  bool _matchesQuery(CuisineItem item) {
    if (_query.isEmpty) return true;
    return item.name.toLowerCase().contains(_query);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.gray300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Select Cuisines',
                      style: context.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: () {
                      widget.onDone(_selected);
                      Navigator.of(context).pop();
                    },
                    child: Text('Done (${_selected.length})'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search cuisines...',
                  prefixIcon:
                      const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => setState(() => _query = v.toLowerCase()),
              ),
            ),
            const SizedBox(height: 12),

            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.only(bottom: 32),
                children: [
                  // Quick picks
                  if (_query.isEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                      child: Text(
                        'POPULAR',
                        style: context.textTheme.labelSmall?.copyWith(
                          color: AppTheme.gray500,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: AppTheme.spacing8,
                        runSpacing: AppTheme.spacing8,
                        children: quickPickCuisines.map((c) {
                          return AnimatedSelectableChip(
                            leading: Text(
                              c.flag,
                              style: const TextStyle(fontSize: 16),
                            ),
                            label: c.name,
                            selected: _selected.contains(c.name),
                            showCheckWhenSelected: false,
                            selectedFill: AppTheme.accentPlayfulLight,
                            selectedBorder: AppTheme.accentPlayful,
                            selectedLabelColor: AppTheme.accentPlayful,
                            onTap: () => _toggle(c.name),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                  ],

                  // Regions
                  ...cuisineRegions.map((region) {
                    final filtered = region.cuisines
                        .where(_matchesQuery)
                        .toList();
                    if (filtered.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                          child: Text(
                            region.name.toUpperCase(),
                            style:
                                context.textTheme.labelSmall?.copyWith(
                              color: AppTheme.gray500,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ),
                        ...filtered.map((c) {
                          final isSelected = _selected.contains(c.name);
                          return ListTile(
                            dense: true,
                            leading: Text(
                              c.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            title: Text(
                              c.name,
                              style: context.textTheme.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isSelected
                                    ? AppTheme.accentPlayful
                                    : AppTheme.gray900,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: AppTheme.accentPlayful,
                                    size: 22,
                                  )
                                : const Icon(
                                    Icons.circle_outlined,
                                    color: AppTheme.gray300,
                                    size: 22,
                                  ),
                            onTap: () => _toggle(c.name),
                          );
                        }),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
