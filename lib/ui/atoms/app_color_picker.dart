import 'package:flutter/material.dart';
import '../../core/models/appearance_preferences.dart';
import 'app_action_button.dart';
import 'app_dialog.dart';
import 'app_text_field.dart';
import '../core/context_l10n.dart';
import '../core/theme/appearance_palette.dart';
import '../core/theme/app_tokens.dart';
import '../core/theme/theme_context_extensions.dart';

class AppColorSwatch extends StatelessWidget {
  const AppColorSwatch({super.key, required this.color, this.size = 22});
  final Color color;
  final double size;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: context.colors.borderHover),
      ),
    ),
  );
}

class AppColorButton extends StatelessWidget {
  const AppColorButton({
    super.key,
    required this.color,
    required this.onPressed,
    this.label,
  });
  final Color color;
  final VoidCallback? onPressed;
  final String? label;
  @override
  Widget build(BuildContext context) => AppActionButton(
    label: label ?? formatHexRgb(color.toARGB32()),
    leading: AppColorSwatch(color: color),
    variant: AppButtonVariant.secondary,
    onPressed: onPressed,
  );
}

/// Local draft with explicit apply/cancel; invalid HEX never changes the theme.
Future<Color?> showAppColorPicker(
  BuildContext context, {
  required Color initial,
  required String title,
  Color? contrastAgainst,
}) => showAppDialog<Color>(
  context,
  (_) => _ColorDialog(
    initial: initial,
    title: title,
    contrastAgainst: contrastAgainst,
  ),
);

class _ColorDialog extends StatefulWidget {
  const _ColorDialog({
    required this.initial,
    required this.title,
    this.contrastAgainst,
  });
  final Color initial;
  final String title;
  final Color? contrastAgainst;
  @override
  State<_ColorDialog> createState() => _ColorDialogState();
}

class _ColorDialogState extends State<_ColorDialog> {
  late HSVColor _hsv;
  late final TextEditingController _hex;
  bool _valid = true;
  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial.withValues(alpha: 1));
    _hex = TextEditingController(text: formatHexRgb(widget.initial.toARGB32()));
  }

  @override
  void dispose() {
    _hex.dispose();
    super.dispose();
  }

  void _change(HSVColor next) => setState(() {
    _hsv = next;
    _valid = true;
    _hex.text = formatHexRgb(next.toColor().toARGB32());
  });
  void _apply() {
    if (_valid) Navigator.of(context).pop(_hsv.toColor());
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final color = _hsv.toColor();
    final lowContrast =
        widget.contrastAgainst != null &&
        AppearancePalette.contrast(color, widget.contrastAgainst!) < 4.5;
    Widget slider(
      String label,
      double value,
      double max,
      ValueChanged<double> change,
    ) => Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(label, style: context.textTheme.bodySmall),
        ),
        Expanded(
          child: Semantics(
            label: label,
            child: Slider(
              value: value,
              max: max,
              semanticFormatterCallback: (v) => '${v.round()}',
              onChanged: change,
            ),
          ),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '${value.round()}',
            style: context.textTheme.labelSmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
    return AppDialog(
      title: widget.title,
      maxWidth: 460,
      actions: [
        AppActionButton.subtle(
          label: l.cancel,
          onPressed: () => Navigator.of(context).pop(),
        ),
        AppActionButton(
          label: l.appearanceApply,
          onPressed: _valid ? _apply : null,
        ),
      ],
      child: AnimatedSize(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : AppDurations.fast,
        curve: AppCurves.smoothOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const height = 150.0;
                  void position(Offset p) => _change(
                    _hsv
                        .withSaturation(
                          (p.dx / constraints.maxWidth).clamp(0, 1),
                        )
                        .withValue((1 - p.dy / height).clamp(0, 1)),
                  );
                  return GestureDetector(
                    onTapDown: (d) => position(d.localPosition),
                    onPanStart: (d) => position(d.localPosition),
                    onPanUpdate: (d) => position(d.localPosition),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.precise,
                      child: CustomPaint(
                        size: Size(constraints.maxWidth, height),
                        painter: _SaturationValuePainter(
                          _hsv,
                          context.colors.borderFocus,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                AppColorSwatch(color: color, size: 36),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppTextField(
                    controller: _hex,
                    hintText: l.appearanceHex,
                    onChanged: (text) => setState(() {
                      final parsed = parseHexRgb(text);
                      _valid = parsed != null;
                      if (parsed != null) {
                        _hsv = HSVColor.fromColor(Color(parsed));
                      }
                    }),
                    onSubmitted: (_) => _apply(),
                  ),
                ),
              ],
            ),
            if (!_valid) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l.appearanceHexInvalid,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.error,
                ),
              ),
            ],
            slider(
              l.appearanceHue,
              _hsv.hue,
              360,
              (v) => _change(_hsv.withHue(v)),
            ),
            slider(
              l.appearanceSaturation,
              _hsv.saturation * 100,
              100,
              (v) => _change(_hsv.withSaturation(v / 100)),
            ),
            slider(
              l.appearanceValue,
              _hsv.value * 100,
              100,
              (v) => _change(_hsv.withValue(v / 100)),
            ),
            if (lowContrast)
              Text(
                l.appearanceContrastWarning,
                style: context.textTheme.bodySmall?.copyWith(
                  color: context.colors.warning,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Colors here represent the HSV color space, not hard-coded application styles.
class _SaturationValuePainter extends CustomPainter {
  _SaturationValuePainter(this.hsv, this.focus);
  final HSVColor hsv;
  final Color focus;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final white = hsv.withSaturation(0).withValue(1).toColor();
    final black = hsv.withValue(0).toColor();
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          colors: [white, hsv.withSaturation(1).withValue(1).toColor()],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [black.withValues(alpha: 0), black],
        ).createShader(rect),
    );
    final point = Offset(
      hsv.saturation * size.width,
      (1 - hsv.value) * size.height,
    );
    canvas.drawCircle(
      point,
      6,
      Paint()
        ..color = focus
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    canvas.drawCircle(
      point,
      5,
      Paint()
        ..color = AppearancePalette.onColor(hsv.toColor())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SaturationValuePainter old) =>
      old.hsv != hsv || old.focus != focus;
}
