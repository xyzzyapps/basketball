// lib/stick_man.dart
// Stick figure basketball player controller, continuous rhythm bobbing, and up-bob boost mechanics.
import 'dart:math' as math;
import 'sdf_math.dart';

enum PlayerState { idle, aim, throwFollow, celebrate, miss }

class CourtSpot {
  final String name;
  final double x;
  final int points;

  const CourtSpot(this.name, this.x, this.points);
}

class StickManController {
  static const List<CourtSpot> spots = [
    CourtSpot("Free Throw", 5.2, 2),
    CourtSpot("3-Pointer", 3.6, 3),
    CourtSpot("Half Court", 2.0, 4),
    CourtSpot("Close Floater", 7.5, 2),
    CourtSpot("Deep Corner", 1.2, 5),
  ];

  int currentSpotIndex = 1; // Default to 3-pointer
  CourtSpot get currentSpot => spots[currentSpotIndex];

  // Continuous rhythmic bounce up & down
  double bobTime = 0.0;
  double get bobOffset => math.sin(bobTime * 4.5) * 0.08;
  double get bobUpVelocity => math.cos(bobTime * 4.5);

  // Upward bob boost: adds up to +3.5 launch speed when timing shot with upward bob!
  double get currentUpBobBoost {
    final up = bobUpVelocity;
    return up > 0 ? (up * 3.5) : 0.0;
  }

  bool get isBobbingUp => bobUpVelocity > 0.15;

  // Player position incorporates continuous bobbing
  Vec2 get position => Vec2(currentSpot.x, 2.0 + (state == PlayerState.throwFollow ? 0.0 : bobOffset));

  PlayerState state = PlayerState.idle;
  double aimAngle = 0.85; // approx 48 degrees
  double aimPower = 0.75;
  double throwTimer = 0.0;
  double stateTimer = 0.0;

  void nextSpot() {
    currentSpotIndex = (currentSpotIndex + 1) % spots.length;
  }

  void setSpotIndex(int index) {
    if (index >= 0 && index < spots.length) {
      currentSpotIndex = index;
    }
  }

  void startAiming() {
    state = PlayerState.aim;
    stateTimer = 0.0;
  }

  void updateAim(double angle, double power) {
    aimAngle = angle.clamp(0.18, 1.45);
    aimPower = power.clamp(0.20, 1.0);
  }

  void releaseThrow() {
    state = PlayerState.throwFollow;
    throwTimer = 0.0;
  }

  void celebrate() {
    state = PlayerState.celebrate;
    stateTimer = 0.0;
  }

  void miss() {
    state = PlayerState.miss;
    stateTimer = 0.0;
  }

  void returnToIdle() {
    state = PlayerState.idle;
    stateTimer = 0.0;
    throwTimer = 0.0;
  }

  void update(double dt) {
    stateTimer += dt;
    bobTime += dt;
    if (state == PlayerState.throwFollow) {
      throwTimer += dt * 3.5;
    }
  }

  // Returns exact ball hold position in world space for stick figure shooting pocket
  Vec2 getBallHoldPosition() {
    final pos = position;
    if (state == PlayerState.aim) {
      final crouch = 0.16 * aimPower;
      final hips = pos + Vec2(0.0, 1.05 - crouch);
      final shoulders = hips + Vec2(0.04 + crouch * 0.4, 0.95);
      final elbowR = shoulders + Vec2(math.cos(aimAngle - 1.1) * 0.32, math.sin(aimAngle - 1.1) * 0.32);
      final wristR = elbowR + Vec2(math.cos(aimAngle + 0.35) * 0.35, math.sin(aimAngle + 0.35) * 0.35);
      return wristR + Vec2(math.cos(aimAngle) * 0.22, math.sin(aimAngle) * 0.22);
    } else {
      return pos + const Vec2(0.35, 1.35);
    }
  }

  double get stateValue {
    switch (state) {
      case PlayerState.idle:
        return 0.0;
      case PlayerState.aim:
        return 1.0;
      case PlayerState.throwFollow:
        return 2.0;
      case PlayerState.celebrate:
        return 3.0;
      case PlayerState.miss:
        return 4.0;
    }
  }

  double get throwProgress => throwTimer.clamp(0.0, 1.0);
}
