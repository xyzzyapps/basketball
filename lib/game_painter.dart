// lib/game_painter.dart
// CustomPainter driving the GPU Fragment Shader and providing a complete Black & White outline line-animation renderer.
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'sdf_math.dart';
import 'physics.dart';
import 'stick_man.dart';

class Particle {
  Vec2 pos;
  Vec2 vel;
  Color color;
  double life;
  double maxLife;
  double size;

  Particle({
    required this.pos,
    required this.vel,
    required this.color,
    required this.maxLife,
    required this.size,
  }) : life = maxLife;

  bool update(double dt) {
    pos = pos + vel * dt;
    vel = vel + const Vec2(0, -9.8) * dt;
    life -= dt;
    return life > 0;
  }
}

class FloatingText {
  Vec2 pos;
  String text;
  Color color;
  double life;
  double maxLife;

  FloatingText({
    required this.pos,
    required this.text,
    required this.color,
    this.maxLife = 1.4,
  }) : life = maxLife;

  bool update(double dt) {
    pos = pos + const Vec2(0, 0.8) * dt;
    life -= dt;
    return life > 0;
  }
}

class GamePainter extends CustomPainter {
  final ui.FragmentShader? shader;
  final PhysicsEngine physics;
  final StickManController player;
  final double time;
  final int streak;
  final double scoreFlash;
  final bool isAiming;
  final List<Particle> particles;
  final List<FloatingText> floatingTexts;

  GamePainter({
    required this.shader,
    required this.physics,
    required this.player,
    required this.time,
    required this.streak,
    required this.scoreFlash,
    required this.isAiming,
    required this.particles,
    required this.floatingTexts,
  });

  // Convert world coordinates (16x9) to screen canvas pixels
  Offset worldToScreen(Vec2 w, Size size) {
    final scale = size.width / 16.0;
    return Offset(w.x * scale, size.height - (w.y * scale));
  }

