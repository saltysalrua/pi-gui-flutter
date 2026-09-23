import 'package:flutter/material.dart';
import 'package:pi_gui/core/rpc/pi_packages_types.dart';
import 'package:pi_gui/core/rpc/pi_provider_profiles_types.dart';
import 'package:pi_gui/core/services/provider_plugin_installer.dart';
import 'package:pi_gui/ui/atoms/app_action_button.dart';
import 'package:pi_gui/ui/atoms/app_badge.dart';
import 'package:pi_gui/ui/atoms/app_card.dart';
import 'package:pi_gui/ui/atoms/app_dialog.dart';
import 'package:pi_gui/ui/atoms/app_icon_button.dart';
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
    'PROFILE_ACTIVATE_FAILED' => l.providerErrorActivate,
    'PROFILE_SESSION_BUSY' => l.providerErrorBusy,
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

  Future<void> _install() async {
    if (_installing || widget.packages.busy) return;
    final l = context.l10n;
    final approved = await showAppDialog<bool>(
      context,
      (context) => AppDialog(
        title: l.providerInstallTitle,
        actions: [
          AppActionButton.subtle(
            label: l.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          AppActionButton(
            label: l.pluginsInstall,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
        child: Text(l.providerInstallWarning),
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _installing = true;
      _installError = null;
    });
    try {
      final source = await ProviderPluginInstaller.prepareSource();
      if (!mounted) return;
      final ok = await widget.packages.installSource(source);
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    return ListenableBuilder(
      listenable: Listenable.merge([widget.packages, widget.profiles]),
      builder: (context, _) {
        final state = widget.profiles.state;
        final extensions = _extensions;
        final enabled = extensions.any((item) => item.enabled);
        final disabled = extensions
            .where((item) => !item.enabled && item.isUserScope)
            .firstOrNull;
        final query = widget.query.trim().toLowerCase();
        final profiles =
            state?.profiles
                .where(
                  (p) => '${p.name} ${p.baseUrl} ${p.api} ${p.models.join(' ')}'
                      .toLowerCase()
                      .contains(query),
                )
                .toList() ??
            const <PiProviderProfile>[];
        final error = _installError ?? widget.profiles.error;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.providerTitle, style: context.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.providerDescription,
              style: context.textTheme.bodyMedium?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (widget.packages.status != PackagesStatus.ready)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.packages.status == PackagesStatus.failed
                          ? l.pluginsLoadFailed
                          : l.pluginsBusyHint,
                    ),
                    if (widget.packages.status == PackagesStatus.failed)
                      AppActionButton.subtle(
                        label: l.appearanceRetry,
                        onPressed: widget.packages.load,
                      ),
                  ],
                ),
              )
            else if (!enabled)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      extensions.isEmpty
                          ? l.providerNotInstalled
                          : l.providerDisabled,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    if (extensions.isEmpty)
                      AppActionButton(
                        label: l.providerInstallTitle,
                        isLoading: _installing || widget.packages.busy,
                        onPressed: _installing || widget.packages.busy
                            ? null
                            : _install,
                      )
                    else if (disabled != null)
                      AppActionButton(
                        label: l.providerEnable,
                        isLoading: widget.packages.isToggling(disabled),
                        onPressed:
                            widget.packages.busy ||
                                widget.packages.isToggling(disabled)
                            ? null
                            : () async {
                                setState(() => _installError = null);
                                await widget.packages.toggle(disabled, true);
                                if (mounted) {
                                  setState(
                                    () => _installError =
                                        widget.packages.actionError,
                                  );
                                }
                              },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(l.providerActive(state?.active ?? l.providerNone)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                AppActionButton(
                  label: l.providerAdd,
                  leading: const Icon(Icons.add_rounded),
                  onPressed: widget.profiles.busy || state == null
                      ? null
                      : () => _edit(null),
                ),
                AppActionButton.subtle(
                  label: l.modelRefresh,
                  leading: const Icon(Icons.refresh_rounded),
                  isLoading: widget.profiles.busy && state == null,
                  onPressed: widget.profiles.busy ? null : widget.profiles.load,
                ),
              ],
            ),
            if (widget.profiles.switchedCurrentSession != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.profiles.switchedCurrentSession == true
                    ? l.providerSwitched(widget.profiles.lastActivated!)
                    : l.providerNextSession,
                style: context.textTheme.bodySmall?.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
            if (error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Semantics(
                liveRegion: true,
                child: Text(
                  _providerErrorText(context, error),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                  ),
                ),
              ),
            ],
            if (state != null && profiles.isEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              AppCard(
                child: Text(
                  state.profiles.isEmpty
                      ? l.providerEmpty
                      : l.providerNoMatches,
                ),
              ),
            ],
            for (final profile in profiles) ...[
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            profile.name,
                            style: context.textTheme.titleMedium,
                          ),
                        ),
                        if (state?.active == profile.name)
                          AppBadge(label: l.providerSelected),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      profile.baseUrl,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppBadge(label: profile.api),
                        AppBadge(
                          label: l.providerModelCount(profile.models.length),
                        ),
                        if (profile.hasApiKey)
                          AppBadge(label: l.providerHasKey),
                        if (profile.reasoning)
                          AppBadge(label: l.providerThinkingBadge),
                      ],
                    ),
                    if (profile.defaultModel != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l.providerDefaultModelValue(profile.defaultModel!),
                        style: context.textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        AppActionButton.subtle(
                          label: l.providerActivate,
                          isLoading:
                              widget.profiles.busy &&
                              widget.profiles.lastActivated == profile.name,
                          onPressed: widget.profiles.busy || !enabled
                              ? null
                              : () => widget.profiles.activate(profile.name),
                        ),
                        AppActionButton.subtle(
                          label: l.providerEdit,
                          onPressed: widget.profiles.busy
                              ? null
                              : () => _edit(profile),
                        ),
                        AppActionButton.subtle(
                          label: l.pluginsRemove,
                          onPressed: widget.profiles.busy
                              ? null
                              : () => _remove(profile.name),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Future<void> _edit(PiProviderProfile? profile) async {
    widget.profiles.clearMessages();
    await showAppDialog<void>(
      context,
      (_) => _ProviderEditor(controller: widget.profiles, profile: profile),
    );
  }

  Future<void> _remove(String name) async {
    final l = context.l10n;
    final ok = await showAppDialog<bool>(
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
        child: Text(l.providerRemoveWarning(name)),
      ),
    );
    if (ok == true && mounted) {
      widget.profiles.clearMessages();
      await widget.profiles.remove(name);
    }
  }
}

