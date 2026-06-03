import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalpath/core/widgets/skeleton.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('SkeletonBox renders at given size', (t) async {
    await t.pumpWidget(_wrap(const SkeletonBox(width: 100, height: 20)));
    expect(find.byType(SkeletonBox), findsOneWidget);
    final box = t.widget<SkeletonBox>(find.byType(SkeletonBox));
    expect(box.width, 100);
    expect(box.height, 20);
  });

  testWidgets('DashboardSkeleton builds with multiple skeleton boxes', (t) async {
    await t.pumpWidget(_wrap(
        const SizedBox(width: 360, height: 720, child: DashboardSkeleton())));
    expect(find.byType(DashboardSkeleton), findsOneWidget);
    expect(find.byType(SkeletonBox), findsWidgets);
    expect(t.takeException(), isNull);
  });

  testWidgets('SkeletonBox is static under reduced motion', (t) async {
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: _wrap(const SkeletonBox(width: 50, height: 10)),
    ));
    // No pending animation frames when reduced motion is on.
    expect(t.hasRunningAnimations, isFalse);
  });
}
