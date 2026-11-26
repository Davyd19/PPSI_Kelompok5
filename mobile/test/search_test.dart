import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/screens/badge_collection.dart';
import 'package:mobile/theme.dart';
import 'package:mobile/widgets/school_ui.dart';

void main() {
  test('matchesSearch ignores case and word order', () {
    final fields = ['Siswa Contoh', 'X IPA 1', 'Terlambat'];
    expect(matchesSearch('', fields), isTrue);
    expect(matchesSearch('  ', fields), isTrue);
    expect(matchesSearch('siswa', fields), isTrue);
    expect(matchesSearch('ipa contoh', fields), isTrue);
    expect(matchesSearch('TERLAMBAT x', fields), isTrue);
    expect(matchesSearch('alfa', fields), isFalse);
    expect(matchesSearch('siswa alfa', fields), isFalse);
    expect(matchesSearch('a', [null, 'Abc']), isTrue);
  });

  testWidgets('badge collection filters by search and can be cleared', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: BadgeCollection(
            load: () async => [
              {
                'id': 1,
                'badge': 'Rajin',
                'nama': 'Perunggu',
                'progress': 3,
                'target': 5,
                'diperoleh': false,
              },
              {
                'id': 2,
                'badge': 'Disiplin',
                'nama': 'Perak',
                'progress': 5,
                'target': 5,
                'diperoleh': true,
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rajin · Perunggu'), findsOneWidget);
    expect(find.text('Disiplin · Perak'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'disiplin');
    await tester.pumpAndSettle();
    expect(find.text('Rajin · Perunggu'), findsNothing);
    expect(find.text('Disiplin · Perak'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'tidak ada');
    await tester.pumpAndSettle();
    expect(
      find.text('Tidak ada badge yang cocok dengan "tidak ada".'),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pumpAndSettle();
    expect(find.text('Rajin · Perunggu'), findsOneWidget);
    expect(find.text('Disiplin · Perak'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
