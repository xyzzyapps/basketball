// test/mobile_orientation_test.dart
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aladdin_basketball/main.dart';

void main() {
  testWidgets('Renders properly in landscape view (horizontal)', (WidgetTester tester) async {
    // Landscape dimensions: 844 x 390
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const StickBasketballApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Verify key landscape elements
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('HOOP HEIGHT'), findsOneWidget);
    expect(find.text('BEST'), findsOneWidget);
  });

  testWidgets('Renders properly in portrait view (vertical) with mobile arcade console', (WidgetTester tester) async {
    // Portrait dimensions: 390 x 844
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(const StickBasketballApp());
    await tester.pump(const Duration(milliseconds: 100));

    // Verify portrait elements
    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('HOOP HEIGHT'), findsOneWidget);
    expect(find.text('BEST'), findsOneWidget);
    expect(find.text('FREE THROW'), findsOneWidget);
    expect(find.text('3-POINTER'), findsOneWidget);
    expect(find.text('HALF COURT'), findsOneWidget);
    expect(find.text('HOLD TO CHARGE • RELEASE TO SHOOT'), findsOneWidget);

    // Test mobile touch on pad
    final padFinder = find.text('HOLD TO CHARGE • RELEASE TO SHOOT');
    expect(padFinder, findsOneWidget);

    // Touch down on mobile pad
    final gesture = await tester.startGesture(tester.getCenter(padFinder), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(milliseconds: 200));

    // Verify that touching starts charging
    expect(find.textContaining('POWER:'), findsOneWidget);

    // Lift finger to release shot
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
