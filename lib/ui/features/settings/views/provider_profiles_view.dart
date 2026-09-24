import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pi_gui/core/rpc/pi_packages_types.dart';
import 'package:pi_gui/core/rpc/pi_provider_profiles_types.dart';
import 'package:pi_gui/core/services/provider_plugin_installer.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_badge.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
import 'package:pi_gui/ui/atoms/app_nav_tile.dart';
import 'package:pi_gui/ui/atoms/app_select.dart';
import 'package:pi_gui/ui/atoms/app_setting.dart';
import 'package:pi_gui/ui/atoms/app_text_field.dart';
import 'package:pi_gui/ui/core/context_l10n.dart';
import 'package:pi_gui/ui/core/theme/app_tokens.dart';
import 'package:pi_gui/ui/core/theme/theme_context_extensions.dart';

import '../controllers/packages_controller.dart';
import '../controllers/provider_profiles_controller.dart';

String _providerErrorText(BuildContext context, String code) {
  final l = context.l10n;
  return switch (code) {
    'PROFILE_INVALID' => l.providerErrorInvalid,
    'PROFILE_NAME_INVALID' => l.providerErrorName,
    'PROFILE_EXISTS' => l.providerErrorExists,
    'PROFILES_INVALID' => l.providerErrorFile,
    'PROFILE_NOT_FOUND' => l.providerErrorNotFound,
    'PROFILE_NO_MODELS' => l.providerErrorNoModels,
    'MODELS_UNREACHABLE' => l.providerErrorUnreachable,
    'MODELS_UNAUTHORIZED' => l.providerErrorUnauthorized,
    'MODELS_HTTP_ERROR' => l.providerErrorHttp,
    'MODELS_NOT_JSON' => l.providerErrorNotJson,
    'MODELS_EMPTY' => l.providerErrorEmpty,
    'MODELS_KEY_ENV_MISSING' => l.providerErrorKeyEnv,
    'MODELS_KEY_COMMAND_FAILED' => l.providerErrorKeyCommand,
    'PROFILE_KEY_ENDPOINT_CHANGED' => l.providerErrorKeyEndpoint,
    'OUTCOME_UNKNOWN' => l.providerErrorUnknownOutcome,
    'UNKNOWN_COMMAND' => l.providerErrorBackend,
    _ => l.providerErrorFallback,
  };
}

const _apis = [
  'openai-completions',
  'openai-responses',
  'anthropic-messages',
  'google-generative-ai',
];

/// Mirrors the adapter: Pi provider ids are opaque, CJK names are fine.
final _namePattern = RegExp(
  r'^[\p{L}\p{N}][\p{L}\p{N}._-]{0,63}$',
  unicode: true,
);

/// Cherry-Studio-style master/detail: compact profile list on the left, the
/// selected profile's connection and model list on the right. Saving writes
/// provider-profiles.json; the plugin re-registers the provider in every
/// running Pi, so no "use this profile" step exists.
class ProviderProfilesView extends StatefulWidget {
  const ProviderProfilesView({
    super.key,
    required this.packages,
    required this.profiles,
    this.query = '',
  });
  final PackagesController packages;
  final ProviderProfilesController profiles;
  final String query;
  @override
  State<ProviderProfilesView> createState() => _ProviderProfilesViewState();
}

class _ProviderProfilesViewState extends State<ProviderProfilesView> {
  String? _installError;
  bool _installing = false;

  /// Bumped to rebuild the editor (new draft / discarded edits).
  int _draftGeneration = 0;
  bool _dirty = false;

  List<PiResourceItem> get _extensions =>
      widget.packages.state?.resources['extensions']
          ?.where(
            (item) =>
                item.origin == 'package' &&
                item.path
                    .replaceAll('\\', '/')
                    .endsWith('/extensions/provider-switch.ts'),
          )
          .toList() ??
      const [];

  Future<bool> _confirm(String title, String body, String action) async =>
      await showAppDialog<bool>(
        context,
        (context) => AppDialog(
          title: title,
          actions: [
            AppActionButton.subtle(
              label: context.l10n.cancel,
              onPressed: () => Navigator.pop(context, false),
            ),
            AppActionButton(
              label: action,
              onPressed: () => Navigator.pop(context, true),
            ),
          ],
          child: Text(body),
        ),
      ) ==
      true;

