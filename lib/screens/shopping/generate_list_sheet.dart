import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/shopping_list_provider.dart';
import '../../utils/extensions.dart';

/// Bottom sheet that lets the user pick a date range and generate a shopping
/// list from their kitchen's schedule.
class GenerateListSheet extends ConsumerStatefulWidget {
  const GenerateListSheet({super.key});

  @override
  ConsumerState<GenerateListSheet> createState() => _GenerateListSheetState();
}

class _GenerateListSheetState extends ConsumerState<GenerateListSheet> {
  late DateTime _startDate;
  late DateTime _endDate;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    // Default to the current week (Monday to Sunday).
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 6));
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null && mounted) {
      setState(() {
        _startDate = picked;
        // If end date is before start date, move it.
        if (_endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 6));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate,
      firstDate: _startDate,
      lastDate: _startDate.add(const Duration(days: 30)),
    );
    if (picked != null && mounted) {
      setState(() {
        _endDate = picked;
      });
    }
  }

  Future<void> _generate() async {
    setState(() {
      _isGenerating = true;
    });

    final listId = await ref
        .read(shoppingListActionProvider.notifier)
        .generateFromSchedule(
          startDate: _startDate,
          endDate: _endDate,
        );

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
    });

    if (listId != null) {
      Navigator.of(context).pop();
      context.push('/shopping/$listId');
    } else {
      final actionState = ref.read(shoppingListActionProvider);
      final errorMsg = actionState.whenOrNull(
        error: (e, _) => e.toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg ?? 'Failed to generate shopping list.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('EEE, MMM d, yyyy');
    final dayCount = _endDate.difference(_startDate).inDays + 1;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppTheme.spacing20,
          right: AppTheme.spacing20,
          top: AppTheme.spacing4,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppTheme.spacing16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title
            Text(
              'Generate from Schedule',
              style: context.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
                color: AppTheme.gray900,
              ),
            ),

            const SizedBox(height: AppTheme.spacing8),

            Text(
              'Create a shopping list from all scheduled recipes in the selected date range.',
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
                height: 1.5,
              ),
            ),

            const SizedBox(height: AppTheme.spacing24),

            // Start date
            _DatePickerRow(
              label: 'Start date',
              value: dateFormatter.format(_startDate),
              onTap: _isGenerating ? null : _pickStartDate,
            ),

            const SizedBox(height: AppTheme.spacing8),

            // End date
            _DatePickerRow(
              label: 'End date',
              value: dateFormatter.format(_endDate),
              onTap: _isGenerating ? null : _pickEndDate,
            ),

            const SizedBox(height: AppTheme.spacing12),

            // Range preview
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing12,
                vertical: AppTheme.spacing8,
              ),
              decoration: BoxDecoration(
                color: AppTheme.primaryLight,
                borderRadius: AppTheme.borderRadiusSmall,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.date_range_rounded,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: AppTheme.spacing8),
                  Text(
                    '$dayCount day${dayCount == 1 ? '' : 's'} selected',
                    style: context.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing24),

            // Generate button
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _isGenerating ? null : _generate,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.borderRadiusMedium,
                  ),
                ),
                child: _isGenerating
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Generate Shopping List'),
              ),
            ),

            const SizedBox(height: AppTheme.spacing8),
          ],
        ),
      ),
    );
  }
}

// ── Date Picker Row ──────────────────────────────────────────────────────────

class _DatePickerRow extends StatelessWidget {
  const _DatePickerRow({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppTheme.borderRadiusMedium,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing12,
        ),
        decoration: BoxDecoration(
          color: AppTheme.gray50,
          borderRadius: AppTheme.borderRadiusMedium,
          border: Border.all(color: AppTheme.gray200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray500,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: context.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.gray900,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing8),
                const Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: AppTheme.gray400,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
