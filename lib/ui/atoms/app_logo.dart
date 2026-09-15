import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../core/context_l10n.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';

/// Trusted bundled brand artwork, separate from user-provided chat images.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = AppSpacing.xxxl});

  final double size;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    'assets/images/pi_logo.svg',
    width: size,
    height: size,
    fit: BoxFit.contain,
    colorFilter: ColorFilter.mode(context.colors.textPrimary, BlendMode.srcIn),
    semanticsLabel: context.l10n.appName,
  );
}
