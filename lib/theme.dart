import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum Look { amoled, editorial, glass }

extension LookX on Look {
  String get label => const ['AMOLED', 'Editorial', 'Glass'][index];
  String get font => const ['Space Grotesk', 'Fraunces', 'Outfit'][index];
}

/// Colours + look, carried on ThemeData so a theme switch cross-fades for free.
class Skin extends ThemeExtension<Skin> {
  const Skin(this.look, this.bg, this.surface, this.ink, this.line, this.dark);

  final Look look;
  final Color bg, surface, ink, line;
  final bool dark;

  Color get mute => ink.withValues(alpha: .55);

  factory Skin.of(Look look, bool editorialDark) => switch (look) {
        Look.amoled => const Skin(Look.amoled, Color(0xFF000000), Color(0xFF0D0D11),
            Color(0xFFF4F4F6), Color(0x14FFFFFF), true),
        Look.glass => const Skin(Look.glass, Color(0xFF0B0B1E), Color(0x1FFFFFFF),
            Color(0xFFF6F5FF), Color(0x2EFFFFFF), true),
        Look.editorial => editorialDark
            ? const Skin(Look.editorial, Color(0xFF1B1A17), Color(0xFF252420),
                Color(0xFFEFE9DC), Color(0x1FEFE9DC), true)
            : const Skin(Look.editorial, Color(0xFFF4EFE6), Color(0xFFFBF8F2),
                Color(0xFF1B1A17), Color(0x1F1B1A17), false),
      };

  TextStyle disp(double size, {FontWeight w = FontWeight.w600, Color? color, double? ls, double? h}) =>
      GoogleFonts.getFont(look.font,
          fontSize: size, fontWeight: w, color: color ?? ink, letterSpacing: ls ?? (size > 20 ? -size * .02 : 0), height: h);

  TextStyle body(double size, {FontWeight w = FontWeight.w400, Color? color}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: w, color: color ?? ink);

  @override
  Skin copyWith() => this;

  @override
  Skin lerp(Skin? o, double t) => o == null
      ? this
      : Skin(t < .5 ? look : o.look, Color.lerp(bg, o.bg, t)!, Color.lerp(surface, o.surface, t)!,
          Color.lerp(ink, o.ink, t)!, Color.lerp(line, o.line, t)!, t < .5 ? dark : o.dark);
}

extension SkinCtx on BuildContext {
  Skin get skin => Theme.of(this).extension<Skin>()!;
}

ThemeData buildTheme(Skin s, Color accent) => ThemeData(
      useMaterial3: true,
      brightness: s.dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.fromSeed(
          seedColor: accent, brightness: s.dark ? Brightness.dark : Brightness.light, surface: s.bg)
          .copyWith(primary: accent, onSurface: s.ink),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: [s],
    );

/// Animation helper: honours the OS "remove animations" setting.
Duration dur(BuildContext c, int ms) => MediaQuery.of(c).disableAnimations ? Duration.zero : Duration(milliseconds: ms);

const easeOut = Cubic(.23, 1, .32, 1);
const easeInOut = Cubic(.77, 0, .175, 1);

/// Full-screen backdrop: gradient / custom image + a soft accent glow.
class Backdrop extends StatelessWidget {
  const Backdrop({super.key, required this.accent, this.imagePath, this.dim = .5});

  final Color accent;
  final String? imagePath;
  final double dim;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    return Stack(fit: StackFit.expand, children: [
      ColoredBox(color: s.bg),
      if (s.look == Look.glass)
        const DecoratedBox(
            decoration: BoxDecoration(
                gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2A1B5E), Color(0xFF0B0B1E), Color(0xFF0E3A4D)]))),
      AnimatedSwitcher(
        duration: dur(context, 500),
        child: imagePath == null
            ? const SizedBox.expand(key: ValueKey('none'))
            : Stack(key: ValueKey(imagePath), fit: StackFit.expand, children: [
                Image.file(File(imagePath!), fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                ColoredBox(color: s.bg.withValues(alpha: dim)),
              ]),
      ),
      // accent glow follows the active section
      IgnorePointer(
        child: TweenAnimationBuilder<Color?>(
          tween: ColorTween(end: accent),
          duration: dur(context, 600),
          builder: (_, c, _) => DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(.9, -1.0),
                radius: 1.1,
                colors: [c!.withValues(alpha: s.look == Look.editorial ? .10 : .22), c.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Card surface that renders per look (solid / paper / frosted glass).
class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.radius = 18, this.glow, this.padding});

  final Widget child;
  final double radius;
  final Color? glow;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    final r = BorderRadius.circular(s.look == Look.editorial ? radius * .75 : radius);
    final inner = Padding(padding: padding ?? EdgeInsets.zero, child: child);
    if (s.look == Look.glass) {
      return ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.white.withValues(alpha: .14), Colors.white.withValues(alpha: .05)]),
              border: Border.all(color: s.line),
            ),
            child: inner,
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: r,
        border: Border.all(color: s.line),
        boxShadow: s.look == Look.amoled && glow != null
            ? [BoxShadow(color: glow!.withValues(alpha: .10), blurRadius: 24, spreadRadius: -4)]
            : null,
      ),
      child: inner,
    );
  }
}

/// Press feedback: scales to .97 on touch-down, springs back. Fires on touch-up.
class Press extends StatefulWidget {
  const Press({super.key, required this.child, this.onTap, this.onLongPress});

  final Widget child;
  final VoidCallback? onTap, onLongPress;

  @override
  State<Press> createState() => _PressState();
}

class _PressState extends State<Press> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _down ? .97 : 1,
          duration: dur(context, _down ? 90 : 220),
          curve: easeOut,
          child: widget.child,
        ),
      );
}

/// Selectable chip used for tabs, filters and status pickers.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.on, required this.color, required this.onTap, this.icon, this.count});

  final String label;
  final bool on;
  final Color color;
  final VoidCallback onTap;
  final IconData? icon;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final s = context.skin;
    final fg = on ? Colors.black : s.ink.withValues(alpha: .75);
    return Press(
      onTap: onTap,
      child: AnimatedContainer(
        duration: dur(context, 240),
        curve: easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? color : s.ink.withValues(alpha: .06),
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: on ? color : s.line),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[Icon(icon, size: 16, color: fg), const SizedBox(width: 6)],
          Text(label, style: s.body(13.5, w: FontWeight.w600, color: fg)),
          if (count != null) ...[
            const SizedBox(width: 6),
            Text('$count', style: s.body(12, w: FontWeight.w500, color: fg.withValues(alpha: .7))),
          ],
        ]),
      ),
    );
  }
}
