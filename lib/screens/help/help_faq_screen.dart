import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../utils/app_help_content.dart';
import '../../utils/extensions.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final topics = AppHelpTopic.values.map(appHelpForTopic).toList();

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        title: Text(
          'Help & FAQs',
          style: AppTheme.displayTitleMedium(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          AppTheme.spacing12,
          AppTheme.spacing16,
          AppTheme.spacing32,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppTheme.spacing20),
            decoration: BoxDecoration(
              color: AppTheme.surfaceElevated,
              borderRadius: AppTheme.borderRadiusXL,
              boxShadow: AppTheme.shadowSm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need a refresher?',
                  style: AppTheme.displayTitleSmall(),
                ),
                const SizedBox(height: AppTheme.spacing6),
                Text(
                  'Quick answers for the most common questions, plus a simple guide to what each main area of the app does.',
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.gray500,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTheme.spacing20),
          Text(
            'Quick Answers',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryDeep,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          ...generalHelpFaqs.map(
            (faq) => _FaqTile(faq: faq),
          ),
          const SizedBox(height: AppTheme.spacing24),
          Text(
            'Main App Areas',
            style: context.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimaryDeep,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          ...topics.map(
            (topic) => _TopicSection(topic: topic),
          ),
        ],
      ),
    );
  }
}

class _TopicSection extends StatelessWidget {
  const _TopicSection({required this.topic});

  final AppHelpContent topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusXL,
        boxShadow: AppTheme.shadowSm,
      ),
      child: ExpansionTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppTheme.accentPlayfulLight,
            borderRadius: AppTheme.borderRadiusMedium,
          ),
          child: Icon(
            topic.icon,
            color: AppTheme.accentPlayful,
            size: 20,
          ),
        ),
        title: Text(
          topic.title,
          style: context.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimaryDeep,
          ),
        ),
        subtitle: Text(
          topic.subtitle,
          style: context.textTheme.bodySmall?.copyWith(
            color: AppTheme.gray500,
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          0,
          AppTheme.spacing16,
          AppTheme.spacing16,
        ),
        children: [
          const SizedBox(height: AppTheme.spacing4),
          ...topic.bullets.map(
            (bullet) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(
                      Icons.circle,
                      size: 6,
                      color: AppTheme.accentPlayful,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Text(
                      bullet,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.gray700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          ...topic.faqs.map((faq) => _FaqTile(faq: faq, dense: true)),
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile({
    required this.faq,
    this.dense = false,
  });

  final HelpFaqItem faq;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(
        bottom: dense ? AppTheme.spacing8 : AppTheme.spacing12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(color: AppTheme.gray100),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spacing16,
          vertical: AppTheme.spacing4,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppTheme.spacing16,
          0,
          AppTheme.spacing16,
          AppTheme.spacing16,
        ),
        title: Text(
          faq.question,
          style: context.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimaryDeep,
          ),
        ),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              faq.answer,
              style: context.textTheme.bodyMedium?.copyWith(
                color: AppTheme.gray600,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
