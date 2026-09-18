import 'dart:async';

import 'package:flutter/material.dart';

import '../../../atoms/app_action_button.dart';
import '../../../atoms/app_badge.dart';
import '../../../atoms/app_card.dart';
import '../../../atoms/app_code_block.dart';
import '../../../atoms/app_dialog.dart';
import '../../../atoms/app_disclosure.dart';
import '../../../atoms/app_icon_button.dart';
import '../../../atoms/app_select.dart';
import '../../../atoms/app_setting.dart';
import '../../../atoms/app_text_field.dart';
import '../../../core/chat_resource_scope.dart';
import '../../../core/context_l10n.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_context_extensions.dart';
import '../../../../core/rpc/pi_packages_types.dart';
import '../controllers/packages_controller.dart';

enum _PackagesTab { gallery, manage }

/// Settings page "plugins": gallery (npm pi-package search) plus a
/// pi-config-style management tab. Pure rendering; all logic lives in
/// [PackagesController].
class PackagesSettingsContent extends StatefulWidget {
  const PackagesSettingsContent({
    super.key,
    required this.controller,
    this.query = '',
  });
  final PackagesController controller;
  final String query;

  @override
  State<PackagesSettingsContent> createState() =>
      _PackagesSettingsContentState();
}

class _PackagesSettingsContentState extends State<PackagesSettingsContent> {
  _PackagesTab _tab = _PackagesTab.gallery;
  static const _pageSize = 30;
  int _galleryVisible = _pageSize;
  Timer? _search;
  final _gallerySearch = TextEditingController();

  @override
  void initState() {
    super.initState();
    _scheduleGallerySearch();
  }

  @override
  void dispose() {
    _search?.cancel();
    _gallerySearch.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PackagesSettingsContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The shared settings search now filters the gallery list client-side,
    // so a changed query only restarts paging, not a network round trip.
    if (widget.query != oldWidget.query) {
      _galleryVisible = _pageSize;
    }
  }

  // The gallery owns its search box: bursts of keystrokes collapse into one
  // npm registry round trip, and paging restarts with every new query.
  void _onGallerySearchChanged() {
    _galleryVisible = _pageSize;
    _scheduleGallerySearch();
    setState(() {});
  }

  void _scheduleGallerySearch() {
    _search?.cancel();
    _search = Timer(const Duration(milliseconds: 350), () {
      if (mounted) widget.controller.searchGallery(_gallerySearch.text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.pluginsPageTitle, style: context.textTheme.displaySmall),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l.pluginsPageSubtitle,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              _tabButton(_PackagesTab.gallery, l.pluginsTabGallery),
              const SizedBox(width: AppSpacing.sm),
              _tabButton(_PackagesTab.manage, l.pluginsTabManage),
            ],
          ),
          const SizedBox(height: AppSpacing.xxl),
          switch (_tab) {
            _PackagesTab.gallery => _GalleryTab(
              controller: widget.controller,
              query: widget.query,
              visible: _galleryVisible,
              searchController: _gallerySearch,
              onSearchChanged: _onGallerySearchChanged,
              onShowMore: () =>
                  setState(() => _galleryVisible = _galleryVisible + _pageSize),
            ),
            _PackagesTab.manage => _ManageTab(
              controller: widget.controller,
              query: widget.query,
            ),
          },
        ],
      ),
    );
  }

  Widget _tabButton(_PackagesTab tab, String label) {
    final selected = _tab == tab;
    return selected
        ? AppActionButton(
            label: label,
            leading: Icon(
              tab == _PackagesTab.gallery
                  ? Icons.storefront_outlined
                  : Icons.tune_rounded,
            ),
            onPressed: () => setState(() => _tab = tab),
          )
        : AppActionButton.subtle(
            label: label,
            leading: Icon(
              tab == _PackagesTab.gallery
                  ? Icons.storefront_outlined
                  : Icons.tune_rounded,
            ),
            onPressed: () => setState(() => _tab = tab),
          );
  }
}

