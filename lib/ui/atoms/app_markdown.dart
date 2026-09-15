import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import '../core/chat_resource_scope.dart';
import 'app_image.dart';
import 'app_code_block.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_context_extensions.dart';

/// Shared GFM renderer. Local/embedded images preview inline; remote images are opt-in.
class AppMarkdown extends StatelessWidget {
  const AppMarkdown({super.key, required this.data});
  final String data;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = context.textTheme;
    return SelectionArea(
      child: MarkdownBody(
        data: data,
        fitContent: false,
        extensionSet: md.ExtensionSet.gitHubFlavored,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: text.bodyLarge,
          h1: text.headlineMedium,
          h2: text.headlineSmall,
          h3: text.titleLarge,
          h4: text.titleMedium,
          h5: text.titleSmall,
          h6: text.titleSmall,
          code: AppTheme.codeStyle(
            Theme.of(context),
          ).copyWith(backgroundColor: colors.codeBackground),
          a: text.bodyLarge?.copyWith(
            color: colors.primary,
            decoration: TextDecoration.underline,
          ),
          blockquote: text.bodyLarge?.copyWith(color: colors.textSecondary),
          blockquoteDecoration: BoxDecoration(
            color: colors.mutedBackground.withValues(alpha: 0.5),
            border: Border(
              left: BorderSide(color: colors.borderFocus, width: 2),
            ),
          ),
          blockSpacing: AppSpacing.md,
          codeblockPadding: EdgeInsets.zero,
          codeblockDecoration: const BoxDecoration(),
          tableHead: text.labelLarge,
          tableBody: text.bodyMedium,
          tableBorder: TableBorder.all(color: colors.borderDefault),
          horizontalRuleDecoration: BoxDecoration(
            border: Border(top: BorderSide(color: colors.borderDefault)),
          ),
        ),
        builders: {'pre': _CodeBuilder()},
        checkboxBuilder: (checked) => Semantics(
          checked: checked,
          child: Icon(
            checked ? Icons.check_box : Icons.check_box_outline_blank,
            size: 16,
            color: checked ? colors.primary : colors.textMuted,
          ),
        ),
        imageBuilder: (uri, title, alt) => AppImage(
          key: ValueKey(uri.toString()),
          source: uri.toString(),
          label: alt == null || alt.isEmpty ? null : alt,
        ),
        onTapLink: (_, href, _) => ChatResourceScope.open(context, href ?? ''),
      ),
    );
  }
}

class _CodeBuilder extends MarkdownElementBuilder {
  @override
  bool isBlockElement() => true;
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    final code = element.children?.whereType<md.Element>().firstOrNull;
    final language = code?.attributes['class']?.replaceFirst('language-', '');
    final source = element.textContent.replaceFirst(RegExp(r'\n$'), '');
    return AppCodeBlock(
      code: source,
      label: language == null || language.isEmpty ? null : language,
      language: language,
    );
  }
}
