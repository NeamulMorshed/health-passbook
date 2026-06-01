import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalpath/core/anim/reduced_motion.dart';

void main() {
  testWidgets('prefersReducedMotion true when disableAnimations set', (t) async {
    late bool result;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Builder(builder: (c) {
        result = prefersReducedMotion(c);
        return const SizedBox();
      }),
    ));
    expect(result, isTrue);
  });

  testWidgets('prefersReducedMotion false by default', (t) async {
    late bool result;
    await t.pumpWidget(MediaQuery(
      data: const MediaQueryData(),
      child: Builder(builder: (c) {
        result = prefersReducedMotion(c);
        return const SizedBox();
      }),
    ));
    expect(result, isFalse);
  });
}
