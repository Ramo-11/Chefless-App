import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_theme.dart';
import '../../models/kitchen.dart';
import '../../models/user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/kitchen_provider.dart';
import '../../utils/app_help_content.dart';
import '../../widgets/app_top_bar.dart';
import '../../widgets/shimmer_loading.dart';
import '../../widgets/user_avatar.dart';
import '../paywall/paywall_bottom_sheet.dart';

/// Editorial kitchen home: hero with identity + invite + recipes link,
/// followed by Members and Settings tabs.
class KitchenDetailScreen extends ConsumerStatefulWidget {
  const KitchenDetailScreen({super.key});

  @override
  ConsumerState<KitchenDetailScreen> createState() =>
      _KitchenDetailScreenState();
}

class _KitchenDetailScreenState extends ConsumerState<KitchenDetailScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) ref.invalidate(myKitchenProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kitchenAsync = ref.watch(myKitchenProvider);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppTheme.surfaceWarm,
      appBar: AppBar(
        backgroundColor: AppTheme.surfaceWarm,
        automaticallyImplyLeading: context.canPop(),
        title: Text(
          'My Kitchen',
          style: AppTheme.displayTitleMedium(),
        ),
        actions: const [
          NotificationBellIcon(),
          ProfileShortcutIcon(),
          MainTabMoreButton(topic: AppHelpTopic.kitchen),
        ],
      ),
      body: kitchenAsync.when(
        data: (detail) {
          if (detail == null) {
            return _NoKitchenView(
              onRefresh: () => ref.invalidate(myKitchenProvider),
            );
          }
          final userId = currentUser.valueOrNull?.id;
          final isLead = userId == detail.kitchen.leadId;
          return _KitchenContent(
            detail: detail,
            isLead: isLead,
            currentUserId: userId ?? '',
            tabController: _tabController,
            onRefresh: () async => ref.invalidate(myKitchenProvider),
          );
        },
        loading: () => const _LoadingView(),
        error: (error, _) => _KitchenErrorView(
          message: error.toString().replaceFirst('Exception: ', ''),
          onRetry: () => ref.invalidate(myKitchenProvider),
        ),
      ),
    );
  }
}

// ── Kitchen content (hero + tabs) ────────────────────────────────────────────

class _KitchenContent extends ConsumerWidget {
  const _KitchenContent({
    required this.detail,
    required this.isLead,
    required this.currentUserId,
    required this.tabController,
    required this.onRefresh,
  });

  final KitchenDetail detail;
  final bool isLead;
  final String currentUserId;
  final TabController tabController;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NestedScrollView(
      headerSliverBuilder: (context, _) => [
        SliverToBoxAdapter(
          child: _KitchenHeroCard(detail: detail),
        ),
        SliverPersistentHeader(
          pinned: true,
          delegate: _KitchenTabBarDelegate(
            tabBar: TabBar(
              controller: tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing8,
                vertical: 6,
              ),
              indicator: BoxDecoration(
                color: AppTheme.accentPlayful,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentPlayful.withValues(alpha: 0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.gray600,
              labelStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
              unselectedLabelStyle:
                  Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.gray600,
                        letterSpacing: -0.1,
                      ),
              tabs: const [
                Tab(text: 'Members'),
                Tab(text: 'Settings'),
              ],
            ),
          ),
        ),
      ],
      body: TabBarView(
        controller: tabController,
        children: [
          _MembersTabView(
            detail: detail,
            isLead: isLead,
            currentUserId: currentUserId,
            onRefresh: onRefresh,
          ),
          _SettingsTabView(
            detail: detail,
            isLead: isLead,
            onRefresh: onRefresh,
          ),
        ],
      ),
    );
  }
}

// ── Hero card ────────────────────────────────────────────────────────────────

class _KitchenHeroCard extends StatelessWidget {
  const _KitchenHeroCard({required this.detail});

  final KitchenDetail detail;

