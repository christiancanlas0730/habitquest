import 'package:flutter/material.dart';
import 'premium_ui.dart';

class QuestLogoMark extends StatelessWidget {
  const QuestLogoMark({super.key, this.size = 104});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * 0.84,
      child: CustomPaint(painter: _QuestLogoPainter()),
    );
  }
}

class HabitQuestWordmark extends StatelessWidget {
  const HabitQuestWordmark({super.key, this.fontSize = 29});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.9,
        ),
        children: const [
          TextSpan(
            text: 'Habit',
            style: TextStyle(color: const Color(0xFFF4F6FB)),
          ),
          TextSpan(
            text: 'Quest',
            style: TextStyle(color: const Color(0xFF55B7FF)),
          ),
        ],
      ),
    );
  }
}

class _QuestLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 100, size.height / 84);

    final mountain = Path()
      ..moveTo(5, 76)
      ..lineTo(37, 27)
      ..lineTo(49, 45)
      ..lineTo(64, 24)
      ..lineTo(96, 76)
      ..lineTo(76, 76)
      ..lineTo(64, 57)
      ..lineTo(51, 75)
      ..lineTo(38, 57)
      ..lineTo(26, 76)
      ..close();

    canvas.drawPath(
      mountain,
      Paint()
        ..color = const Color(0xFF55B7FF).withValues(alpha: 0.36)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawPath(
      mountain,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7ED0FF), Color(0xFF4A8DFF), Color(0xFF8567FF)],
        ).createShader(const Rect.fromLTWH(0, 0, 100, 84)),
    );

    final ridge = Path()
      ..moveTo(37, 27)
      ..lineTo(49, 45)
      ..lineTo(64, 24);
    canvas.drawPath(
      ridge,
      Paint()
        ..color = const Color(0xFFB7E8FF).withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    final star = Path()
      ..moveTo(64, 1)
      ..lineTo(68, 9)
      ..lineTo(77, 13)
      ..lineTo(68, 17)
      ..lineTo(64, 25)
      ..lineTo(60, 17)
      ..lineTo(51, 13)
      ..lineTo(60, 9)
      ..close();
    canvas.drawPath(
      star,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Color(0xFFB8E8FF)],
        ).createShader(const Rect.fromLTWH(51, 1, 26, 24)),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _QuestLogoPainter oldDelegate) => false;
}
