// lib/physics.dart
// SDF-driven Physics simulation with generous rim funneling, solved projectile ballistics, and anti-stuck safety.
import 'dart:math' as math;
import 'sdf_math.dart';

enum ShotResult { none, scored, missed }

class PhysicsEngine {
  // World parameters
  static const double gravity = -14.5;
  static const double floorY = 2.0;
  static const double ballRadius = 0.22;

  // Dynamic Hoop Height (Adjusted for every turn!)
  double hoopY = 5.85;

  // Generous, realistic rim opening (Width = 1.25 units, ~2.8x ball diameter)
  Vec2 get rimFront => Vec2(12.20, hoopY);
  Vec2 get rimBack => Vec2(13.45, hoopY);
  static const double rimRadius = 0.055;

  Vec2 get backboardCenter => Vec2(13.55, hoopY + 0.40);
  static const Vec2 backboardHalf = Vec2(0.08, 0.85);

  // Ball state
  Vec2 ballPos = const Vec2(3.2, 4.2);
  Vec2 ballVel = Vec2.zero;
  double ballRot = 0.0;
  double ballRotVel = 0.0;
  bool isFlying = false;
  double flightTime = 0.0; // Anti-stuck safety timer

  // Shot tracking
  bool touchedRim = false;
  bool touchedBackboard = false;
  bool enteredRimAbove = false;
  bool scored = false;
  ShotResult lastResult = ShotResult.none;
  String scoreType = ""; // "SWISH", "BANK SHOT", "BASKET"

  // Net dynamic simulation (spring-damper)
  Vec2 netFlex = Vec2.zero;
  Vec2 netFlexVel = Vec2.zero;

  // Randomize / adjust hoop height for every turn
  void randomizeHoopHeight() {
    final rand = math.Random();
    double candidate;
    do {
      // Range: 4.3 (low dunk height) to 7.2 (high skyhook height)
      candidate = 4.3 + rand.nextDouble() * 2.9;
    } while ((candidate - hoopY).abs() < 0.6);
    hoopY = candidate;
  }

  void resetBall(Vec2 throwPosition) {
    ballPos = throwPosition;
    ballVel = Vec2.zero;
    ballRotVel = 0.0;
    isFlying = false;
    flightTime = 0.0;
    touchedRim = false;
    touchedBackboard = false;
    enteredRimAbove = false;
    scored = false;
    lastResult = ShotResult.none;
    scoreType = "";
  }

  // Solved launch speed: power + up-bob boost allows reaching ANY height from ANY court spot
  void launch(double angleRad, double power, [double upBobBoost = 0.0]) {
    isFlying = true;
    flightTime = 0.0;
    touchedRim = false;
    touchedBackboard = false;
    enteredRimAbove = false;
    scored = false;
    lastResult = ShotResult.none;

    // Upgraded speed formula: power * 18.5 + upBobBoost gives up to 22.0 speed (easily reaches >11.0m height)
    final speed = power * 18.5 + upBobBoost;
    ballVel = Vec2(math.cos(angleRad) * speed, math.sin(angleRad) * speed);
    // Backspin on release
    ballRotVel = -power * 10.0;
  }

  // SDF map of solid obstacles (Backboard, Rims, Post, Bracket)
  double sceneObstacleSdf(Vec2 p) {
    final dBackboard = SdfMath.sdBox(p - backboardCenter, backboardHalf);
    final dRimFront = SdfMath.sdCircle(p - rimFront, rimRadius);
    final dRimBack = SdfMath.sdCircle(p - rimBack, rimRadius);
    final dPost = SdfMath.sdBox(p - const Vec2(14.6, 4.8), const Vec2(0.12, 3.2));
    final dBracket = SdfMath.sdCapsule(p, Vec2(14.6, hoopY + 0.40), Vec2(13.55, hoopY + 0.40), 0.045);

    return math.min(math.min(dBackboard, math.min(dPost, dBracket)), math.min(dRimFront, dRimBack));
  }

