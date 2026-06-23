import 'package:flutter_test/flutter_test.dart';

import 'package:gatepassx/main.dart';
import 'package:gatepassx/models/gate_pass.dart';
import 'package:gatepassx/services/config.dart';

void main() {
  testWidgets('GatePassX app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GatePassXApp());
    expect(find.textContaining('DePass'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
  });

  group('GatePass model + workflow', () {
    test('creates pass, computes QR payload, roundtrips JSON', () {
      final pass = GatePass(
        passId: 'GPX-DINNER-2026-000999',
        eventName: 'Test Gala',
        eventType: EventType.DINNER,
        category: PassCategory.GUEST,
        fullName: 'Test Guest',
        idNumber: 'ID-123',
        organizer: 'Test Organizer',
        validFrom: DateTime(2026, 6, 1),
        validTo: DateTime(2026, 6, 3),
        gate: 'Gate X',
        tableNumber: 'T-05',
        groupRef: 'GRP-1',
      );
      final payload = pass.computeQrPayload(secret: AppConfig.qrSecret);
      expect(payload, isNotNull);
      expect(payload, contains('pid'));
      expect(payload, contains('sig'));

      final json = pass.toJson();
      final restored = GatePass.fromJson(json);
      expect(restored.passId, pass.passId);
      expect(restored.fullName, pass.fullName);
      expect(restored.eventName, pass.eventName);
      expect(restored.tableNumber, 'T-05');
      expect(restored.qrPayload, isNotNull);
    });

    test('fromJson accepts Python-style compact keys (pid, nm, cat, etc)', () {
      final pyStyle = {
        'pid': 'GPX-GALA-2026-000007',
        'ev': 'Charity Gala',
        'nm': 'Python User',
        'cat': 'SPEAKER',
        'idn': 'PY-007',
        'org': 'Py Organizer',
        'vf': '2026-07-01',
        'vt': '2026-07-05',
        'gt': 'Gate PY',
        'tbl': 'T-10',
      };
      final p = GatePass.fromJson(pyStyle);
      expect(p.passId, 'GPX-GALA-2026-000007');
      expect(p.eventName, 'Charity Gala');
      expect(p.category, PassCategory.SPEAKER);
      expect(p.fullName, 'Python User');
      expect(p.tableNumber, 'T-10');
      expect(p.validTo.year, 2026);
    });

    test('fromJson handles legacy fields (operator, trip_type)', () {
      final legacy = {
        'pass_id': 'LEGACY-001',
        'full_name': 'Legacy User',
        'id_number': 'LEG-ID',
        'operator': 'Old Org',
        'trip_type': 'HAJJ',
        'category': 'VIP',
        'valid_from': '2026-08-01',
        'valid_to': '2026-08-05',
      };
      final p = GatePass.fromJson(legacy);
      expect(p.organizer, 'Old Org');
      expect(p.eventType, EventType.OTHER);
      expect(p.category, PassCategory.VIP);
    });

    test('PassLog serializes and deserializes', () {
      final log = PassLog(
        passId: 'GPX-DINNER-2026-000101',
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
        category: PassCategory.GUEST,
        fullName: 'Expired',
        idNumber: 'X',
        organizer: 'O',
        validFrom: DateTime(2020),
        validTo: DateTime(2021),
      );
      expect(expired.validTo.isAfter(DateTime.now()), false);
    });
  });
}
