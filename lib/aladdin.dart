// lib/aladdin.dart
// Aladdin character state, skeletal kinematics, and shooting positions
import 'dart:math' as math;
import 'sdf_math.dart';

enum AladdinState { idle, aim, throwFollow, celebrate, miss }

class ShootingSpot {
  final String name;
  final double x;
  final int points;

  const ShootingSpot(this.name, this.x, this.points);
}

class AladdinController {
  static const List<ShootingSpot> spots = [
    ShootingSpot("Free Throw", 5.2, 2),
    ShootingSpot("3-Pointer", 3.6, 3),
    ShootingSpot("Deep Balcony", 2.2, 4),
    ShootingSpot("Close Floater", 7.2, 2),
    ShootingSpot("Extreme Rooftop Edge", 1.2, 5),
  ];

  int currentSpotIndex = 1; // Default to 3-pointer
  ShootingSpot get currentSpot => spots[currentSpotIndex];

  Vec2 get position => Vec2(currentSpot.x, 2.0);

  AladdinState state = AladdinState.idle;
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
    state = AladdinState.aim;
    stateTimer = 0.0;
  }

  void updateAim(double angle, double power) {
    aimAngle = angle.clamp(0.2, 1.45);
    aimPower = power.clamp(0.2, 1.0);
  }

  void releaseThrow() {
    state = AladdinState.throwFollow;
    throwTimer = 0.0;
  }

  void celebrate() {
    state = AladdinState.celebrate;
    stateTimer = 0.0;
  }

  void miss() {
    state = AladdinState.miss;
    stateTimer = 0.0;
  }

  void returnToIdle() {
    state = AladdinState.idle;
    stateTimer = 0.0;
    throwTimer = 0.0;
  }

  void update(double dt) {
    stateTimer += dt;
    if (state == AladdinState.throwFollow) {
      throwTimer += dt * 3.5;
      if (throwTimer > 1.2) {
        // Remain in follow-through or idle until ball resolves
      }
    }
  }

  // Returns ball hold position in world coordinates when aiming or holding
  Vec2 getBallHoldPosition() {
    final pos = position;
    if (state == AladdinState.aim) {
      // Arm raised cocked back holding ball
      final shoulder = pos + const Vec2(0.12, 1.25);
      final elbow = shoulder + Vec2(math.cos(aimAngle - 1.2) * 0.28, math.sin(aimAngle - 1.2) * 0.28);
      final wrist = elbow + Vec2(math.cos(aimAngle + 0.4) * 0.32, math.sin(aimAngle + 0.4) * 0.32);
      return wrist + Vec2(math.cos(aimAngle) * 0.22, math.sin(aimAngle) * 0.22);
    } else {
      // Resting hold
      return pos + const Vec2(0.35, 1.35);
    }
  }

  double get stateValue {
    switch (state) {
      case AladdinState.idle:
        return 0.0;
      case AladdinState.aim:
        return 1.0;
      case AladdinState.throwFollow:
        return 2.0;
      case AladdinState.celebrate:
        return 3.0;
      case AladdinState.miss:
        return 4.0;
    }
  }

  double get throwProgress => throwTimer.clamp(0.0, 1.0);
}
