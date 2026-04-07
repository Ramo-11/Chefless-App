import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../utils/extensions.dart';

/// Reason options available for reporting content.
enum ReportReason {
  spam('spam', 'Spam'),
  inappropriate('inappropriate', 'Inappropriate content'),
  copyright('copyright', 'Copyright violation'),
  harassment('harassment', 'Harassment'),
  other('other', 'Other');

  const ReportReason(this.value, this.label);
  final String value;
  final String label;
}

/// Modal bottom sheet for reporting a recipe or user.
///
/// Shows radio buttons for reason selection and an optional description field.
/// Submits via [ApiService.createReport] and shows a success snackbar.
class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({
    super.key,
    required this.targetType,
    required this.targetId,
  });

  final String targetType;
  final String targetId;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<ReportSheet> {
  ReportReason? _selectedReason;
  final _descriptionController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) return;

    setState(() => _isSubmitting = true);

    final apiService = await ref.read(apiServiceProvider.future);
    final result = await apiService.createReport(
      targetType: widget.targetType,
      targetId: widget.targetId,
      reason: _selectedReason!.value,
      description: _descriptionController.text.trim().isEmpty
          ? null
          : _descriptionController.text.trim(),
    );

    if (!context.mounted) return;

    if (result.isSuccess) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Report submitted. We will review it shortly.'),
        ),
      );
    } else {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.error ?? 'Failed to submit report.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final targetLabel =
        widget.targetType == 'user' ? 'user' : 'recipe';

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppTheme.spacing8),

              // Title
              Text(
                'Report $targetLabel',
                style: context.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.gray900,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: AppTheme.spacing16),

              // Subtitle
              Text(
                'Why are you reporting this $targetLabel?',
                style: context.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.gray500,
                ),
              ),

              const SizedBox(height: AppTheme.spacing12),

              // Reason radio buttons
              RadioGroup<ReportReason>(
                groupValue: _selectedReason,
                onChanged: _isSubmitting
                    ? (_) {}
                    : (value) {
                        setState(() => _selectedReason = value);
                      },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ReportReason.values.map((reason) {
                    return RadioListTile<ReportReason>(
                      value: reason,
                      title: Text(
                        reason.label,
                        style: context.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.gray700,
                        ),
                      ),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: AppTheme.spacing16),

              // Description field
              TextField(
                controller: _descriptionController,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  hintText: 'Additional details (optional)',
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 3,
                minLines: 2,
                maxLength: 500,
              ),

              const SizedBox(height: AppTheme.spacing16),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed:
                      _selectedReason != null && !_isSubmitting
                          ? _submit
                          : null,
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Report'),
                ),
              ),

              const SizedBox(height: AppTheme.spacing20),
            ],
          ),
        ),
      ),
    );
  }
}