  @override
  Widget build(BuildContext context) {
    final kitchen = detail.kitchen;
    final memberCount = kitchen.memberCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing12,
        AppTheme.spacing16,
        AppTheme.spacing16,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: AppTheme.borderRadiusXL,
          boxShadow: AppTheme.shadowCard,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              AppTheme.accentPlayfulLight.withValues(alpha: 0.55),
            ],
          ),
        ),
        child: Column(
          children: [
            // Identity block
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing20,
                AppTheme.spacing24,
                AppTheme.spacing20,
                AppTheme.spacing20,
              ),
              child: Column(
                children: [
                  _KitchenAvatar(
                    photo: kitchen.photo,
                    name: kitchen.name,
                  ),
                  const SizedBox(height: AppTheme.spacing16),
                  Text(
                    kitchen.name,
                    style: AppTheme.displayTitleMedium().copyWith(
                      fontSize: 24,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: AppTheme.spacing8,
                    runSpacing: AppTheme.spacing6,
                    children: [
                      _HeroChip(
                        icon: Icons.people_alt_rounded,
                        label:
                            '$memberCount member${memberCount == 1 ? '' : 's'}',
                      ),
                      _HeroChip(
                        icon: kitchen.isPublic
                            ? Icons.public_rounded
                            : Icons.lock_rounded,
                        label: kitchen.isPublic ? 'Public' : 'Private',
                        accent: kitchen.isPublic,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Hairline
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
              ),
              color: AppTheme.gray200.withValues(alpha: 0.6),
            ),
            // Invite code block
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing20,
                AppTheme.spacing16,
                AppTheme.spacing20,
                AppTheme.spacing16,
              ),
              child: _InviteCodeBlock(
                inviteCode: kitchen.inviteCode,
                kitchenName: kitchen.name,
              ),
            ),
            // Hairline
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing20,
              ),
              color: AppTheme.gray200.withValues(alpha: 0.6),
            ),
            // Recipes feature row
            _RecipesFeatureRow(),
          ],
        ),
      ),
    );
  }
}

class _KitchenAvatar extends StatelessWidget {
  const _KitchenAvatar({required this.photo, required this.name});

  final String? photo;
  final String name;

  @override
  Widget build(BuildContext context) {
    const size = 88.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentPlayful.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xFF1F1A12).withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color: AppTheme.accentPlayfulLight,
          image: photo != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(photo!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: photo == null
            ? const Center(
                child: Icon(
                  Icons.kitchen_rounded,
                  size: 38,
                  color: AppTheme.accentPlayful,
                ),
              )
            : null,
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({
    required this.icon,
    required this.label,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: AppTheme.spacing6,
      ),
      decoration: BoxDecoration(
        color: accent
            ? AppTheme.accentPlayfulLight
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: AppTheme.borderRadiusFull,
        border: Border.all(
          color: accent
              ? AppTheme.accentPlayful.withValues(alpha: 0.25)
              : AppTheme.gray200.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: accent ? AppTheme.accentPlayful : AppTheme.gray600,
          ),
          const SizedBox(width: AppTheme.spacing6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.1,
              color: accent ? AppTheme.accentPlayful : AppTheme.gray700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteCodeBlock extends StatefulWidget {
  const _InviteCodeBlock({
    required this.inviteCode,
    required this.kitchenName,
  });

  final String inviteCode;
  final String kitchenName;

  @override
  State<_InviteCodeBlock> createState() => _InviteCodeBlockState();
}

class _InviteCodeBlockState extends State<_InviteCodeBlock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _copyAnim;
  bool _justCopied = false;

  @override
  void initState() {
    super.initState();
    _copyAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      lowerBound: 0,
      upperBound: 1,
    );
  }

  @override
  void dispose() {
    _copyAnim.dispose();
    super.dispose();
  }

  Future<void> _onCopy() async {
    HapticFeedback.heavyImpact();
    await Clipboard.setData(ClipboardData(text: widget.inviteCode));
    _copyAnim
      ..reset()
      ..forward();
    if (!mounted) return;
    setState(() => _justCopied = true);
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _justCopied = false);
    });
  }