/// "pi.dev/packages"-style catalog browse with in-page search and sorting.
class _GalleryTab extends StatelessWidget {
  const _GalleryTab({
    required this.controller,
    required this.query,
    required this.visible,
    required this.searchController,
    required this.onSearchChanged,
    required this.onShowMore,
  });
  final PackagesController controller;
  final String query;
  final int visible;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final VoidCallback onShowMore;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final operation = controller.operation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: AppTextField(
                controller: searchController,
                hintText: l.pluginsSearchGalleryHint,
                isCompact: true,
                leading: const Icon(Icons.search),
                onChanged: (_) => onSearchChanged(),
                trailing: searchController.text.isEmpty
                    ? null
                    : AppIconButton.subtle(
                        icon: Icons.close,
                        tooltip: l.clearSearch,
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged();
                        },
                      ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppSelect<GallerySort>(
              value: controller.gallerySort,
              label: l.pluginsSortLabel,
              options: [
                AppSelectOption(GallerySort.relevance, l.pluginsSortRelevance),
                AppSelectOption(GallerySort.downloads, l.pluginsSortDownloads),
                AppSelectOption(GallerySort.updated, l.pluginsSortUpdated),
                AppSelectOption(GallerySort.name, l.pluginsSortName),
              ],
              onChanged: controller.setGallerySort,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          l.pluginsGalleryHint,
          style: context.textTheme.bodySmall?.copyWith(
            color: colors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        switch (controller.galleryStatus) {
          GalleryStatus.idle || GalleryStatus.loading => const AppCard(
            child: Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ),
            ),
          ),
          GalleryStatus.failed => AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.galleryFailure == null
                      ? l.pluginsGalleryFailed
                      : l.pluginsGalleryFailedDetail(
                          controller.galleryFailure!,
                        ),
                ),
                const SizedBox(height: AppSpacing.md),
                AppActionButton.subtle(
                  label: l.appearanceRetry,
                  leading: const Icon(Icons.refresh),
                  onPressed: () =>
                      controller.searchGallery(searchController.text),
                ),
              ],
            ),
          ),
          GalleryStatus.ready when _filtered.isEmpty => AppCard(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(l.pluginsGalleryEmpty),
            ),
          ),
          GalleryStatus.ready => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in _filtered.take(visible))
                _GalleryItem(
                  controller: controller,
                  item: item,
                  onInstall: () => controller.installFromGallery(item.name),
                ),
              if (visible < _filtered.length)
                Center(
                  child: AppActionButton.subtle(
                    label: l.pluginsShowMore,
                    leading: const Icon(Icons.expand_more_rounded),
                    onPressed: onShowMore,
                  ),
                ),
            ],
          ),
        },
        if (operation != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _OperationCard(controller: controller),
        ],
      ],
    );
  }

  // Sorted server results, narrowed client-side by the shared settings
  // search so both boxes stay useful without extra network calls.
  List<GalleryPackage> get _filtered => controller.sortedGallery
      .where((item) => _matches(item, query))
      .toList(growable: false);

  static bool _matches(GalleryPackage item, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return item.name.toLowerCase().contains(q) ||
        (item.description?.toLowerCase().contains(q) ?? false) ||
        item.keywords.any((keyword) => keyword.contains(q));
  }
}

