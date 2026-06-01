import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vitalpath/core/widgets/status_hero_card.dart';

Widget _wrap(Widget c) => MaterialApp(home: Scaffold(body: c));

void main() {
  testWidgets('on-track shows pill, title, action', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard(
      data: const StatusHeroData(
          fraction: 0.66,
          ringLabel: '2/3',
          pillLabel: 'ON TRACK',
          tone: HeroTone.positive,
          title: 'One more to go today',
          subtitle: 'Evening dose due at 8:00 PM',
          actionLabel: 'Mark next dose taken'),
      onAction: () {},
    )));
    await t.pumpAndSettle();
    expect(find.text('ON TRACK'), findsOneWidget);
    expect(find.text('One more to go today'), findsOneWidget);
    expect(find.text('Mark next dose taken'), findsOneWidget);
  });

  testWidgets('all-done hides action button', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard(
      data: const StatusHeroData(
          fraction: 1.0,
          ringLabel: '✓',
          pillLabel: 'ALL DONE',
          tone: HeroTone.positive,
          title: 'Everything logged',
          subtitle: '3 of 3 doses',
          actionLabel: null),
      onAction: null,
    )));
    await t.pumpAndSettle();
    expect(find.text('ALL DONE'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });

  testWidgets('catch-up uses warning tone label', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard(
      data: const StatusHeroData(
          fraction: 0.33,
          ringLabel: '1/3',
          pillLabel: 'LET\'S CATCH UP',
          tone: HeroTone.warning,
          title: '2 doses waiting',
          subtitle: 'Morning & noon still due',
          actionLabel: 'Mark morning dose taken'),
      onAction: () {},
    )));
    await t.pumpAndSettle();
    expect(find.text('LET\'S CATCH UP'), findsOneWidget);
    expect(find.text('Mark morning dose taken'), findsOneWidget);
  });

  testWidgets('schedule variant lists rows + open action', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard.schedule(
      dateLabel: 'Mon, Jun 1',
      rows: const [
        ScheduleRow(
            time: '09:30',
            name: 'Aisha Hassan',
            status: 'Confirmed',
            confirmed: true),
        ScheduleRow(
            time: '11:00',
            name: 'Rafiq Ahmed',
            status: 'Pending',
            confirmed: false),
      ],
      onOpen: () {},
    )));
    await t.pumpAndSettle();
    expect(find.text('Today · 2 appointments'), findsOneWidget);
    expect(find.text('Open appointments'), findsOneWidget);
  });

  testWidgets('schedule empty shows caught-up', (t) async {
    await t.pumpWidget(_wrap(StatusHeroCard.schedule(
        dateLabel: 'Mon, Jun 1', rows: const [], onOpen: () {})));
    await t.pumpAndSettle();
    expect(find.text('No appointments today'), findsOneWidget);
  });
}
