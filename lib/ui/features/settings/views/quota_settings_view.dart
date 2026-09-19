import 'package:pi_gui/ui/atoms/app_progress_indicator.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../atoms/app_action_button.dart';
import '../../../atoms/app_card.dart';
import '../../../atoms/app_setting.dart';
import '../../../core/context_l10n.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_context_extensions.dart';
import '../controllers/quota_controller.dart';

/// Settings page "账号额度": reads the Codex OAuth token from Pi's
/// auth.json and renders the live ChatGPT plan usage windows.
///
/// All data comes from [QuotaController]; this widget only renders states.
class QuotaSettingsContent extends StatelessWidget {
  const QuotaSettingsContent({
    super.key,
    required this.controller,
    this.query = '',
  });
  final QuotaController controller;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.quotaPageTitle, style: context.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.quotaPageSubtitle,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              AppActionButton.subtle(
                label: controller.isRefreshing
                    ? l.quotaRefreshing
                    : l.quotaRefresh,
                leading: controller.isRefreshing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: AppProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                onPressed: controller.isRefreshing ? null : controller.refresh,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxxl),
          switch (controller.status) {
            QuotaStatus.loading => AppCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: AppProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l.quotaLoading,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            QuotaStatus.missing => _MissingCard(controller: controller),
            QuotaStatus.failed => _FailedCard(controller: controller),
            QuotaStatus.ready => _buildBody(context),
          },
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final snapshot = controller.snapshot!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (snapshot.limitReached)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: AppCard(
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      context.l10n.quotaLimitReached,
                      style: context.textTheme.bodyMedium?.copyWith(
                        color: context.colors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        _AccountGroup(controller: controller, snapshot: snapshot),
        const SizedBox(height: AppSpacing.xxl),
        _UsageGroup(snapshot: snapshot),
        const SizedBox(height: AppSpacing.xxl),
        _CreditsGroup(snapshot: snapshot),
      ],
    );
  }
}

class _MissingCard extends StatelessWidget {
  const _MissingCard({required this.controller});
  final QuotaController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.quotaMissingTitle, style: context.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l.quotaMissingHint,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FailedCard extends StatelessWidget {
  const _FailedCard({required this.controller});
  final QuotaController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final message = switch (controller.failure) {
      QuotaFailure.unauthorized => l.quotaUnauthorizedHint,
      QuotaFailure.network => l.quotaNetworkHint,
      _ => l.quotaParseHint,
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.quotaFailedTitle, style: context.textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: context.textTheme.bodySmall?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppActionButton.subtle(
            label: l.appearanceRetry,
            leading: const Icon(Icons.refresh),
            onPressed: controller.refresh,
          ),
        ],
      ),
    );
  }
}

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.controller, required this.snapshot});
  final QuotaController controller;
  final CodexUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final expiresAt = controller.auth?.expiresAt;
    final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());
    return AppSettingsGroup(
      title: l.quotaAccountGroup,
      children: [
        AppSettingRow(
          title: l.quotaProvider,
          description: l.quotaProviderDescription,
          control: Text('OpenAI Codex', style: context.textTheme.labelLarge),
        ),
        AppSettingRow(
          title: l.quotaEmail,
          control: Text(
            snapshot.email.isEmpty ? '—' : snapshot.email,
            style: context.textTheme.labelLarge,
          ),
        ),
        AppSettingRow(
          title: l.quotaPlan,
          control: Text(
            snapshot.planType.isEmpty ? '—' : snapshot.planType,
            style: context.textTheme.labelLarge,
          ),
        ),
        AppSettingRow(
          title: l.quotaTokenExpiry,
          description: expired ? l.quotaTokenExpiredHint : null,
          control: Text(
            expiresAt == null
                ? '—'
                : DateFormat.yMd().add_Hm().format(expiresAt.toLocal()),
            style: context.textTheme.labelLarge?.copyWith(
              color: expired ? colors.error : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _UsageGroup extends StatelessWidget {
  const _UsageGroup({required this.snapshot});
  final CodexUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppSettingsGroup(
      title: l.quotaUsageGroup,
      description: l.quotaUsageGroupDescription,
      children: [
        _WindowRow(title: l.quotaPrimaryWindow, window: snapshot.primaryWindow),
        _WindowRow(
          title: l.quotaSecondaryWindow,
          window: snapshot.secondaryWindow,
        ),
      ],
    );
  }
}

class _WindowRow extends StatelessWidget {
  const _WindowRow({required this.title, required this.window});
  final String title;
  final CodexUsageWindow? window;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    if (window == null) {
      return AppSettingRow(
        title: title,
        control: Text('—', style: context.textTheme.labelLarge),
      );
    }
    final used = window!.usedPercent;
    final barColor = used >= 90
        ? colors.error
        : used >= 70
        ? colors.warning
        : colors.success;
    final resetAt = window!.resetAtUtc;
    return AppSettingRow(
      title: title,
      description: resetAt == null
          ? null
          : l.quotaWindowResets(
              DateFormat.yMd().add_Hm().format(resetAt.toLocal()),
            ),
      control: _UsageBar(percent: used, color: barColor),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.percent, required this.color});
  final int percent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final remaining = (100 - percent).clamp(0, 100);
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$percent%', style: context.textTheme.labelLarge),
              Text(
                l.quotaRemaining(remaining),
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent / 100),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : AppDurations.slow,
              curve: AppCurves.smoothOut,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: colors.mutedBackground,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditsGroup extends StatelessWidget {
  const _CreditsGroup({required this.snapshot});
  final CodexUsageSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppSettingsGroup(
      title: l.quotaCreditsGroup,
      children: [
        AppSettingRow(
          title: l.quotaCreditsBalance,
          description: l.quotaCreditsDescription,
          control: Text(
            snapshot.hasCredits ? snapshot.creditsBalance : l.quotaNoCredits,
            style: context.textTheme.labelLarge,
          ),
        ),
      ],
    );
  }
}