class _ProviderEditor extends StatefulWidget {
  const _ProviderEditor({required this.controller, this.profile});
  final ProviderProfilesController controller;
  final PiProviderProfile? profile;
  @override
  State<_ProviderEditor> createState() => _ProviderEditorState();
}

class _ProviderEditorState extends State<_ProviderEditor> {
  late final _name = TextEditingController(text: widget.profile?.name);
  late final _url = TextEditingController(text: widget.profile?.baseUrl);
  final _key = TextEditingController();
  late final _models = TextEditingController(
    text: widget.profile?.models.join('\n'),
  );
  late String _api = widget.profile?.api ?? 'openai-responses';
  late bool _reasoning = widget.profile?.reasoning ?? false;
  late String? _default = widget.profile?.defaultModel;
  bool _saving = false, _fetching = false, _showKey = false, _clearKey = false;
  String? _error, _nameError, _urlError;
  int? _fetchedCount;
  bool get _working => _saving || _fetching;

  List<String> get _ids => _models.text
      .split(RegExp(r'[,\r\n]+'))
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toSet()
      .toList();

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    _key.dispose();
    _models.dispose();
    super.dispose();
  }

  bool _validate({bool includeName = false}) {
    final name = _name.text.trim();
    final url = Uri.tryParse(_url.text.trim());
    setState(() {
      _error = null;
      _nameError =
          includeName &&
              (!RegExp(r'^[a-zA-Z0-9][a-zA-Z0-9._-]{0,63}$').hasMatch(name) ||
                  const [
                    '__proto__',
                    'constructor',
                    'prototype',
                  ].contains(name))
          ? 'PROFILE_NAME_INVALID'
          : null;
      if (includeName &&
          widget.profile == null &&
          widget.controller.state?.profiles.any((p) => p.name == name) ==
              true) {
        _nameError = 'PROFILE_EXISTS';
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

  Future<bool> _fetch() async {
    if (!_validate()) return false;
    setState(() {
      _fetching = true;
      _fetchedCount = null;
    });
    try {
      final result = await widget.controller.fetchModels(
        name: widget.profile?.name,
        baseUrl: _url.text.trim(),
        api: _api,
        apiKey: _key.text.trim(),
        clearApiKey: _clearKey,
      );
      if (!mounted) return false;
      setState(() {
        // Refresh must not erase manually configured IDs or the default.
        final ids = {..._ids, ...result.models}.toList();
        _models.text = ids.join('\n');
        _url.text = result.baseUrl;
        if (!ids.contains(_default)) _default = ids.firstOrNull;
        _fetchedCount = result.models.length;
      });
      return result.models.isNotEmpty;
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
    if (_working || !_validate(includeName: true)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    // No placeholder model ID is required. Fetch before the first write, so a
    // failed listing leaves both the draft and the on-disk profile untouched.
    if (_ids.isEmpty && !await _fetch()) {
      if (mounted) setState(() => _saving = false);
      return;
    }
    if (!mounted) return;
    final ids = _ids;
    final ok = await widget.controller.save(
      name: _name.text.trim(),
      baseUrl: _url.text.trim(),
      api: _api,
      reasoning: _reasoning,
      models: ids,
      defaultModel: ids.contains(_default) ? _default! : ids.first,
      apiKey: _key.text.trim(),
      clearApiKey: _clearKey,
      createOnly: widget.profile == null,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = ok ? null : widget.controller.error;
    });
    if (ok) {
      // Let PopScope rebuild before closing a successfully saved form.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final colors = context.colors;
    final ids = _ids;
    return PopScope(
      canPop: !_working,
      child: AppDialog(
        title: widget.profile == null ? l.providerAdd : l.providerEdit,
        maxWidth: 560,
        actions: [
          AppActionButton.subtle(
            label: l.cancel,
            onPressed: _working ? null : () => Navigator.pop(context),
          ),
          AppActionButton(
            label: l.providerSave,
            isLoading: _saving,
            onPressed: _working ? null : _save,
          ),
        ],
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTextField(
              controller: _name,
              labelText: l.providerNameLabel,
              hintText: l.providerName,
              errorText: _nameError == null
                  ? null
                  : _providerErrorText(context, _nameError!),
              autofocus: widget.profile == null,
              enabled: !_working && widget.profile == null,
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
              onChanged: (_) => setState(() => _fetchedCount = null),
            ),
            AppSettingRow(
              title: l.providerApi,
              control: AppSelect<String>(
                value: _api,
                label: l.providerApi,
                options: const [
                  AppSelectOption('openai-responses', 'openai-responses'),
                  AppSelectOption('openai-completions', 'openai-completions'),
                  AppSelectOption('anthropic-messages', 'anthropic-messages'),
                  AppSelectOption(
                    'google-generative-ai',
                    'google-generative-ai',
                  ),
                ],
                onChanged: _working
                    ? null
                    : (v) => setState(() {
                        _api = v;
                        _fetchedCount = null;
                      }),
              ),
            ),
            AppTextField(
              controller: _key,
              labelText: l.providerKeyLabel,
              hintText: widget.profile?.hasApiKey == true && !_clearKey
                  ? l.providerKeepKey
                  : l.providerKey,
              enabled: !_working && !_clearKey,
              obscureText: !_showKey,
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
            const SizedBox(height: AppSpacing.xs),
            Text(
              l.providerKeyHint,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            if (widget.profile?.hasApiKey == true)
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
                      : (v) => setState(() {
                          _clearKey = v;
                          if (v) _key.clear();
                        }),
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.centerLeft,
              child: AppActionButton.subtle(
                label: l.providerFetchModels,
                leading: const Icon(Icons.cloud_download_outlined),
                isLoading: _fetching,
                onPressed: _working ? null : _fetch,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l.providerModels,
              style: context.textTheme.bodySmall?.copyWith(
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              controller: _models,
              labelText: l.providerModelsLabel,
              hintText: l.providerManualModels,
              maxLines: 4,
              minLines: 2,
              enabled: !_working,
              onChanged: (_) => setState(() => _fetchedCount = null),
            ),
            if (_fetchedCount != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Semantics(
                liveRegion: true,
                child: Text(
                  l.providerFetchedModels(_fetchedCount!),
                  style: context.textTheme.bodySmall,
                ),
              ),
            ],
            if (ids.isNotEmpty)
              AppSettingRow(
                title: l.providerDefaultModel,
                control: AppSelect<String>(
                  value: ids.contains(_default) ? _default! : ids.first,
                  label: l.providerDefaultModel,
                  options: ids.map((id) => AppSelectOption(id, id)).toList(),
                  onChanged: _working
                      ? null
                      : (id) => setState(() => _default = id),
                ),
              ),
            AppSettingRow(
              title: l.providerThinking,
              control: AppSelect<bool>(
                value: _reasoning,
                label: l.providerThinking,
                options: [
                  AppSelectOption(false, l.pluginsToggleOff),
                  AppSelectOption(true, l.pluginsToggleOn),
                ],
                onChanged: _working
                    ? null
                    : (v) => setState(() => _reasoning = v),
              ),
            ),
            if (_saving && _fetching)
              Text(
                l.providerFetchingOnSave,
                style: context.textTheme.bodySmall,
              ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _providerErrorText(context, _error!),
                  style: context.textTheme.bodySmall?.copyWith(
                    color: colors.warning,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