  double worldToScreenDist(double dist, Size size) {
    return dist * (size.width / 16.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1. RENDER SDF WORLD VIA GPU FRAGMENT SHADER
    if (shader != null) {
      shader!.setFloat(0, size.width);
      shader!.setFloat(1, size.height);
      shader!.setFloat(2, time);
      shader!.setFloat(3, physics.ballPos.x);
      shader!.setFloat(4, physics.ballPos.y);
      shader!.setFloat(5, PhysicsEngine.ballRadius);
      shader!.setFloat(6, physics.ballRot);
      shader!.setFloat(7, player.position.x);
      shader!.setFloat(8, player.position.y);
      shader!.setFloat(9, player.aimAngle);
      shader!.setFloat(10, player.aimPower);
      shader!.setFloat(11, player.stateValue);
      shader!.setFloat(12, player.throwProgress);
      shader!.setFloat(13, physics.netFlex.x);
      shader!.setFloat(14, physics.netFlex.y);
      shader!.setFloat(15, streak.toDouble());
      shader!.setFloat(16, scoreFlash);
      shader!.setFloat(17, physics.hoopY);

      canvas.drawRect(
        Offset.zero & size,
        Paint()..shader = shader,
      );
    } else {
      // Outline line-animation vector fallback
      _paintOutlineScene(canvas, size);
    }

    // 2. RENDER AIMING TRAJECTORY (Predicts launch speed + Up-Bob Boost)
    if (isAiming) {
      final startPos = player.getBallHoldPosition();
      final trajectory = physics.calculateTrajectory(
        startPos,
        player.aimAngle,
        player.aimPower,
        player.currentUpBobBoost,
      );

      for (int i = 0; i < trajectory.length; i++) {
        final pt = trajectory[i];
        final screenPt = worldToScreen(pt, size);
        final t = i / trajectory.length;
        final radius = (1.0 - t * 0.45) * 5.0;

        // Glowing white dot
        final glowPaint = Paint()
          ..color = (player.isBobbingUp ? Colors.white : Colors.white70).withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(screenPt, radius + 2, glowPaint);

        // Solid white dot with dark outline
        canvas.drawCircle(screenPt, radius, Paint()..color = Colors.white);
        canvas.drawCircle(screenPt, radius, Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 1.0);
      }
    }

    // 3. RENDER LEFT-CLICK SHOT POWER METER & UP-BOOST INDICATOR
    if (isAiming) {
      _paintPowerMeter(canvas, size);
    }

    // 4. RENDER CELEBRATION PARTICLES (White / Silver Stars & Sparks)
    for (final p in particles) {
      final alpha = (p.life / p.maxLife).clamp(0.0, 1.0);
      final screenPos = worldToScreen(p.pos, size);
      final particlePaint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
      canvas.drawCircle(screenPos, p.size, particlePaint);
    }

    // 5. RENDER FLOATING SCORE TEXTS (Crisp High-Contrast White)
    for (final ft in floatingTexts) {
      final alpha = (ft.life / ft.maxLife).clamp(0.0, 1.0);
      final screenPos = worldToScreen(ft.pos, size);

      final textSpan = TextSpan(
        text: ft.text,
        style: TextStyle(
          color: ft.color.withValues(alpha: alpha),
          fontSize: 26,
          fontWeight: FontWeight.w900,
          letterSpacing: 2.0,
          shadows: [
            Shadow(
              blurRadius: 6.0,
              color: Colors.black.withValues(alpha: alpha * 0.9),
              offset: const Offset(2, 2),
            ),
            Shadow(
              blurRadius: 14.0,
              color: ft.color.withValues(alpha: alpha * 0.5),
            ),
          ],
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(
        canvas,
        screenPos - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    }
  }

  // Draw the Left-Click Shot Power Meter and Up-Bob Boost badge
  void _paintPowerMeter(Canvas canvas, Size size) {
    final playerScreen = worldToScreen(player.position, size);
    final meterLeft = playerScreen.dx - 45.0;
    final meterBottom = playerScreen.dy - 10.0;
    const meterWidth = 14.0;
    const meterHeight = 90.0;
    final meterRect = Rect.fromLTWH(meterLeft, meterBottom - meterHeight, meterWidth, meterHeight);

    // Dark backdrop with white border outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(meterRect, const Radius.circular(4)),
      Paint()..color = Colors.black.withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(meterRect, const Radius.circular(4)),
      Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0,
    );

    // Power fill level
    final fillHeight = meterHeight * player.aimPower;
    final fillRect = Rect.fromLTWH(meterLeft + 2, meterBottom - fillHeight + 1, meterWidth - 4, fillHeight - 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(fillRect, const Radius.circular(2)),
      Paint()..color = Colors.white,
    );

    // Percentage & Up-Bob Boost Banner
    final pct = (player.aimPower * 100).toInt();
    final isUp = player.isBobbingUp;
    final boostText = isUp ? "▲ BOOST!" : "PWR";

    final textSpan = TextSpan(
      children: [
        TextSpan(
          text: "$boostText\n",
          style: TextStyle(
            color: isUp ? const Color(0xFFFFD54F) : Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
        TextSpan(
          text: "$pct%",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(canvas, Offset(meterLeft - 10, meterBottom - meterHeight - 28));
  }

  // Complete, clean line-art outline vector scene (Xiao Xiao animation style)
  void _paintOutlineScene(Canvas canvas, Size size) {
    final scale = size.width / 16.0;

    // Dark canvas
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0C0E12));

    // Ground line
    final floorYScreen = size.height - (PhysicsEngine.floorY * scale);
    final linePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(0, floorYScreen), Offset(size.width, floorYScreen), linePaint);

    // Court tick marks
    canvas.drawLine(
      Offset(worldToScreen(const Vec2(5.2, 2.0), size).dx, floorYScreen),
      Offset(worldToScreen(const Vec2(5.2, 2.0), size).dx, floorYScreen + 8),
      linePaint,
    );
    canvas.drawLine(
      Offset(worldToScreen(const Vec2(3.6, 2.0), size).dx, floorYScreen),
      Offset(worldToScreen(const Vec2(3.6, 2.0), size).dx, floorYScreen + 8),
      linePaint,
    );

    // Hoop Outline at dynamic hoopY
    final hoopY = physics.hoopY;

    // Stand Wireframe
    final poleL = worldToScreen(const Vec2(14.50, 2.0), size).dx;
    final poleR = worldToScreen(const Vec2(14.70, 2.0), size).dx;
    final poleTop = worldToScreen(const Vec2(14.60, 8.2), size).dy;
    canvas.drawLine(Offset(poleL, floorYScreen), Offset(poleL, poleTop), linePaint);
    canvas.drawLine(Offset(poleR, floorYScreen), Offset(poleR, poleTop), linePaint);

    // Bracket
    final bracketStart = worldToScreen(Vec2(14.60, hoopY + 0.40), size);
    final bracketEnd = worldToScreen(Vec2(13.55, hoopY + 0.40), size);
    canvas.drawLine(bracketStart, bracketEnd, linePaint);

    // Backboard Outline (Hollow Rectangle)
    final bbCenterScreen = worldToScreen(Vec2(13.55, hoopY + 0.40), size);
    final bbRect = Rect.fromCenter(center: bbCenterScreen, width: 8, height: scale * 1.7);
    canvas.drawRRect(RRect.fromRectAndRadius(bbRect, const Radius.circular(2)), linePaint);

    // Target Box Outline
    final targetCenterScreen = worldToScreen(Vec2(13.48, hoopY + 0.28), size);
    canvas.drawRect(Rect.fromCenter(center: targetCenterScreen, width: 4, height: scale * 0.52), linePaint);

    // Rim Line Outline
    final rimFrontScreen = worldToScreen(Vec2(12.20, hoopY), size);
    final rimBackScreen = worldToScreen(Vec2(13.45, hoopY), size);
    canvas.drawLine(rimFrontScreen, rimBackScreen, linePaint..strokeWidth = 3.0);

    // Woven Net Wireframe lines
    final netFlex = physics.netFlex;
    final netTopScreen = worldToScreen(Vec2(12.82, hoopY), size);
    final netBottomScreen = worldToScreen(Vec2(12.82 + netFlex.x, hoopY - 1.05 + netFlex.y), size);
    final netPaint = Paint()..color = Colors.white.withValues(alpha: 0.9)..strokeWidth = 1.5;

    for (double i = -0.6; i <= 0.6; i += 0.2) {
      final topPt = Offset(netTopScreen.dx + i * scale * 0.9, netTopScreen.dy);
      final botPt = Offset(netBottomScreen.dx + i * scale * 0.45, netBottomScreen.dy);
      canvas.drawLine(topPt, botPt, netPaint);
    }

    // Stick Figure (Hollow Head, Line Limbs with Bobbing position)
    final root = player.position;
    final crouch = player.state == PlayerState.aim ? 0.16 * player.aimPower : 0.0;
    final hips = root + Vec2(0.0, 1.05 - crouch);
    final footL = root + const Vec2(-0.25, 0.04);
    final footR = root + const Vec2(0.22, 0.04);
    final kneeL = (hips + footL) * 0.5 + Vec2(crouch * 0.8 + 0.08, 0.0);
    final kneeR = (hips + footR) * 0.5 + Vec2(crouch * 0.8 + 0.10, 0.0);
    final shoulders = hips + Vec2(0.04 + crouch * 0.4, 0.95);
    final neck = shoulders + const Vec2(0.02, 0.14);
    final head = neck + const Vec2(0.04, 0.28);

    final stickPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Hollow Head Circle
    canvas.drawCircle(worldToScreen(head, size), scale * 0.20, stickPaint);
    // Eye dot
    canvas.drawCircle(worldToScreen(head + const Vec2(0.06, 0.04), size), 2.0, Paint()..color = Colors.white);

    // Spine
    canvas.drawLine(worldToScreen(shoulders, size), worldToScreen(hips, size), stickPaint);
    // Legs
    canvas.drawLine(worldToScreen(hips, size), worldToScreen(kneeL, size), stickPaint);
    canvas.drawLine(worldToScreen(kneeL, size), worldToScreen(footL, size), stickPaint);
    canvas.drawLine(worldToScreen(hips, size), worldToScreen(kneeR, size), stickPaint);
    canvas.drawLine(worldToScreen(kneeR, size), worldToScreen(footR, size), stickPaint);

    // Arms
    Vec2 elbowR, wristR;
    if (player.state == PlayerState.aim) {
      final angle = player.aimAngle;
      elbowR = shoulders + Vec2(math.cos(angle - 1.1) * 0.32, math.sin(angle - 1.1) * 0.32);
      wristR = elbowR + Vec2(math.cos(angle + 0.35) * 0.35, math.sin(angle + 0.35) * 0.35);
    } else if (player.state == PlayerState.throwFollow) {
      final angle = player.aimAngle;
      elbowR = shoulders + Vec2(math.cos(angle) * 0.38, math.sin(angle) * 0.38);
      wristR = elbowR + Vec2(math.cos(angle) * 0.35, math.sin(angle) * 0.35 - 0.14);
    } else {
      elbowR = shoulders + const Vec2(0.24, -0.32);
      wristR = elbowR + const Vec2(0.22, 0.18);
    }
    canvas.drawLine(worldToScreen(shoulders, size), worldToScreen(elbowR, size), stickPaint);
    canvas.drawLine(worldToScreen(elbowR, size), worldToScreen(wristR, size), stickPaint);

    // Basketball Outline
    final ballCenterScreen = worldToScreen(physics.ballPos, size);
    final rScreen = worldToScreenDist(PhysicsEngine.ballRadius, size);
    canvas.drawCircle(ballCenterScreen, rScreen, Paint()..color = Colors.black.withValues(alpha: 0.6));
    canvas.drawCircle(ballCenterScreen, rScreen, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2.0);

    // Rotating Seams
    final seamPaint = Paint()..color = Colors.white..strokeWidth = 1.5;
    canvas.save();
    canvas.translate(ballCenterScreen.dx, ballCenterScreen.dy);
    canvas.rotate(physics.ballRot);
    canvas.drawLine(Offset(-rScreen, 0), Offset(rScreen, 0), seamPaint);
    canvas.drawLine(Offset(0, -rScreen), Offset(0, rScreen), seamPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter oldDelegate) => true;
}