class _GalleryItem extends StatelessWidget {
  const _GalleryItem({
    required this.controller,
    required this.item,
    required this.onInstall,
  });
  final PackagesController controller;
  final GalleryPackage item;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final installed = controller.isInstalled(item.name);
    final installing =
        controller.busy && controller.operation?.source == 'npm:${item.name}';
    final meta = [
      if (item.publisher != null) item.publisher!,
      if (item.updatedAt != null) item.updatedAt!.substring(0, 10),
      if (item.monthlyDownloads != null)
        l.pluginsMonthlyDownloads(item.monthlyDownloads!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      item.name,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (installed)
                    AppBadge(
                      label: l.pluginsInstalled,
                      variant: AppBadgeVariant.success,
                    )
                  else
                    AppActionButton(
                      label: installing
                          ? l.pluginsInstalling
                          : l.pluginsInstall,
                      leading: const Icon(Icons.download_rounded),
                      isLoading: installing,
                      onPressed: controller.busy ? null : onInstall,
                    ),
                ],
              ),
              if (item.description?.isNotEmpty == true) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.description!,
                  style: context.textTheme.bodyMedium?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  if (item.version.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppBadge(label: 'v${item.version}'),
                    ),
                  if (item.isExtension)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppBadge(label: l.pluginsResourcesExtensions),
                    ),
                  if (item.isSkill)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppBadge(label: l.pluginsResourcesSkills),
                    ),
                  Expanded(
                    child: Text(
                      meta,
                      overflow: TextOverflow.ellipsis,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  if (item.npmUrl != null)
                    AppIconButton.subtle(
                      icon: Icons.open_in_new_rounded,
                      tooltip: l.pluginsOpenNpm,
                      onPressed: () =>
                          ChatResourceScope.open(context, item.npmUrl!),
                    ),
                  if (item.repositoryUrl != null)
                    AppIconButton.subtle(
                      icon: Icons.code_rounded,
                      tooltip: l.pluginsOpenRepo,
                      onPressed: () =>
                          ChatResourceScope.open(context, item.repositoryUrl!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Installed packages with per-resource enable/disable, like `pi config`
/// in global mode.
class _ManageTab extends StatelessWidget {
  const _ManageTab({required this.controller, required this.query});
  final PackagesController controller;
  final String query;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final data = controller.state;
    return switch (controller.status) {
      PackagesStatus.loading => const AppCard(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      PackagesStatus.failed => AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              controller.failure == null
                  ? l.pluginsLoadFailed
                  : l.pluginsLoadFailedDetail(controller.failure!),
            ),
            const SizedBox(height: AppSpacing.md),
            AppActionButton.subtle(
              label: l.appearanceRetry,
              leading: const Icon(Icons.refresh),
              onPressed: controller.load,
            ),
          ],
        ),
      ),
      PackagesStatus.ready =>
        data == null ? const SizedBox.shrink() : _buildReady(context, data),
    };
  }

  Widget _buildReady(BuildContext context, PiPackagesState state) {
    final l = context.l10n;
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSettingsGroup(
          title: l.pluginsTabManage,
          description: controller.actionError != null
              ? l.pluginsActionFailed(controller.actionError!)
              : null,
          children: [
            AppSettingRow(
              title: l.pluginsCheckUpdates,
              description: controller.updates.isEmpty
                  ? null
                  : l.pluginsUpdatesAvailable(controller.updates.length),
              control: _CheckUpdatesButton(controller: controller),
            ),
            AppSettingRow(
              title: l.pluginsUpdateAll,
              description: l.pluginsProjectScopeHint,
              control: AppActionButton.subtle(
                label: l.pluginsUpdateAll,
                leading: const Icon(Icons.update_rounded),
                isLoading: controller.busy,
                onPressed: controller.updates.isEmpty || controller.busy
                    ? null
                    : controller.updateAll,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),
        if (state.packages.isEmpty && _topLevel(state).isEmpty)
          Text(
            l.pluginsEmpty,
            style: context.textTheme.bodyMedium?.copyWith(
              color: colors.textSecondary,
            ),
          )
        else ...[
          for (final entry in state.packages.where(
            (entry) => _matches(entry, query),
          ))
            _PackageCard(controller: controller, state: state, entry: entry),
          if (_topLevel(state).isNotEmpty)
            _TopLevelCard(controller: controller, state: state),
        ],
        if (controller.operation != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _OperationCard(controller: controller),
        ],
      ],
    );
  }

  static List<PiResourceItem> _topLevel(PiPackagesState state) => state
      .resources
      .values
      .expand((items) => items)
      .where((item) => item.origin == 'top-level' && item.isUserScope)
      .toList(growable: false);

  bool _matches(PiPackageEntry entry, String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return entry.source.toLowerCase().contains(q) ||
        (entry.installedPath?.toLowerCase().contains(q) ?? false);
  }
}

class _CheckUpdatesButton extends StatelessWidget {
  const _CheckUpdatesButton({required this.controller});
  final PackagesController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final checking =
        controller.busy && controller.operation?.kind == 'check_updates';
    return AppActionButton.subtle(
      label: checking ? l.pluginsChecking : l.pluginsCheckUpdates,
      leading: const Icon(Icons.refresh),
      isLoading: checking,
      onPressed: controller.busy ? null : controller.checkUpdates,
    );
  }
}

