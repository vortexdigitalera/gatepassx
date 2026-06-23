import 'dart:convert';
import 'package:crypto/crypto.dart' show sha256, Hmac;
import 'package:intl/intl.dart';

// ignore_for_file: constant_identifier_names
enum PassCategory { GUEST, VIP, STAFF, SPEAKER, PERFORMER, MEDIA, VENDOR, EXHIBITOR }
enum EventType { DINNER, GALA, CONFERENCE, WEDDING, CONCERT, FESTIVAL, EXHIBITION, CORPORATE, PRIVATE_PARTY, OTHER }

enum PassScanStatus {
  valid,
  notStarted,
  expired,
  duplicate,
  unknown,
}

class GatePass {
  final String passId;
  final String eventName;
  final EventType eventType;
  final PassCategory category;
  final String fullName;
  final String idNumber;
  final String? phone;
  final String? email;
  final String organizer;
  final DateTime validFrom;
  final DateTime validTo;
  final String? gate;
  final String? tableNumber;
  final String? groupRef;
  final DateTime issuedAt;
  final String issuedBy;
  String? qrPayload;
  DateTime? lastScannedAt;

  GatePass({
    required this.passId,
    this.eventName = 'General Event',
    this.eventType = EventType.DINNER,
    this.category = PassCategory.GUEST,
    required this.fullName,
    required this.idNumber,
    this.phone,
    this.email,
    this.organizer = 'Event Organizer',
    required this.validFrom,
    required this.validTo,
    this.gate,
    this.tableNumber,
    this.groupRef,
    DateTime? issuedAt,
    this.issuedBy = 'GatePassX',
    this.lastScannedAt,
  }) : issuedAt = issuedAt ?? DateTime.now();

  String get formattedValidity =>
      '${DateFormat.yMd().format(validFrom)} → ${DateFormat.yMd().format(validTo)}';

  /// Whether the pass validity window is currently active.
  bool get isActive {
    final now = DateTime.now();
    return !now.isBefore(validFrom) && !now.isAfter(validTo);
  }

  /// Whether the event hasn't started yet.
  bool get isNotStarted => DateTime.now().isBefore(validFrom);

  /// Whether the pass has expired.
  bool get isExpired => DateTime.now().isAfter(validTo);

  /// Whether this pass was already scanned today.
  bool get scannedToday {
    if (lastScannedAt == null) return false;
    final now = DateTime.now();
    return lastScannedAt!.year == now.year &&
        lastScannedAt!.month == now.month &&
        lastScannedAt!.day == now.day;
  }

  /// Compute the scan status for this known pass.
  PassScanStatus computeScanStatus() {
    final now = DateTime.now();
    if (now.isBefore(validFrom)) return PassScanStatus.notStarted;
    if (now.isAfter(validTo)) return PassScanStatus.expired;
    if (scannedToday) return PassScanStatus.duplicate;
    return PassScanStatus.valid;
  }

  /// Human-readable status label for display.
  String get statusLabel {
    if (isNotStarted) return 'NOT STARTED';
    if (isExpired) return 'EXPIRED';
    if (scannedToday) return 'SCANNED';
    return 'VALID';
  }

  Map<String, dynamic> toVerificationMap() {
    final map = {
      'pid': passId,
      'ev': eventName,
      'nm': fullName,
      'cat': category.name,
      'idn': idNumber,
      'org': organizer,
      'vf': DateFormat('yyyy-MM-dd').format(validFrom),
      'vt': DateFormat('yyyy-MM-dd').format(validTo),
      'gt': gate ?? '',
    };
    if (tableNumber != null && tableNumber!.isNotEmpty) map['tbl'] = tableNumber!;
    if (groupRef != null && groupRef!.isNotEmpty) map['grp'] = groupRef!;
    return map;
  }