  Future<void> _onShare(BuildContext context) async {
    HapticFeedback.selectionClick();
    final body = 'Join "${widget.kitchenName}" on Chefless.\n\n'
        'Use this invite code: ${widget.inviteCode}';
    final box = context.findRenderObject() as RenderBox?;
    Rect? origin;
    if (box != null && box.hasSize) {
      origin = box.localToGlobal(Offset.zero) & box.size;
    }
    await SharePlus.instance.share(
      ShareParams(
        text: body,
        subject: 'Join my Chefless kitchen',
        sharePositionOrigin: origin,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Invite code',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.gray500,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(width: AppTheme.spacing8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _justCopied
                  ? Container(
                      key: const ValueKey('copied'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: const BoxDecoration(
                        color: AppTheme.successLight,
                        borderRadius: AppTheme.borderRadiusFull,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_rounded,
                            size: 11,
                            color: AppTheme.success,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Copied',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.success,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _onCopy,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  widget.inviteCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3.5,
                    color: AppTheme.textPrimaryDeep,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            _IconAction(
              icon: Icons.copy_rounded,
              tooltip: 'Copy code',
              onTap: _onCopy,
            ),
            const SizedBox(width: AppTheme.spacing8),
            _IconAction(
              icon: Icons.ios_share_rounded,
              tooltip: 'Share invite',
              onTap: () => _onShare(context),
              accent: true,
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spacing8),
        const Text(
          'Share this with family or friends to invite them.',
          style: TextStyle(
            fontSize: 12.5,
            color: AppTheme.gray500,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: accent ? AppTheme.accentPlayful : Colors.white,
        borderRadius: AppTheme.borderRadiusMedium,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: AppTheme.accentPlayful.withValues(alpha: 0.12),
          highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.06),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              border: accent
                  ? null
                  : Border.all(
                      color: AppTheme.gray200.withValues(alpha: 0.7),
                    ),
              borderRadius: AppTheme.borderRadiusMedium,
            ),
            child: Icon(
              icon,
              size: 18,
              color: accent ? Colors.white : AppTheme.textPrimaryDeep,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipesFeatureRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.push('/kitchen/recipes');
        },
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(AppTheme.radiusXL),
          bottomRight: Radius.circular(AppTheme.radiusXL),
        ),
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.10),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing20,
            AppTheme.spacing16,
            AppTheme.spacing16,
            AppTheme.spacing16,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.accentPlayfulLight,
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  size: 20,
                  color: AppTheme.accentPlayful,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kitchen recipes',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryDeep,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Browse everything shared across the kitchen.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.gray500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 18,
                color: AppTheme.accentPlayful,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Tab content ──────────────────────────────────────────────────────────────

class _MembersTabView extends ConsumerWidget {
  const _MembersTabView({
    required this.detail,
    required this.isLead,
    required this.currentUserId,
    required this.onRefresh,
  });

  final KitchenDetail detail;
  final bool isLead;
  final String currentUserId;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchen = detail.kitchen;
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isPremium = currentUser?.isPremium ?? false;
    final atCapacity = !isPremium && kitchen.memberCount >= 4;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.accentPlayful,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: AppTheme.spacing32),
        children: [
          if (isLead && atCapacity)
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing4,
              ),
              child: _CapacityBanner(),
            ),
          const _SectionHeader(
            title: 'Roster',
            subtitle: 'Everyone cooking together in this kitchen.',
          ),
          ...detail.members.map((member) {
            final memberIsLead = member.id == kitchen.leadId;
            final canEditSchedule =
                kitchen.membersWithScheduleEdit.contains(member.id);
            final canApprove =
                kitchen.membersWithApprovalPower.contains(member.id);
            return Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                0,
                AppTheme.spacing16,
                AppTheme.spacing10,
              ),
              child: _MemberTile(
                member: member,
                isLead: memberIsLead,
                canEditSchedule: canEditSchedule,
                canApprove: canApprove,
                showRemoveButton: isLead && member.id != currentUserId,
                onRemove: () => _confirmRemove(context, ref, member),
                onTransfer: isLead && member.id != currentUserId
                    ? () => _confirmTransfer(context, ref, member)
                    : null,
              ),
            );
          }),
          if (isLead) ...[
            const SizedBox(height: AppTheme.spacing12),
            const _SectionHeader(
              title: 'Lead controls',
              subtitle: 'Tools for kitchen leads.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              child: _LeadActionsCard(),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    CheflessUser member,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member'),
        content: Text(
          'Remove ${member.fullName} from the kitchen? They will lose access '
          'to the schedule, suggestions, and shared recipes.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
              final success = await ref
                  .read(kitchenActionProvider.notifier)
                  .removeMember(member.id);
              if (context.mounted && !success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Failed to remove member.')),
                );
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _confirmTransfer(
    BuildContext context,
    WidgetRef ref,
    CheflessUser member,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Transfer lead'),
        content: Text(
          'Transfer the Kitchen Lead role to ${member.fullName}? '
          'You will become a regular member and lose lead-only controls.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentPlayful,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              final success = await ref
                  .read(kitchenActionProvider.notifier)
                  .transferLead(member.id);
              if (context.mounted && !success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Failed to transfer lead role.'),
                  ),
                );
              }
            },
            child: const Text('Transfer'),
          ),
        ],
      ),
    );
  }
}

