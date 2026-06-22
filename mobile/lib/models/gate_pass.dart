import 'dart:convert';
import 'package:intl/intl.dart';

enum PassCategory { PILGRIM, STAFF, VEHICLE, VISITOR, VIP }
enum TripType { HAJJ, UMRAH }

class GatePass {
  final String passId;
  final PassCategory category;
  final String fullName;
  final String idNumber;
  final String? phone;
  final String operator;
  final TripType? tripType;
  final DateTime validFrom;
  final DateTime validTo;
  final String? gate;
  final String? groupRef;
  final String? vehiclePlate;
  final DateTime issuedAt;
  final String issuedBy;
  String? qrPayload;

  GatePass({
    required this.passId,
    required this.category,
    required this.fullName,
    required this.idNumber,
    this.phone,
    required this.operator,
    this.tripType,
    required this.validFrom,
    required this.validTo,
    this.gate,
    this.groupRef,
    this.vehiclePlate,
    DateTime? issuedAt,
    this.issuedBy = 'Mobile App',
  }) : issuedAt = issuedAt ?? DateTime.now();

  String get formattedValidity =>
      '${DateFormat.yMd().format(validFrom)} → ${DateFormat.yMd().format(validTo)}';

  Map<String, dynamic> toVerificationMap() {
    final map = {
      'pid': passId,
      'nm': fullName,
      'cat': category.name,
      'idn': idNumber,
      'op': operator,
      'vf': DateFormat('yyyy-MM-dd').format(validFrom),
      'vt': DateFormat('yyyy-MM-dd').format(validTo),
      'gt': gate ?? '',
    };
    if (groupRef != null && groupRef!.isNotEmpty) map['grp'] = groupRef!;
    if (vehiclePlate != null && vehiclePlate!.isNotEmpty) map['vp'] = vehiclePlate!;
    return map;
  }

  String computeQrPayload({String secret = 'ahuon-gatepass-secret-2026'}) {
    final data = toVerificationMap();
    // For compatibility with Python generator, use compact json
    qrPayload = jsonEncode(data);
    return qrPayload!;
  }

  Map<String, dynamic> toJson() => {
        'pass_id': passId,
        'category': category.name,
        'full_name': fullName,
        'id_number': idNumber,
        'phone': phone,
        'operator': operator,
        'trip_type': tripType?.name,
        'valid_from': DateFormat('yyyy-MM-dd').format(validFrom),
        'valid_to': DateFormat('yyyy-MM-dd').format(validTo),
        'gate': gate,
        'group_ref': groupRef,
        'vehicle_plate': vehiclePlate,
        'issued_at': issuedAt.toIso8601String(),
        'issued_by': issuedBy,
        'qr_payload': qrPayload,
      };

  factory GatePass.fromJson(Map<String, dynamic> json) {
    String norm(String? s) => (s ?? '').toString().toUpperCase();
    final catStr = norm(json['category'] ?? json['cat'] ?? 'PILGRIM');
    final tripStr = norm(json['trip_type'] ?? json['tripType']);
    return GatePass(
      passId: json['pass_id'] ?? json['pid'] ?? 'UNKNOWN',
      category: PassCategory.values.firstWhere(
          (e) => e.name.toUpperCase() == catStr,
          orElse: () => PassCategory.PILGRIM),
      fullName: json['full_name'] ?? json['nm'] ?? '',
      idNumber: json['id_number'] ?? json['idn'] ?? '',
      phone: json['phone'],
      operator: json['operator'] ?? json['op'] ?? 'Unknown Operator',
      tripType: tripStr.isNotEmpty
          ? TripType.values.firstWhere((e) => e.name.toUpperCase() == tripStr, orElse: () => TripType.HAJJ)
          : null,
      validFrom: DateTime.tryParse(json['valid_from'] ?? '') ?? DateTime.now(),
      validTo: DateTime.tryParse(json['valid_to'] ?? '') ?? DateTime.now().add(const Duration(days: 30)),
      gate: json['gate'] ?? json['gt'],
      groupRef: json['group_ref'] ?? json['grp'],
      vehiclePlate: json['vehicle_plate'] ?? json['vp'],
      issuedAt: json['issued_at'] != null ? DateTime.tryParse(json['issued_at']) : null,
      issuedBy: json['issued_by'] ?? 'Mobile App',
    )..qrPayload = json['qr_payload'];
  }
}

class PassLog {
  final DateTime timestamp;
  final String passId;
  final String action; // ENTRY, EXIT, REJECTED
  final String? gate;
  final String? scannedBy;
  final bool valid;
  final String? notes;

  PassLog({
    required this.passId,
    required this.action,
    this.gate,
    this.scannedBy,
    this.valid = true,
    this.notes,
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
      };

  factory PassLog.fromJson(Map<String, dynamic> json) => PassLog(
        passId: json['pass_id'],
        action: json['action'],
        gate: json['gate'],
        scannedBy: json['scanned_by'],
        valid: json['valid'] ?? true,
        notes: json['notes'],
        timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      );
}
