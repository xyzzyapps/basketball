import 'package:flutter_test/flutter_test.dart';
import 'package:aladdin_basketball/sdf_math.dart';
import 'package:aladdin_basketball/physics.dart';
import 'package:aladdin_basketball/stick_man.dart';

void main() {
  group('SDF Math Primitive Tests', () {
    test('sdCircle calculates exact distance', () {
      const center = Vec2(0, 0);
      expect(SdfMath.sdCircle(const Vec2(3, 4) - center, 5.0), closeTo(0.0, 1e-5));
      expect(SdfMath.sdCircle(const Vec2(0, 2) - center, 5.0), closeTo(-3.0, 1e-5));
      expect(SdfMath.sdCircle(const Vec2(8, 0) - center, 5.0), closeTo(3.0, 1e-5));
    });

    test('sdBox calculates exact distance', () {
      const b = Vec2(2, 1);
      expect(SdfMath.sdBox(const Vec2(2, 0.5), b), closeTo(0.0, 1e-5));
      expect(SdfMath.sdBox(const Vec2(0, 0), b), lessThan(0.0));
      expect(SdfMath.sdBox(const Vec2(3, 1), b), closeTo(1.0, 1e-5));
    });

    test('calcNormal computes exact perpendicular gradient', () {
      final normal = SdfMath.calcNormal((p) => SdfMath.sdCircle(p, 2.0), const Vec2(2.0, 0.0));
      expect(normal.x, closeTo(1.0, 1e-2));
      expect(normal.y, closeTo(0.0, 1e-2));
    });
  });

  group('Physics & Stick Figure Controller Tests', () {
    test('Stick figure spot switching and continuous bobbing', () {
      final player = StickManController();
      expect(player.currentSpot.name, "3-Pointer");
      player.nextSpot();
      expect(player.currentSpot.name, "Half Court");
      player.update(0.1);
      expect(player.bobTime, greaterThan(0.0));
    });

    test('Dynamic hoop height level adjustment for every turn', () {
      final physics = PhysicsEngine();
      final initialHeight = physics.hoopY;
      expect(initialHeight, 5.85);

      physics.randomizeHoopHeight();
      expect(physics.hoopY, isNot(equals(initialHeight)));
      expect(physics.hoopY, inInclusiveRange(4.0, 7.5));
      expect(physics.rimFront.y, equals(physics.hoopY));
      expect(physics.rimBack.y, equals(physics.hoopY));
      expect(physics.backboardCenter.y, equals(physics.hoopY + 0.40));
    });

    test('Parabola math: every hoop height (up to 7.5) has valid angles that reach and clear hoop', () {
      final physics = PhysicsEngine();
      // Test extreme high basket at 7.5
      physics.hoopY = 7.5;
      const startPos = Vec2(3.6, 3.2); // 3-pointer position
      const double targetX = 12.8;

      // With max power and up-bob boost, verify trajectory reaches hoop X with height >= 7.5
      final trajectory = physics.calculateTrajectory(startPos, 1.15, 1.0, 3.0, 40);
      bool reachedAboveHoop = false;
      for (final pt in trajectory) {
        if ((pt.x - targetX).abs() < 0.6 && pt.y >= 7.5) {
          reachedAboveHoop = true;
          break;
        }
      }
      expect(reachedAboveHoop, isTrue, reason: "Ball should reach or exceed high hoop height");
    });
  });
}