class _SettingsTabView extends ConsumerWidget {
  const _SettingsTabView({
    required this.detail,
    required this.isLead,
    required this.onRefresh,
  });

  final KitchenDetail detail;
  final bool isLead;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kitchen = detail.kitchen;
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppTheme.accentPlayful,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.only(bottom: AppTheme.spacing32),
        children: [
          const _SectionHeader(
            title: 'Privacy',
            subtitle: 'Who can discover this kitchen.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
            ),
            child: _PrivacyCard(kitchen: kitchen, isLead: isLead),
          ),
          const _SectionHeader(
            title: 'Schedule policy',
            subtitle: 'Who can add meals directly to the schedule.',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
            ),
            child: _SchedulePolicyCard(kitchen: kitchen, isLead: isLead),
          ),
          if (isLead) ...[
            const _SectionHeader(
              title: 'Meal slot categories',
              subtitle: 'Add custom rows beyond Breakfast, Lunch, Dinner, '
                  'and Snack.',
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing16,
              ),
              child: _MealSlotsCard(kitchen: kitchen),
            ),
          ],
          const _SectionHeader(
            title: 'Danger zone',
            subtitle: 'Permanent actions. Proceed carefully.',
            destructive: true,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
            ),
            child: _DangerCard(isLead: isLead),
          ),
        ],
      ),
    );
  }
}

// ── Section header (accent-bar serif) ────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.subtitle,
    this.destructive = false,
  });

  final String title;
  final String? subtitle;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final barColor = destructive ? AppTheme.error : AppTheme.accentPlayful;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing24,
        AppTheme.spacing16,
        AppTheme.spacing12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppTheme.spacing8),
              Flexible(
                child: Text(
                  title,
                  style: AppTheme.displayTitleSmall().copyWith(
                    fontSize: 19,
                    height: 1.1,
                    color: destructive ? AppTheme.error : null,
                  ),
                ),
              ),
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: AppTheme.spacing4),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(
                subtitle!,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.gray500,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Capacity banner ──────────────────────────────────────────────────────────

class _CapacityBanner extends StatelessWidget {
  const _CapacityBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing14),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        borderRadius: AppTheme.borderRadiusLarge,
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: AppTheme.borderRadiusMedium,
            ),
            child: const Icon(
              Icons.group_rounded,
              size: 18,
              color: AppTheme.warning,
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kitchen at capacity',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.gray900,
                    letterSpacing: -0.1,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Upgrade to Premium for unlimited members.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.gray600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spacing8),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentPlayful,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spacing14,
                vertical: 8,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.1,
              ),
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              PaywallBottomSheet.show(
                context,
                reason: PaywallReason.kitchenCapacityReached,
              );
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

