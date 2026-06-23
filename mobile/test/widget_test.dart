// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:gatepassx/main.dart';
import 'package:gatepassx/models/gate_pass.dart';
import 'package:gatepassx/services/config.dart';

void main() {
  testWidgets('GatePassX app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GatePassXApp());
    // Verify title text appears
    expect(find.textContaining('GatePassX'), findsOneWidget);
    // Dashboard tab label
    expect(find.text('Dashboard'), findsOneWidget);
  });

  group('GatePass model + workflow', () {
    test('creates pass, computes QR payload, roundtrips JSON', () {
      final pass = GatePass(
        passId: 'AHUON-HAJJ-2026-000999',
        category: PassCategory.PILGRIM,
        fullName: 'Test Pilgrim',
        idNumber: 'ID-123',
        operator: 'Test Operator',
        tripType: TripType.HAJJ,
        validFrom: DateTime(2026, 6, 1),
        validTo: DateTime(2026, 7, 1),
        gate: 'Gate X',
        groupRef: 'GRP-1',
      );
      final payload = pass.computeQrPayload(secret: AppConfig.qrSecret);
      expect(payload, isNotNull);
      expect(payload, contains('pid'));
      expect(payload, contains('sig')); // when secret present

      final json = pass.toJson();
      final restored = GatePass.fromJson(json);
      expect(restored.passId, pass.passId);
      expect(restored.fullName, pass.fullName);
      expect(restored.qrPayload, isNotNull);
    });

    test('fromJson accepts Python-style compact keys (pid, nm, cat, etc)', () {
      final pyStyle = {
        'pid': 'AHUON-UMR-2026-000007',
        'nm': 'Python User',
        'cat': 'STAFF',
        'idn': 'PY-007',
        'op': 'Py Operator',
        'vf': '2026-07-01',
        'vt': '2026-07-31',
        'gt': 'Gate PY',
      };
      final p = GatePass.fromJson(pyStyle);
      expect(p.passId, 'AHUON-UMR-2026-000007');
      expect(p.category, PassCategory.STAFF);
      expect(p.fullName, 'Python User');
      expect(p.validTo.year, 2026);
    });

    test('PassLog serializes and deserializes', () {
      final log = PassLog(
        passId: 'AHUON-HAJJ-2026-000101',
        action: 'ENTRY',
        gate: 'Gate A',
        valid: true,
        notes: 'ok',
      );
      final j = log.toJson();
      final back = PassLog.fromJson(j);
      expect(back.passId, log.passId);
      expect(back.action, 'ENTRY');
      expect(back.valid, true);
    });

    test('validity check works', () {
      final expired = GatePass(
        passId: 'EXP',
        category: PassCategory.VISITOR,
        fullName: 'Expired',
        idNumber: 'X',
        operator: 'O',
        validFrom: DateTime(2020),
        validTo: DateTime(2021),
      );
      expect(expired.validTo.isAfter(DateTime.now()), false);
    });
  });
}