  /// Installs, or replaces an older bundled registration with this version.
  Future<void> _install({PiResourceItem? outdated}) async {
    if (_installing || widget.packages.busy) return;
    final l = context.l10n;
    final approved = outdated == null
        ? await _confirm(
            l.providerInstallTitle,
            l.providerInstallWarning,
            l.pluginsInstall,
          )
        : await _confirm(
            l.providerUpgradeTitle,
            l.providerUpgradeWarning(ProviderPluginInstaller.version),
            l.providerUpgradeTitle,
          );
    if (!approved || !mounted) return;
    setState(() {
      _installing = true;
      _installError = null;
    });
    try {
      final source = await ProviderPluginInstaller.prepareSource();
      if (!mounted) return;
      var ok = await widget.packages.installSource(source);
      if (ok && outdated != null) {
        ok = await widget.packages.remove(outdated.source);
      }
      if (!mounted) return;
      if (ok) {
        await widget.packages.load();
        await widget.profiles.load();
      } else {
        _installError = widget.packages.actionError ?? 'PROVIDER_FAILED';
      }
    } catch (e) {
      _installError = ProviderProfilesController.errorCode(e);
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _select(String? name) async {
    final profiles = widget.profiles;
    if (name == profiles.selected && name != null) return;
    if (_dirty &&
        !await _confirm(
          context.l10n.providerDiscardTitle,
          context.l10n.providerDiscardBody,
          context.l10n.providerDiscard,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _dirty = false;
      _draftGeneration++;
    });
    profiles.select(name);
  }

  Widget _pluginNotice(BuildContext context) {
    final l = context.l10n;
    final packages = widget.packages;
    if (packages.status != PackagesStatus.ready) {
      if (packages.status != PackagesStatus.failed) return const SizedBox();
      return _Notice(
        text: l.pluginsLoadFailed,
        action: AppActionButton.subtle(
          label: l.appearanceRetry,
          onPressed: packages.load,
        ),
      );
    }
    final extensions = _extensions;
    final enabled = extensions.where((item) => item.enabled).toList();
    final busy = _installing || packages.busy;
    if (extensions.isEmpty) {
      return _Notice(
        text: l.providerNotInstalled,
        action: AppActionButton(
          label: l.providerInstallTitle,
          isLoading: busy,
          onPressed: busy ? null : _install,
        ),
      );
    }
    if (enabled.isEmpty) {
      final disabled = extensions.where((i) => i.isUserScope).firstOrNull;
      return _Notice(
        text: l.providerDisabled,
        action: disabled == null
            ? null
            : AppActionButton(
                label: l.providerEnable,
                isLoading: packages.isToggling(disabled),
                onPressed: packages.busy || packages.isToggling(disabled)
                    ? null
                    : () async {
                        setState(() => _installError = null);
                        await packages.toggle(disabled, true);
                        if (mounted) {
                          setState(() => _installError = packages.actionError);
                        }
                      },
              ),
      );
    }
    final old = enabled.firstWhere(
      (item) =>
          ProviderPluginInstaller.installedVersion(item.path) !=
          ProviderPluginInstaller.version,
      orElse: () => enabled.first,
    );
    final version = ProviderPluginInstaller.installedVersion(old.path);
    // Only bundled copies carry a version path; a hand-installed plugin is
    // the user's business.
    if (version == null ||
        version == ProviderPluginInstaller.version ||
        !old.isUserScope) {
      return const SizedBox();
    }
    return _Notice(
      text: l.providerOutdated(version, ProviderPluginInstaller.version),
      warning: true,
      action: AppActionButton(
        label: l.providerUpgradeTitle,
        isLoading: busy,
        onPressed: busy ? null : () => _install(outdated: old),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.packages, widget.profiles]),
      builder: (context, _) {
        final controller = widget.profiles;
        final state = controller.state;
        final query = widget.query.trim().toLowerCase();
        final profiles =
            state?.profiles
                .where(
                  (p) =>
                      query.isEmpty ||
                      '${p.name} ${p.baseUrl} ${p.api} ${p.models.map((m) => m.id).join(' ')}'
                          .toLowerCase()
                          .contains(query),
                )
                .toList() ??
            const <PiProviderProfile>[];
        final selected = controller.selectedProfile;
        final creating = state != null && controller.selected == null;
        final list = _ProfileList(
          profiles: profiles,
          selected: controller.selected,
          creating: creating,
          empty: state?.profiles.isEmpty == true,
          onSelect: _select,
          onAdd: state == null ? null : () => _select(null),
        );
        final detail = state == null
            ? AppCard(
                child: Text(
                  controller.error == null
                      ? l.pluginsBusyHint
                      : _providerErrorText(context, controller.error!),
                ),
              )
            : _ProfileEditor(
                key: ValueKey('${selected?.name ?? ''}#$_draftGeneration'),
                controller: controller,
                profile: selected,
                existingNames: {for (final p in state.profiles) p.name},
                onDirtyChanged: (dirty) => _dirty = dirty,
                onRemove: selected == null
                    ? null
                    : () async {
                        if (!await _confirm(
                          l.pluginsRemoveConfirmTitle,
                          l.providerRemoveWarning(selected.name),
                          l.pluginsRemove,
                        )) {
                          return;
                        }
                        _dirty = false;
                        await controller.remove(selected.name);
                      },
              );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _pluginNotice(context),
            if (_installError != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  _providerErrorText(context, _installError!),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 640) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      list,
                      const SizedBox(height: AppSpacing.md),
                      detail,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 220, child: list),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(child: detail),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, this.action, this.warning = false});
  final String text;
  final Widget? action;
  final bool warning;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
    child: AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      borderColor: warning ? context.colors.warning : null,
      child: Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Text(text, style: context.textTheme.bodyMedium),
          ),
          ?action,
        ],
      ),
    ),
  );
}