// ── Member tile ──────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isLead,
    required this.canEditSchedule,
    required this.canApprove,
    required this.showRemoveButton,
    required this.onRemove,
    this.onTransfer,
  });

  final CheflessUser member;
  final bool isLead;
  final bool canEditSchedule;
  final bool canApprove;
  final bool showRemoveButton;
  final VoidCallback onRemove;
  final VoidCallback? onTransfer;

  @override
  Widget build(BuildContext context) {
    final badges = <Widget>[
      if (isLead)
        const _RoleBadge(
          label: 'Lead',
          color: AppTheme.accentPlayful,
          background: AppTheme.accentPlayfulLight,
          icon: Icons.star_rounded,
        ),
      if (canEditSchedule)
        _RoleBadge(
          label: 'Editor',
          color: AppTheme.info,
          background: AppTheme.info.withValues(alpha: 0.10),
          icon: Icons.edit_calendar_rounded,
        ),
      if (canApprove)
        _RoleBadge(
          label: 'Approver',
          color: AppTheme.success,
          background: AppTheme.success.withValues(alpha: 0.10),
          icon: Icons.verified_rounded,
        ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusLarge,
        boxShadow: AppTheme.shadowSm,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spacing14,
          AppTheme.spacing12,
          AppTheme.spacing8,
          AppTheme.spacing12,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            UserAvatar(
              fullName: member.fullName,
              profilePictureUrl: member.profilePicture,
              size: 44,
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.fullName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryDeep,
                      letterSpacing: -0.2,
                    ),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: badges,
                    ),
                  ],
                ],
              ),
            ),
            if (showRemoveButton)
              SizedBox(
                width: 36,
                height: 36,
                child: PopupMenuButton<String>(
                  padding: EdgeInsets.zero,
                  tooltip: 'Member actions',
                  icon: const Icon(
                    Icons.more_horiz_rounded,
                    color: AppTheme.gray400,
                    size: 20,
                  ),
                  onOpened: () => HapticFeedback.selectionClick(),
                  itemBuilder: (ctx) => [
                    if (onTransfer != null)
                      const PopupMenuItem(
                        value: 'transfer',
                        child: Row(
                          children: [
                            Icon(
                              Icons.workspace_premium_rounded,
                              size: 18,
                              color: AppTheme.accentPlayful,
                            ),
                            SizedBox(width: 10),
                            Text('Make lead'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'remove',
                      child: Row(
                        children: [
                          Icon(
                            Icons.person_remove_rounded,
                            size: 18,
                            color: AppTheme.error,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Remove',
                            style: TextStyle(color: AppTheme.error),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'remove') {
                      onRemove();
                    } else if (value == 'transfer') {
                      onTransfer?.call();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({
    required this.label,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color background;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppTheme.borderRadiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Settings cards ───────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusLarge,
        boxShadow: AppTheme.shadowSm,
      ),
      child: child,
    );
  }
}

class _PrivacyCard extends ConsumerStatefulWidget {
  const _PrivacyCard({required this.kitchen, required this.isLead});

  final Kitchen kitchen;
  final bool isLead;

  @override
  ConsumerState<_PrivacyCard> createState() => _PrivacyCardState();
}

class _PrivacyCardState extends ConsumerState<_PrivacyCard> {
  bool _isSaving = false;
  late bool _localIsPublic;

  @override
  void initState() {
    super.initState();
    _localIsPublic = widget.kitchen.isPublic;
  }

  @override
  void didUpdateWidget(covariant _PrivacyCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kitchen.isPublic != widget.kitchen.isPublic) {
      _localIsPublic = widget.kitchen.isPublic;
    }
  }

  Future<void> _toggle(bool value) async {
    HapticFeedback.selectionClick();
    setState(() {
      _isSaving = true;
      _localIsPublic = value;
    });
    final success = await ref
        .read(kitchenActionProvider.notifier)
        .updateKitchenVisibility(value);
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      if (!success) _localIsPublic = widget.kitchen.isPublic;
    });
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update kitchen privacy.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPublic = _localIsPublic;
    return _SettingsCard(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: isPublic
                        ? AppTheme.accentPlayfulLight
                        : AppTheme.gray100,
                    borderRadius: AppTheme.borderRadiusMedium,
                  ),
                  child: Icon(
                    isPublic ? Icons.public_rounded : Icons.lock_rounded,
                    size: 18,
                    color: isPublic
                        ? AppTheme.accentPlayful
                        : AppTheme.gray700,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isPublic ? 'Public kitchen' : 'Private kitchen',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimaryDeep,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isPublic
                            ? 'Discoverable on community surfaces.'
                            : 'Only members of this kitchen can see it.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.gray500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.isLead)
                  _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                              AppTheme.accentPlayful,
                            ),
                          ),
                        )
                      : Switch(
                          value: isPublic,
                          activeThumbColor: Colors.white,
                          activeTrackColor: AppTheme.accentPlayful,
                          onChanged: _toggle,
                        ),
              ],
            ),
            const SizedBox(height: AppTheme.spacing12),
            Text(
              widget.isLead
                  ? 'Private kitchens stay member-only. Turn this on only if '
                      'you’re comfortable with the kitchen being discoverable.'
                  : 'Private kitchens stay member-only. Your kitchen lead '
                      'controls this setting.',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.gray600,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchedulePolicyCard extends ConsumerStatefulWidget {
  const _SchedulePolicyCard({required this.kitchen, required this.isLead});

  final Kitchen kitchen;
  final bool isLead;

  @override
  ConsumerState<_SchedulePolicyCard> createState() =>
      _SchedulePolicyCardState();
}

class _SchedulePolicyCardState extends ConsumerState<_SchedulePolicyCard> {
  bool _isSaving = false;

  String _policyLabel(String policy) {
    return policy == 'all' ? 'Anyone in the kitchen' : 'Only the lead';
  }

  String _policyDescription(String policy, bool isLead) {
    if (policy == 'all') {
      return isLead
          ? 'All members can add meals directly to the schedule.'
          : 'All members can add meals directly. Your kitchen lead controls '
              'this setting.';
    }
    return isLead
        ? 'Only you (and editors) add meals directly. Everyone else sends '
            'suggestions for you or an approver to confirm.'
        : 'Only the kitchen lead (and editors) add directly. Your additions '
            'are sent as suggestions for the lead or an approver to confirm.';
  }

  Future<void> _openPolicyPicker(String currentPolicy) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppTheme.radiusXL)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing20,
              AppTheme.spacing4,
              AppTheme.spacing20,
              AppTheme.spacing16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spacing8,
                  ),
                  child: Text(
                    'Who can add to the schedule',
                    style: AppTheme.displayTitleSmall(),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing4),
                _PolicyOption(
                  value: 'lead_only',
                  selected: currentPolicy == 'lead_only',
                  title: 'Only the lead can add',
                  subtitle:
                      'Members send suggestions that the lead or approvers '
                      'confirm.',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(ctx).pop('lead_only');
                  },
                ),
                const SizedBox(height: AppTheme.spacing8),
                _PolicyOption(
                  value: 'all',
                  selected: currentPolicy == 'all',
                  title: 'Anyone in the kitchen',
                  subtitle: 'All members add meals to the schedule directly.',
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(ctx).pop('all');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    if (selected == null || selected == currentPolicy) return;

    setState(() => _isSaving = true);
    final success = await ref
        .read(kitchenActionProvider.notifier)
        .updateScheduleAddPolicy(selected);
    if (!mounted) return;
    setState(() => _isSaving = false);
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update schedule add policy.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final policy = widget.kitchen.scheduleAddPolicy;
    final label = _policyLabel(policy);
    final description = _policyDescription(policy, widget.isLead);

    return _SettingsCard(
      child: InkWell(
        onTap: widget.isLead && !_isSaving
            ? () => _openPolicyPicker(policy)
            : null,
        borderRadius: AppTheme.borderRadiusLarge,
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: const BoxDecoration(
                      color: AppTheme.accentPlayfulLight,
                      borderRadius: AppTheme.borderRadiusMedium,
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      size: 18,
                      color: AppTheme.accentPlayful,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add policy',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimaryDeep,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          label,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.gray500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isLead)
                    _isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(
                                AppTheme.accentPlayful,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.chevron_right_rounded,
                            color: AppTheme.gray400,
                          )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: const BoxDecoration(
                        color: AppTheme.gray100,
                        borderRadius: AppTheme.borderRadiusFull,
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 11,
                            color: AppTheme.gray600,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Lead only',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.gray700,
                              letterSpacing: 0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.gray600,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PolicyOption extends StatelessWidget {
  const _PolicyOption({
    required this.value,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String value;
  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppTheme.borderRadiusLarge,
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing14),
          decoration: BoxDecoration(
            color: selected ? AppTheme.accentPlayfulLight : Colors.white,
            borderRadius: AppTheme.borderRadiusLarge,
            border: Border.all(
              color: selected
                  ? AppTheme.accentPlayful.withValues(alpha: 0.32)
                  : AppTheme.gray200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppTheme.accentPlayful : Colors.white,
                  border: Border.all(
                    color: selected
                        ? AppTheme.accentPlayful
                        : AppTheme.gray300,
                    width: selected ? 2 : 1.5,
                  ),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryDeep,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.gray500,
                        height: 1.4,
                      ),
                    ),
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

class _MealSlotsCard extends ConsumerStatefulWidget {
  const _MealSlotsCard({required this.kitchen});

  final Kitchen kitchen;

  @override
  ConsumerState<_MealSlotsCard> createState() => _MealSlotsCardState();
}

class _MealSlotsCardState extends ConsumerState<_MealSlotsCard> {
  bool _isSaving = false;

  Future<void> _addSlot() async {
    HapticFeedback.selectionClick();
    final controller = TextEditingController();
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add meal slot'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          maxLength: 50,
          decoration: const InputDecoration(
            hintText: 'e.g. Pre-Workout, Late Night…',
            counterText: '',
          ),
          onSubmitted: (v) {
            final trimmed = v.trim();
            if (trimmed.isNotEmpty) Navigator.of(ctx).pop(trimmed);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.accentPlayful,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                HapticFeedback.lightImpact();
                Navigator.of(ctx).pop(trimmed);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newName == null || newName.isEmpty || !mounted) return;

    final current = widget.kitchen.customMealSlots;
    if (current.any((s) => s.toLowerCase() == newName.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$newName" already exists.')),
      );
      return;
    }

    await _save([...current, newName]);
  }

  Future<void> _removeSlot(String slot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove slot'),
        content: Text(
          'Remove "$slot" from the schedule?\n\n'
          'Meals already assigned to this slot will remain on the schedule, '
          'but the slot row will no longer appear when empty.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () {
              HapticFeedback.heavyImpact();
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final updated = widget.kitchen.customMealSlots
        .where((s) => s.toLowerCase() != slot.toLowerCase())
        .toList();
    await _save(updated);
  }

  Future<void> _save(List<String> slots) async {
    setState(() => _isSaving = true);
    final success = await ref
        .read(kitchenActionProvider.notifier)
        .setCustomMealSlots(slots);
    if (mounted) {
      setState(() => _isSaving = false);
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update meal slots.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final slots = widget.kitchen.customMealSlots;
    return _SettingsCard(
      child: Column(
        children: [
          if (slots.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing16,
                AppTheme.spacing12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppTheme.gray100,
                      borderRadius: AppTheme.borderRadiusMedium,
                    ),
                    child: const Icon(
                      Icons.label_outline_rounded,
                      size: 16,
                      color: AppTheme.gray500,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  const Expanded(
                    child: Text(
                      'No custom slots yet — add one below.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.gray500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spacing12,
                AppTheme.spacing8,
                AppTheme.spacing8,
                AppTheme.spacing4,
              ),
              child: Column(
                children: [
                  for (var i = 0; i < slots.length; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: AppTheme.accentPlayfulLight,
                              borderRadius: AppTheme.borderRadiusMedium,
                            ),
                            child: const Icon(
                              Icons.label_rounded,
                              size: 15,
                              color: AppTheme.accentPlayful,
                            ),
                          ),
                          const SizedBox(width: AppTheme.spacing12),
                          Expanded(
                            child: Text(
                              slots[i],
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimaryDeep,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Remove slot',
                            icon: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: AppTheme.gray400,
                            ),
                            onPressed:
                                _isSaving ? null : () => _removeSlot(slots[i]),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
            ),
            color: AppTheme.gray100,
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _isSaving ? null : _addSlot,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(AppTheme.radiusLarge),
                bottomRight: Radius.circular(AppTheme.radiusLarge),
              ),
              splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
              highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spacing14),
                child: Row(
                  children: [
                    if (_isSaving)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(
                            AppTheme.accentPlayful,
                          ),
                        ),
                      )
                    else
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppTheme.accentPlayful,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(width: AppTheme.spacing12),
                    const Text(
                      'Add custom slot',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accentPlayful,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeadActionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _SettingsCard(
      child: Column(
        children: [
          _LeadActionRow(
            icon: Icons.admin_panel_settings_rounded,
            iconBg: AppTheme.primaryLight,
            iconColor: AppTheme.primaryColor,
            title: 'Manage permissions',
            subtitle: 'Decide who can edit the schedule and approve.',
            onTap: () {
              HapticFeedback.selectionClick();
              context.push('/kitchen/permissions');
            },
            isFirst: true,
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(
              horizontal: AppTheme.spacing16,
            ),
            color: AppTheme.gray100,
          ),
          Consumer(
            builder: (context, ref, _) => _LeadActionRow(
              icon: Icons.refresh_rounded,
              iconBg: AppTheme.warningLight,
              iconColor: AppTheme.warning,
              title: 'Regenerate invite code',
              subtitle: 'The current code will stop working.',
              onTap: () => _confirmRegenerate(context, ref),
              isLast: true,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmRegenerate(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Regenerate invite code'),
        content: const Text(
          'The current invite code will be invalidated. Anyone holding the '
          'old code will no longer be able to join.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.warning),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(ctx);
              final success = await ref
                  .read(kitchenActionProvider.notifier)
                  .regenerateInviteCode();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Invite code regenerated.'
                          : 'Failed to regenerate code.',
                    ),
                  ),
                );
              }
            },
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
  }
}

class _LeadActionRow extends StatelessWidget {
  const _LeadActionRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isFirst = false,
    this.isLast = false,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.only(
      topLeft: Radius.circular(isFirst ? AppTheme.radiusLarge : 0),
      topRight: Radius.circular(isFirst ? AppTheme.radiusLarge : 0),
      bottomLeft: Radius.circular(isLast ? AppTheme.radiusLarge : 0),
      bottomRight: Radius.circular(isLast ? AppTheme.radiusLarge : 0),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: AppTheme.accentPlayful.withValues(alpha: 0.08),
        highlightColor: AppTheme.accentPlayful.withValues(alpha: 0.04),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing14),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: AppTheme.borderRadiusMedium,
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryDeep,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.gray500,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.gray400,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DangerCard extends ConsumerWidget {
  const _DangerCard({required this.isLead});

  final bool isLead;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated,
        borderRadius: AppTheme.borderRadiusLarge,
        boxShadow: AppTheme.shadowSm,
        border: Border.all(
          color: AppTheme.error.withValues(alpha: 0.18),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (isLead) {
              _confirmDelete(context, ref);
            } else {
              _confirmLeave(context, ref);
            }
          },
          borderRadius: AppTheme.borderRadiusLarge,
          splashColor: AppTheme.error.withValues(alpha: 0.08),
          highlightColor: AppTheme.error.withValues(alpha: 0.04),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: AppTheme.errorLight,
                    borderRadius: AppTheme.borderRadiusMedium,
                  ),
                  child: Icon(
                    isLead
                        ? Icons.delete_forever_rounded
                        : Icons.exit_to_app_rounded,
                    size: 20,
                    color: AppTheme.error,
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLead ? 'Delete kitchen' : 'Leave kitchen',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLead
                            ? 'Removes every member. Cannot be undone.'
                            : 'You will lose access to the schedule and shared '
                                'recipes.',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.gray500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.error.withValues(alpha: 0.6),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLeave(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave kitchen'),
        content: const Text('Are you sure you want to leave this kitchen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
              final success =
                  await ref.read(kitchenActionProvider.notifier).leaveKitchen();
              if (context.mounted) {
                if (success) {
                  context.go('/kitchen');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to leave kitchen.')),
                  );
                }
              }
            },
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete kitchen'),
        content: const Text(
          'This action is permanent and cannot be undone. All members will be '
          'removed from the kitchen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () async {
              HapticFeedback.heavyImpact();
              Navigator.pop(ctx);
              final success = await ref
                  .read(kitchenActionProvider.notifier)
                  .deleteKitchen();
              if (context.mounted) {
                if (success) {
                  context.go('/kitchen');
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete kitchen.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
  }
}

// ── Pinned tab bar ───────────────────────────────────────────────────────────

class _KitchenTabBarDelegate extends SliverPersistentHeaderDelegate {
  _KitchenTabBarDelegate({required this.tabBar});

  final TabBar tabBar;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scrolled = shrinkOffset > 0 || overlapsContent;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.surfaceWarm,
        boxShadow: scrolled
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: tabBar),
          ),
          Container(
            height: 1,
            color: scrolled
                ? AppTheme.gray200
                : AppTheme.gray200.withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_KitchenTabBarDelegate oldDelegate) => false;
}

// ── No-kitchen / loading / error ─────────────────────────────────────────────

class _NoKitchenView extends StatelessWidget {
  const _NoKitchenView({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentPlayfulLight,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.accentPlayful.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.kitchen_rounded,
                size: 44,
                color: AppTheme.accentPlayful,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Text(
              'No kitchen yet',
              style: AppTheme.displayTitleMedium(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spacing8),
            const Text(
              'Create a kitchen for your household, or join one with an '
              'invite code to plan meals, share recipes, and shop together.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.gray500,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push('/kitchen/create');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentPlayful,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Create kitchen'),
              ),
            ),
            const SizedBox(height: AppTheme.spacing12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push('/kitchen/join');
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentPlayful,
                  side: const BorderSide(
                    color: AppTheme.accentPlayful,
                    width: 1.5,
                  ),
                ),
                icon: const Icon(Icons.group_add_rounded, size: 20),
                label: const Text('Join kitchen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Hero skeleton
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spacing16,
            AppTheme.spacing12,
            AppTheme.spacing16,
            AppTheme.spacing16,
          ),
          child: Container(
            height: 280,
            decoration: const BoxDecoration(
              color: AppTheme.gray100,
              borderRadius: AppTheme.borderRadiusXL,
            ),
          ),
        ),
        // Tab placeholder
        const SizedBox(height: AppTheme.spacing12),
        // Member shimmers
        const UserListShimmer(itemCount: 4),
      ],
    );
  }
}

class _KitchenErrorView extends StatelessWidget {
  const _KitchenErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppTheme.spacingXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppTheme.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: AppTheme.error,
              ),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              'Couldn’t load your kitchen',
              style: AppTheme.displayTitleSmall(),
            ),
            const SizedBox(height: AppTheme.spacing6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.gray500,
                height: 1.45,
              ),
            ),
            const SizedBox(height: AppTheme.spacing20),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
