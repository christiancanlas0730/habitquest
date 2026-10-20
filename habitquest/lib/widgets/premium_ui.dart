import 'dart:ui';
import 'package:flutter/material.dart';
import 'quest_logo.dart';

class AppColors {
  static const background = Color(0xFF080A0F);
  static const surface = Color(0xFF11151D);
  static const surfaceRaised = Color(0xFF171D27);
  static const text = Color(0xFFF4F6FB);
  static const muted = Color(0xFF9AA5B5);
  static const faint = Color(0xFF687384);
  static const blue = Color(0xFF55B7FF);
  static const violet = Color(0xFF7968FF);
  static const green = Color(0xFF66D9B0);
  static const orange = Color(0xFFFFB36B);
  static const red = Color(0xFFFF777F);
  static const border = Color(0x2BFFFFFF);
}

IconData habitCategoryIcon(String category) {
  switch (category.toLowerCase()) {
    case 'study':
      return Icons.menu_book_rounded;
    case 'health':
      return Icons.favorite_rounded;
    case 'fitness':
      return Icons.directions_run_rounded;
    case 'personal':
      return Icons.person_rounded;
    default:
      return Icons.check_circle_outline_rounded;
  }
}

Color habitCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'study':
      return AppColors.blue;
    case 'health':
      return AppColors.red;
    case 'fitness':
      return AppColors.green;
    case 'personal':
      return AppColors.violet;
    default:
      return AppColors.muted;
  }
}

class PremiumBackground extends StatelessWidget {
  const PremiumBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF101722),
                AppColors.background,
                Color(0xFF090B12)
              ],
            ),
          ),
        ),
        Positioned(
          top: -150,
          right: -110,
          child: _GlowOrb(color: AppColors.violet.withValues(alpha: 0.13)),
        ),
        Positioned(
          bottom: 90,
          left: -165,
          child: _GlowOrb(color: AppColors.blue.withValues(alpha: 0.09)),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 22,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
          if (glow)
            BoxShadow(
              color: AppColors.blue.withValues(alpha: 0.10),
              blurRadius: 26,
              spreadRadius: -8,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xD91A202B), Color(0xC910141C)],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.trailing,
  });

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class HabitQuestBrand extends StatelessWidget {
  const HabitQuestBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        QuestLogoMark(size: compact ? 72 : 92),
        const SizedBox(height: 6),
        HabitQuestWordmark(fontSize: compact ? 25 : 29),
      ],
    );
  }
}
class CategorySelector extends StatelessWidget {
  const CategorySelector({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onChanged,
  });

  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: categories.map((category) {
        final selected = category == selectedCategory;
        final accent = habitCategoryColor(category);
        return Semantics(
          button: true,
          selected: selected,
          label: category,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: () => onChanged(category),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: selected
                      ? const LinearGradient(
                          colors: [Color(0xFF19344A), Color(0xFF282348)])
                      : null,
                  color: selected ? null : const Color(0x99141922),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: selected
                        ? AppColors.blue.withValues(alpha: 0.65)
                        : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(habitCategoryIcon(category),
                        size: 18, color: selected ? AppColors.blue : accent),
                    const SizedBox(width: 8),
                    Text(category,
                        style: TextStyle(
                            color: selected ? AppColors.text : AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class GradientActionButton extends StatelessWidget {
  const GradientActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(17),
          onTap: isLoading ? null : onPressed,
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: onPressed == null
                    ? const [Color(0xFF424A59), Color(0xFF373D4B)]
                    : const [AppColors.blue, AppColors.violet],
              ),
              borderRadius: BorderRadius.circular(17),
              boxShadow: [
                if (onPressed != null)
                  BoxShadow(
                    color: AppColors.violet.withValues(alpha: 0.24),
                    blurRadius: 18,
                    offset: const Offset(0, 7),
                  ),
              ],
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 19),
                          const SizedBox(width: 9),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration premiumInputDecoration({
  required String hintText,
  IconData? prefixIcon,
}) {
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: const BorderSide(color: Color(0x33FFFFFF)),
  );
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: AppColors.faint),
    prefixIcon: prefixIcon == null
        ? null
        : Icon(prefixIcon, color: AppColors.muted, size: 20),
    filled: true,
    fillColor: const Color(0xAA171C25),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: border,
    enabledBorder: border,
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.blue, width: 1.4),
    ),
  );
}