  String computeQrPayload({String? secret}) {
    final data = toVerificationMap();
    if (secret != null && secret.isNotEmpty) {
      final payloadStr = jsonEncode(data);
      final hmac = Hmac(sha256, utf8.encode(secret));
      final sig = hmac.convert(utf8.encode(payloadStr)).toString().substring(0, 16);
      data['sig'] = sig;
    }
    qrPayload = jsonEncode(data);
    return qrPayload!;
  }

  Map<String, dynamic> toJson() => {
        'pass_id': passId,
        'event_name': eventName,
        'event_type': eventType.name,
        'category': category.name,
        'full_name': fullName,
        'id_number': idNumber,
        'phone': phone,
        'email': email,
        'organizer': organizer,
        'valid_from': DateFormat('yyyy-MM-dd').format(validFrom),
        'valid_to': DateFormat('yyyy-MM-dd').format(validTo),
        'gate': gate,
        'table_number': tableNumber,
        'group_ref': groupRef,
        'issued_at': issuedAt.toIso8601String(),
        'issued_by': issuedBy,
        'qr_payload': qrPayload,
        'last_scanned_at': lastScannedAt?.toIso8601String(),
      };

  factory GatePass.fromJson(Map<String, dynamic> json) {
    String norm(String? s) => (s ?? '').toString().toUpperCase();

    final catStr = norm(json['category'] ?? json['cat'] ?? 'GUEST');
    final etStr = norm(json['event_type'] ?? json['eventType'] ?? json['trip_type'] ?? 'DINNER');

    final organizer = json['organizer'] ?? json['operator'] ?? json['org'] ?? 'Unknown';

    return GatePass(
      passId: json['pass_id'] ?? json['pid'] ?? 'UNKNOWN',
      eventName: json['event_name'] ?? json['ev'] ?? 'General Event',
      eventType: etStr.isNotEmpty
          ? EventType.values.firstWhere((e) => e.name.toUpperCase() == etStr, orElse: () => EventType.OTHER)
          : EventType.DINNER,
      category: PassCategory.values.firstWhere(
          (e) => e.name.toUpperCase() == catStr,
          orElse: () => PassCategory.GUEST),
      fullName: json['full_name'] ?? json['nm'] ?? '',
      idNumber: json['id_number'] ?? json['idn'] ?? '',
      phone: json['phone'],
      email: json['email'],
      organizer: organizer,
      validFrom: DateTime.tryParse(json['valid_from'] ?? json['vf'] ?? '') ?? DateTime.now(),
      validTo: DateTime.tryParse(json['valid_to'] ?? json['vt'] ?? '') ?? DateTime.now().add(const Duration(days: 3)),
      gate: json['gate'] ?? json['gt'],
      tableNumber: json['table_number'] ?? json['tbl'],
      groupRef: json['group_ref'] ?? json['grp'],
      issuedAt: json['issued_at'] != null ? DateTime.tryParse(json['issued_at']) : null,
      issuedBy: json['issued_by'] ?? 'GatePassX',
      lastScannedAt: json['last_scanned_at'] != null ? DateTime.tryParse(json['last_scanned_at']) : null,
    )..qrPayload = json['qr_payload'];
  }
}

class PassLog {
  final DateTime timestamp;
  final String passId;
  final String action;
  final String? gate;
  final String? scannedBy;
  final bool valid;
  final String? notes;
  final String? scanStatus;

  PassLog({
    required this.passId,
    required this.action,
    this.gate,
    this.scannedBy,
    this.valid = true,
    this.notes,
    this.scanStatus,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'pass_id': passId,
        'action': action,
        'gate': gate,
        'scanned_by': scannedBy,
        'valid': valid,
        'notes': notes,
        'scan_status': scanStatus,
      };

  factory PassLog.fromJson(Map<String, dynamic> json) => PassLog(
        passId: json['pass_id'],
        action: json['action'],
        gate: json['gate'],
        scannedBy: json['scanned_by'],
        valid: json['valid'] ?? true,
        notes: json['notes'],
        scanStatus: json['scan_status'],
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );
}