  // Sub-stepped physics update (dt in seconds)
  void update(double dt, {void Function(String type, double intensity)? onSound}) {
    // 1. Update net spring simulation
    const double netSpring = 120.0;
    const double netDamping = 8.5;
    final netAcc = Vec2(
      -netSpring * netFlex.x - netDamping * netFlexVel.x,
      -netSpring * netFlex.y - netDamping * netFlexVel.y,
    );
    netFlexVel = netFlexVel + netAcc * dt;
    netFlex = netFlex + netFlexVel * dt;

    if (!isFlying) return;

    // Safety Anti-Stuck Timer: maximum 3.0 seconds flight time
    flightTime += dt;
    if (flightTime > 3.0) {
      if (!scored && lastResult == ShotResult.none) {
        lastResult = ShotResult.missed;
      }
      return;
    }

    // Fixed sub-stepping for tunneling prevention
    const int subSteps = 8;
    final subDt = dt / subSteps;

    final rimCenterX = (rimFront.x + rimBack.x) * 0.5;
    final rimRadiusX = (rimBack.x - rimFront.x) * 0.5;

    for (int step = 0; step < subSteps; step++) {
      // Apply gravity
      ballVel = ballVel + Vec2(0, gravity * subDt);

      // Mild air drag
      final speed = ballVel.length;
      if (speed > 1e-4) {
        ballVel = ballVel + ballVel * (-0.015 * speed * subDt);
      }

      // 2. MAGNETIC RIM FUNNEL ASSIST
      // When descending over the rim opening, gently guide the ball toward center
      if (ballVel.y < 0 && (ballPos.x - rimCenterX).abs() < rimRadiusX + 0.15) {
        if (ballPos.y >= hoopY - 0.25 && ballPos.y <= hoopY + 0.85) {
          final toCenter = (rimCenterX - ballPos.x);
          ballVel = Vec2(ballVel.x + toCenter * 3.5 * subDt, ballVel.y);
        }
      }

      // If ball has entered the net, dampen horizontal motion so it drops cleanly through
      if (enteredRimAbove && nextPosInsideNet(ballPos)) {
        ballVel = Vec2(ballVel.x * 0.92, ballVel.y);
      }

      var nextPos = ballPos + ballVel * subDt;
      ballRot += ballRotVel * subDt;

      // 3. ROBUST SCORE & SWISH DETECTION
      // Check if ball center crossed the rim height Y=hoopY moving downward inside rim bounds
      final inRimCylinder = (nextPos.x - rimCenterX).abs() < (rimRadiusX - 0.02);
      if (ballPos.y >= hoopY && nextPos.y <= hoopY && inRimCylinder) {
        enteredRimAbove = true;
        netFlex = Vec2(ballVel.x * 0.06, -0.30);
        netFlexVel = Vec2(ballVel.x * 0.6, -4.5);
        onSound?.call('swish', 1.0);
      }

      // Ball clears through net bottom
      if (enteredRimAbove && !scored && nextPos.y < hoopY - 0.55) {
        scored = true;
        lastResult = ShotResult.scored;
        if (!touchedRim && !touchedBackboard) {
          scoreType = "SWISH! +3";
        } else if (touchedBackboard) {
          scoreType = "BANK SHOT! +2";
        } else {
          scoreType = "BASKET! +2";
        }
        netFlexVel = netFlexVel + const Vec2(0, -3.0);
      }

      // 4. ANTI-STUCK: BEHIND THE BASKET CHECK
      if (nextPos.x > backboardCenter.x + 0.10) {
        if (nextPos.y < hoopY || nextPos.y < floorY + 0.6) {
          if (!scored && lastResult == ShotResult.none && flightTime > 0.8) {
            lastResult = ShotResult.missed;
          }
        }
      }

      // 5. Collision against Floor
      if (nextPos.y - ballRadius < floorY) {
        nextPos = Vec2(nextPos.x, floorY + ballRadius);
        if (ballVel.y < 0) {
          final impact = (-ballVel.y / 10.0).clamp(0.1, 1.0);
          onSound?.call('bounce', impact);
          ballVel = Vec2(ballVel.x * 0.82, -ballVel.y * 0.68);
          ballRotVel = -ballVel.x * 6.0;
        }

        // Fast settle when on floor
        if (ballVel.length < 1.2 && flightTime > 0.6) {
          ballVel = Vec2.zero;
          ballRotVel = 0.0;
          if (!scored && lastResult == ShotResult.none) {
            lastResult = ShotResult.missed;
          }
        }
      }

      // 6. Collision against Scene SDF Obstacles (Backboard & Rims)
      final d = sceneObstacleSdf(nextPos);
      if (d < ballRadius) {
        final penetration = ballRadius - d;
        final normal = SdfMath.calcNormal(sceneObstacleSdf, nextPos);

        nextPos = nextPos + normal * penetration;

        final vn = ballVel.dot(normal);
        if (vn < 0) {
          final vt = ballVel - normal * vn;

          final dRim = math.min(
            (nextPos - rimFront).length - ballRadius,
            (nextPos - rimBack).length - ballRadius,
          );

          if (dRim < 0.18) {
            touchedRim = true;
            onSound?.call('rim', (-vn / 8.0).clamp(0.2, 1.0));
            // Soft friendly breakaway rim restitution
            const double rimRestitution = 0.52;
            const double rimFriction = 0.30;
            ballVel = vt * (1.0 - rimFriction) - normal * (vn * rimRestitution);
          } else {
            touchedBackboard = true;
            onSound?.call('backboard', (-vn / 8.0).clamp(0.2, 1.0));
            // Backboard restitution
            const double bbRestitution = 0.72;
            const double bbFriction = 0.20;
            ballVel = vt * (1.0 - bbFriction) - normal * (vn * bbRestitution);
          }

          ballRotVel += vt.cross(normal) * 10.0;
        }
      }

      ballPos = nextPos;
    }

    // Out of bounds check
    if (ballPos.x > 16.5 || ballPos.x < -1.0) {
      if (!scored && lastResult == ShotResult.none) {
        lastResult = ShotResult.missed;
      }
    }
  }

  bool nextPosInsideNet(Vec2 p) {
    return p.y <= hoopY && p.y >= hoopY - 1.1 && p.x > rimFront.x && p.x < rimBack.x;
  }

  // Pre-calculate trajectory dots matching launch physics exactly
  List<Vec2> calculateTrajectory(Vec2 start, double angleRad, double power, [double upBobBoost = 0.0, int points = 24]) {
    final list = <Vec2>[];
    final speed = power * 18.5 + upBobBoost;
    var v = Vec2(math.cos(angleRad) * speed, math.sin(angleRad) * speed);
    var p = start;
    const double dt = 0.035;

    for (int i = 0; i < points; i++) {
      v = v + Vec2(0, gravity * dt);
      p = p + v * dt;
      list.add(p);
      if (p.y < floorY || p.x > backboardCenter.x + 0.1) break;
    }
    return list;
  }
}