class _ProfileList extends StatelessWidget {
  const _ProfileList({
    required this.profiles,
    required this.selected,
    required this.creating,
    required this.empty,
    required this.onSelect,
    required this.onAdd,
  });
  final List<PiProviderProfile> profiles;
  final String? selected;
  final bool creating, empty;
  final ValueChanged<String?> onSelect;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in profiles)
            AppNavTile(
              title: p.name,
              subtitle: l.providerModelCount(p.enabledCount),
              height: 44,
              isSelected: !creating && p.name == selected,
              leading: const Icon(Icons.hub_outlined),
              onTap: () => onSelect(p.name),
            ),
          if (creating)
            AppNavTile(
              title: l.providerNewTitle,
              height: 44,
              isSelected: true,
              leading: const Icon(Icons.add_circle_outline_rounded),
              onTap: () {},
            ),
          if (profiles.isEmpty && !creating && !empty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Text(
                l.providerNoMatches,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.textMuted,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xs),
          AppActionButton.subtle(
            label: l.providerAdd,
            leading: const Icon(Icons.add_rounded),
            mainAxisAlignment: MainAxisAlignment.start,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({
    super.key,
    required this.controller,
    required this.profile,
    required this.existingNames,
    required this.onDirtyChanged,
    required this.onRemove,
  });
  final ProviderProfilesController controller;
  final PiProviderProfile? profile;
  final Set<String> existingNames;
  final ValueChanged<bool> onDirtyChanged;
  final VoidCallback? onRemove;
  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final _name = TextEditingController(text: widget.profile?.name);
  late final _url = TextEditingController(text: widget.profile?.baseUrl);
  final _key = TextEditingController();
  final _filter = TextEditingController();
  final _manualId = TextEditingController();
  late String _api = widget.profile?.api ?? _apis.first;
  late bool _sync = widget.profile?.syncModels ?? true;
  late List<PiProviderModel> _models = [...?widget.profile?.models];

  /// Ids from a listing made in this editor; saved to the plugin's cache.
  List<String>? _discovered;
  bool _saving = false, _fetching = false, _showKey = false, _clearKey = false;
  bool _dirty = false, _saved = false;
  String? _error, _nameError, _urlError;

  bool get _working => _saving || _fetching;
  bool get _isNew => widget.profile == null;

  @override
  void didUpdateWidget(_ProfileEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Fresh state after a save/reload: adopt it unless the user is editing.
    final next = widget.profile;
    if (next != null && next != oldWidget.profile && !_dirty && !_working) {
      _url.text = next.baseUrl;
      _api = next.api;
      _sync = next.syncModels;
      _models = [...next.models];
      _discovered = null;
      _clearKey = false;
      _key.clear();
    }
  }

  String _syncStatus(BuildContext context) {
    final l = context.l10n;
    if (_discovered != null) {
      return l.providerFetchedModels(_discovered!.length);
    }
    final at = widget.profile?.syncedAt;
    if (at == null) return l.providerNeverSynced;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return l.providerSyncedAt(DateFormat.yMd(locale).add_Hm().format(at));
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _key.dispose();
    _filter.dispose();
    _manualId.dispose();
    super.dispose();
  }

  void _touch([VoidCallback? change]) {
    setState(() {
      change?.call();
      _saved = false;
      if (!_dirty) {
        _dirty = true;
        widget.onDirtyChanged(true);
      }
    });
  }

  bool _validate({bool name = false}) {
    final text = _name.text.trim();
    final url = Uri.tryParse(_url.text.trim());
    setState(() {
      _error = null;
      _nameError = null;
      if (name) {
        if (!_namePattern.hasMatch(text) ||
            const ['__proto__', 'constructor', 'prototype'].contains(text)) {
          _nameError = 'PROFILE_NAME_INVALID';
        } else if (widget.existingNames.contains(text) &&
            text != widget.profile?.name) {
          _nameError = 'PROFILE_EXISTS';
        }
      }
      _urlError =
          url == null ||
              !const ['https', 'http'].contains(url.scheme) ||
              url.host.isEmpty ||
              url.userInfo.isNotEmpty ||
              url.hasQuery ||
              url.hasFragment
          ? 'PROFILE_INVALID'
          : null;
    });
    return _nameError == null && _urlError == null;
  }

  /// Lists models; new ids join enabled, previously hidden ids stay hidden,
  /// manual ids are kept.
  Future<bool> _fetch() async {
    if (!_validate()) return false;
    setState(() => _fetching = true);
    try {
      final result = await widget.controller.fetchModels(
        name: widget.profile?.name,
        baseUrl: _url.text.trim(),
        api: _api,
        apiKey: _key.text.trim(),
        clearApiKey: _clearKey,
      );
      if (!mounted) return false;
      _touch(() {
        final previous = {for (final m in _models) m.id: m};
        final ids = {for (final m in result.models) m.id};
        _models = [
          for (final m in result.models)
            m.copyWith(
              enabled: previous[m.id]?.enabled ?? true,
              manual: previous[m.id]?.manual ?? false,
              discovered: true,
            ),
          for (final m in _models)
            if (!ids.contains(m.id) && m.manual) m,
        ];
        _discovered = [for (final m in result.models) m.id];
        _url.text = result.baseUrl;
        _sync = true;
      });
      return true;
    } catch (e) {
      if (mounted) {
        setState(() => _error = ProviderProfilesController.errorCode(e));
      }
      return false;
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  Future<void> _save() async {
    if (_working || !_validate(name: true)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    // A new profile without any model tries one listing first, so filling in
    // the endpoint and key is enough.
    if (_models.isEmpty && _sync && !await _fetch()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    // Editing the name of a saved profile renames it: the backend moves the
    // entry and its discovered cache to the new name in one write, and the
    // plugin hot-swaps the provider registration in running sessions.
    final name = _name.text.trim();
    final renamed = !_isNew && name != widget.profile!.name;
    final ok = await widget.controller.save(
      name: name,
      baseUrl: _url.text.trim(),
      api: _api,
      syncModels: _sync,
      models: _models,
      discovered: _discovered,
      apiKey: _key.text.trim(),
      clearApiKey: _clearKey,
      createOnly: _isNew,
      renameFrom: renamed ? widget.profile!.name : null,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? null : widget.controller.error;
      _saved = ok;
      if (ok) {
        _dirty = false;
        widget.onDirtyChanged(false);
      }
    });
  }

  void _addManual() {
    final id = _manualId.text.trim();
    if (id.isEmpty || id.length > 200) return;
    _touch(() {
      final index = _models.indexWhere((m) => m.id == id);
      if (index >= 0) {
        _models[index] = _models[index].copyWith(enabled: true);
      } else {
        _models = [..._models, PiProviderModel(id: id, manual: true)];
      }
      _manualId.clear();
    });
  }

  void _setAll(bool enabled) => _touch(() {
    final query = _filter.text.trim().toLowerCase();
    _models = [
      for (final m in _models)
        query.isEmpty || m.id.toLowerCase().contains(query)
            ? m.copyWith(enabled: enabled)
            : m,
    ];
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final profile = widget.profile;
    final query = _filter.text.trim().toLowerCase();
    final visible = _models
        .where((m) => query.isEmpty || m.id.toLowerCase().contains(query))
        .toList();
    final enabled = _models.where((m) => m.enabled).length;
    final muted = context.textTheme.bodySmall?.copyWith(
      color: colors.textSecondary,
    );
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Always a full-height, editable name field. Changing the name of
          // a saved profile renames it on save; the plugin re-registers the
          // provider in every running session, so no restart is needed.
          AppTextField(
            controller: _name,
            labelText: l.providerNameLabel,
            hintText: _isNew ? l.providerName : null,
            errorText: _nameError == null
                ? null
                : _providerErrorText(context, _nameError!),
            autofocus: _isNew,
            enabled: !_working,
            onChanged: (_) => _touch(),
            trailing: widget.onRemove == null || _isNew
                ? null
                : AppIconButton.subtle(
                    icon: Icons.delete_outline_rounded,
                    tooltip: l.providerRemove,
                    onPressed: _working || widget.controller.busy
                        ? null
                        : widget.onRemove,
                  ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _url,
            labelText: l.providerBaseUrlLabel,
            hintText: l.providerBaseUrl,
            errorText: _urlError == null
                ? null
                : _providerErrorText(context, _urlError!),
            enabled: !_working,
            onChanged: (_) => _touch(),
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            controller: _key,
            labelText: l.providerKeyLabel,
            hintText: profile?.hasApiKey == true && !_clearKey
                ? l.providerKeepKey
                : l.providerKey,
            enabled: !_working && !_clearKey,
            obscureText: !_showKey,
            onChanged: (_) => _touch(),
            trailing: AppIconButton.subtle(
              icon: _showKey
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              tooltip: _showKey ? l.providerHideKey : l.providerShowKey,
              onPressed: _working || _clearKey
                  ? null
                  : () => setState(() => _showKey = !_showKey),
            ),
          ),
          AppSettingRow(
            title: l.providerApi,
            control: AppSelect<String>(
              value: _api,
              label: l.providerApi,
              options: [for (final a in _apis) AppSelectOption(a, a)],
              onChanged: _working ? null : (v) => _touch(() => _api = v),
            ),
          ),
          if (profile?.hasApiKey == true)
            AppSettingRow(
              title: l.providerSavedKey,
              control: AppSelect<bool>(
                value: _clearKey,
                label: l.providerSavedKey,
                options: [
                  AppSelectOption(false, l.providerRetainKey),
                  AppSelectOption(true, l.providerClearKey),
                ],
                onChanged: _working
                    ? null
                    : (v) => _touch(() {
                        _clearKey = v;
                        if (v) _key.clear();
                      }),
              ),
            ),
          AppSettingRow(
            title: l.providerSync,
            control: AppSelect<bool>(
              value: _sync,
              label: l.providerSync,
              options: [
                AppSelectOption(true, l.appearanceOn),
                AppSelectOption(false, l.appearanceOff),
              ],
              onChanged: _working ? null : (v) => _touch(() => _sync = v),
            ),
          ),
          const Divider(),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.providerModelsTitle,
                      style: context.textTheme.titleSmall,
                    ),
                    Text(
                      '${l.providerModelsSummary(enabled, _models.length)} · ${_syncStatus(context)}',
                      style: muted,
                    ),
                  ],
                ),
              ),
              AppActionButton.subtle(
                label: l.providerFetchModels,
                leading: const Icon(Icons.cloud_download_outlined),
                isLoading: _fetching,
                onPressed: _working ? null : _fetch,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_models.length > 8)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _filter,
                      labelText: l.providerFilterModels,
                      leading: const Icon(Icons.search),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  AppActionButton.subtle(
                    label: l.providerEnableAll,
                    onPressed: _working ? null : () => _setAll(true),
                  ),
                  AppActionButton.subtle(
                    label: l.providerDisableAll,
                    onPressed: _working ? null : () => _setAll(false),
                  ),
                ],
              ),
            ),
          if (_models.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(l.providerNoModels, style: muted),
            )
          else if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Text(l.providerNoModelMatches, style: muted),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: visible.length,
                itemBuilder: (context, index) => _ModelRow(
                  model: visible[index],
                  enabled: !_working,
                  onToggle: (value) => _touch(() {
                    final i = _models.indexWhere(
                      (m) => m.id == visible[index].id,
                    );
                    _models[i] = _models[i].copyWith(enabled: value);
                  }),
                  onRemove: visible[index].manual && !visible[index].discovered
                      ? () => _touch(
                          () => _models.removeWhere(
                            (m) => m.id == visible[index].id,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _manualId,
                  labelText: l.providerAddModelHint,
                  enabled: !_working,
                  onSubmitted: (_) => _addManual(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AppActionButton.subtle(
                label: l.providerAddModel,
                leading: const Icon(Icons.add_rounded),
                onPressed: _working ? null : _addManual,
              ),
            ],
          ),
          if (_error != null || _saved) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              liveRegion: true,
              child: Text(
                _error != null
                    ? _providerErrorText(context, _error!)
                    : l.providerSaved,
                style: context.textTheme.bodySmall?.copyWith(
                  color: _error != null ? colors.warning : colors.success,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_dirty && !_isNew)
                AppActionButton.subtle(
                  label: l.providerDiscard,
                  onPressed: _working
                      ? null
                      : () => setState(() {
                          _name.text = profile?.name ?? '';
                          _url.text = profile?.baseUrl ?? '';
                          _key.clear();
                          _api = profile?.api ?? _apis.first;
                          _sync = profile?.syncModels ?? true;
                          _models = [...?profile?.models];
                          _discovered = null;
                          _clearKey = false;
                          _error = _nameError = _urlError = null;
                          _dirty = false;
                          widget.onDirtyChanged(false);
                        }),
                ),
              const SizedBox(width: AppSpacing.sm),
              AppActionButton(
                label: l.providerSave,
                isLoading: _saving,
                onPressed: _working || (!_dirty && !_isNew) ? null : _save,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact 36px model row: visibility toggle, id, capability badges.
class _ModelRow extends StatelessWidget {
  const _ModelRow({
    required this.model,
    required this.enabled,
    required this.onToggle,
    this.onRemove,
  });
  final PiProviderModel model;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onRemove;

  String? _context(BuildContext context) {
    final window = model.contextWindow;
    if (window == null || window <= 0) return null;
    final l = context.l10n;
    if (window >= 1000000) {
      // 1048576 → "1M", 1500000 → "1.5M".
      final m = (window / 100000).round() / 10;
      return l.providerContextM(
        m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toStringAsFixed(1),
      );
    }
    return l.providerContextK((window / 1000).round().toString());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final contextLabel = _context(context);
    return AppNavTile(
      title: model.id,
      height: 36,
      foregroundColor: model.enabled ? null : colors.textMuted,
      onTap: enabled ? () => onToggle(!model.enabled) : null,
      leading: Tooltip(
        message: model.enabled ? l.providerHideModel : l.providerShowModel,
        child: Icon(
          model.enabled
              ? Icons.check_box_rounded
              : Icons.check_box_outline_blank_rounded,
          color: model.enabled ? colors.primary : colors.textMuted,
        ),
      ),
      trailing: Wrap(
        spacing: AppSpacing.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (model.reasoning)
            AppBadge(
              label: l.providerReasoningBadge,
              variant: AppBadgeVariant.primary,
            ),
          if (model.image)
            AppBadge(
              label: l.providerImageBadge,
              variant: AppBadgeVariant.success,
            ),
          if (contextLabel != null) AppBadge(label: contextLabel),
          if (model.custom) AppBadge(label: l.providerCustomBadge),
          if (model.manual) AppBadge(label: l.providerManualBadge),
          if (onRemove != null)
            AppIconButton.subtle(
              icon: Icons.close_rounded,
              size: 24,
              tooltip: l.providerRemoveModel,
              onPressed: enabled ? onRemove : null,
            ),
        ],
      ),
    );
  }
}
