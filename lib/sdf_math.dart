// lib/sdf_math.dart
// Pure Dart 2D Signed Distance Field (SDF) mathematics
import 'dart:math' as math;
import 'dart:ui';

class Vec2 {
  final double x;
  final double y;

  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double scalar) => Vec2(x * scalar, y * scalar);
  Vec2 operator /(double scalar) => Vec2(x / scalar, y / scalar);
  Vec2 operator -() => Vec2(-x, -y);

  double dot(Vec2 other) => x * other.x + y * other.y;
  double cross(Vec2 other) => x * other.y - y * other.x;
  double get length => math.sqrt(x * x + y * y);
  double get lengthSquared => x * x + y * y;

  Vec2 get normalized {
    final len = length;
    return len > 1e-6 ? this / len : Vec2.zero;
  }

  Offset toOffset() => Offset(x, y);

  static Vec2 fromOffset(Offset o) => Vec2(o.dx, o.dy);
}

class SdfMath {
  static double clamp(double v, double minVal, double maxVal) =>
      math.max(minVal, math.min(maxVal, v));

  // Circle SDF
  static double sdCircle(Vec2 p, double r) => p.length - r;

  // Box SDF
  static double sdBox(Vec2 p, Vec2 b) {
    final dx = p.x.abs() - b.x;
    final dy = p.y.abs() - b.y;
    final ox = math.max(dx, 0.0);
    final oy = math.max(dy, 0.0);
    final outside = math.sqrt(ox * ox + oy * oy);
    final inside = math.min(math.max(dx, dy), 0.0);
    return outside + inside;
  }

  // Segment / Line SDF
  static double sdSegment(Vec2 p, Vec2 a, Vec2 b) {
    final pa = p - a;
    final ba = b - a;
    final baLenSq = ba.lengthSquared;
    final h = baLenSq > 1e-6 ? clamp(pa.dot(ba) / baLenSq, 0.0, 1.0) : 0.0;
    return (pa - ba * h).length;
  }

  // Capsule SDF
  static double sdCapsule(Vec2 p, Vec2 a, Vec2 b, double r) =>
      sdSegment(p, a, b) - r;

  // Smooth minimum (Inigo Quilez cubic smin)
  static double smin(double a, double b, double k) {
    final h = math.max(k - (a - b).abs(), 0.0) / k;
    return math.min(a, b) - h * h * h * k * (1.0 / 6.0);
  }

  // Calculate 2D gradient (surface normal) of any SDF function
  static Vec2 calcNormal(double Function(Vec2) sdf, Vec2 p, [double eps = 0.005]) {
    final dx = sdf(Vec2(p.x + eps, p.y)) - sdf(Vec2(p.x - eps, p.y));
    final dy = sdf(Vec2(p.x, p.y + eps)) - sdf(Vec2(p.x, p.y - eps));
    final n = Vec2(dx, dy);
    return n.normalized;
  }
}