class _PackageCard extends StatelessWidget {
  const _PackageCard({
    required this.controller,
    required this.state,
    required this.entry,
  });
  final PackagesController controller;
  final PiPackagesState state;
  final PiPackageEntry entry;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final resources = state.resources.values
        .expand((items) => items)
        .where(
          (item) =>
              item.origin == 'package' &&
              item.source == entry.source &&
              item.scope == entry.scope,
        )
        .toList(growable: false);
    final updating =
        controller.busy &&
        (controller.operation?.source == entry.source ||
            controller.operation?.kind == 'update');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: AppCard(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.source,
                      style: context.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (entry.scope == 'project')
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppBadge(label: l.pluginsScopeProject),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppBadge(label: l.pluginsScopeUser),
                    ),
                  if (entry.filtered)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppBadge(label: l.pluginsFiltered),
                    ),
                  if (controller.hasUpdate(entry.source))
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppBadge(
                        label: l.pluginsUpdate,
                        variant: AppBadgeVariant.primary,
                      ),
                    ),
                ],
              ),
              if (entry.installedPath != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  entry.installedPath!,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.textSecondary,
                  ),
                ),
              ] else ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  l.pluginsNotInstalled,
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (controller.hasUpdate(entry.source))
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpacing.sm),
                      child: AppActionButton.subtle(
                        label: l.pluginsUpdate,
                        leading: const Icon(Icons.update_rounded),
                        isLoading: updating,
                        onPressed: controller.busy
                            ? null
                            : () => controller.updateSource(entry.source),
                      ),
                    ),
                  AppActionButton.subtle(
                    label: l.pluginsRemove,
                    leading: const Icon(Icons.delete_outline_rounded),
                    onPressed: controller.busy
                        ? null
                        : () => _confirmRemove(context, entry.source),
                  ),
                ],
              ),
              for (final item in resources)
                _ResourceRow(controller: controller, item: item),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, String source) async {
    final l = context.l10n;
    final confirmed = await showAppDialog<bool>(
      context,
      (context) => AppDialog(
        title: l.pluginsRemoveConfirmTitle,
        actions: [
          AppActionButton.subtle(
            label: l.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppActionButton(
            label: l.pluginsRemove,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(l.pluginsRemoveConfirmMessage(source)),
      ),
    );
    if (confirmed == true) await controller.remove(source);
  }
}

/// Top-level resources under ~/.pi/agent (extensions/, skills/, ...),
/// exactly the rows `pi config` shows outside any package.
class _TopLevelCard extends StatelessWidget {
  const _TopLevelCard({required this.controller, required this.state});
  final PackagesController controller;
  final PiPackagesState state;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final items = state.resources.values
        .expand((items) => items)
        .where((item) => item.origin == 'top-level' && item.isUserScope)
        .toList(growable: false);
    if (items.isEmpty) return const SizedBox.shrink();
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.pluginsTopLevelGroup,
              style: context.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            for (final item in items)
              _ResourceRow(controller: controller, item: item),
          ],
        ),
      ),
    );
  }
}

class _ResourceRow extends StatelessWidget {
  const _ResourceRow({required this.controller, required this.item});
  final PackagesController controller;
  final PiResourceItem item;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final typeLabel = switch (item.type) {
      'extensions' => l.pluginsResourcesExtensions,
      'skills' => l.pluginsResourcesSkills,
      'prompts' => l.pluginsResourcesPrompts,
      _ => l.pluginsResourcesThemes,
    };
    final name = item.path.split(RegExp(r'[\\/]')).last;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: AppBadge(label: typeLabel),
          ),
          Expanded(
            child: Tooltip(
              message: item.path,
              waitDuration: AppDurations.micro,
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: context.textTheme.bodyMedium?.copyWith(
                  color: item.enabled
                      ? colors.textPrimary
                      : colors.textSecondary,
                ),
              ),
            ),
          ),
          AppSelect<bool>(
            value: item.enabled,
            label: typeLabel,
            options: [
              AppSelectOption(false, l.pluginsToggleOff),
              AppSelectOption(true, l.pluginsToggleOn),
            ],
            isBusy: controller.isToggling(item),
            onChanged: item.isUserScope && !controller.busy
                ? (enabled) => controller.toggle(item, enabled)
                : null,
          ),
        ],
      ),
    );
  }
}

/// The active or last background operation with its streamed log.
class _OperationCard extends StatelessWidget {
  const _OperationCard({required this.controller});
  final PackagesController controller;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final operation = controller.operation;
    if (operation == null) return const SizedBox.shrink();
    final failed = operation.error != null;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: operation.running
                      ? const CircularProgressIndicator(strokeWidth: 2)
                      : Icon(
                          failed ? Icons.error_outline : Icons.check_rounded,
                          size: 16,
                          color: failed ? colors.warning : colors.primary,
                        ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    operation.running
                        ? l.pluginsBusyHint
                        : failed
                        ? l.pluginsActionFailed(operation.error ?? '')
                        : operation.source ?? operation.kind,
                    style: context.textTheme.bodyMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (operation.log.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppDisclosure(
                framed: false,
                initiallyExpanded: failed || operation.running,
                title: l.pluginsOperationLog,
                builder: (_) => AppCodeBlock(
                  code: operation.log
                      .skip(
                        (operation.log.length - 100).clamp(
                          0,
                          operation.log.length,
                        ),
                      )
                      .join('\n'),
                  label: operation.kind,
                  language: 'bash',
                  framed: false,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
