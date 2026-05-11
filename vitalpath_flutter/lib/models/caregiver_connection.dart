import 'package:cloud_firestore/cloud_firestore.dart';

class CaregiverPermissions {
  final bool medicines;
  final bool vitals;
  final bool appointments;
  final bool prescriptions;
  final bool mealLogs;
  final bool activityLogs;

  const CaregiverPermissions({
    this.medicines = true,
    this.vitals = true,
    this.appointments = true,
    this.prescriptions = true,
    this.mealLogs = false,
    this.activityLogs = false,
  });

  factory CaregiverPermissions.fromMap(Map<String, dynamic> m) =>
      CaregiverPermissions(
        medicines: m['medicines'] as bool? ?? true,
        vitals: m['vitals'] as bool? ?? true,
        appointments: m['appointments'] as bool? ?? true,
        prescriptions: m['prescriptions'] as bool? ?? true,
        mealLogs: m['mealLogs'] as bool? ?? false,
        activityLogs: m['activityLogs'] as bool? ?? false,
      );

  Map<String, dynamic> toMap() => {
        'medicines': medicines,
        'vitals': vitals,
        'appointments': appointments,
        'prescriptions': prescriptions,
        'mealLogs': mealLogs,
        'activityLogs': activityLogs,
      };

  CaregiverPermissions copyWith({
    bool? medicines,
    bool? vitals,
    bool? appointments,
    bool? prescriptions,
    bool? mealLogs,
    bool? activityLogs,
  }) =>
      CaregiverPermissions(
        medicines: medicines ?? this.medicines,
        vitals: vitals ?? this.vitals,
        appointments: appointments ?? this.appointments,
        prescriptions: prescriptions ?? this.prescriptions,
        mealLogs: mealLogs ?? this.mealLogs,
        activityLogs: activityLogs ?? this.activityLogs,
      );
}

class CaregiverNotifSettings {
  final bool missedDose;
  final bool abnormalVital;
  final bool upcomingAppointment;
  final bool appointmentStatusChange;
  final bool newPrescription;
  final bool weeklySummary;
  final String? quietHoursStart; // "HH:mm"
  final String? quietHoursEnd; // "HH:mm"
  final double bpSystolicThreshold;
  final double glucoseThreshold;
  final double heartRateMin;
  final double heartRateMax;

  const CaregiverNotifSettings({
    this.missedDose = true,
    this.abnormalVital = true,
    this.upcomingAppointment = true,
    this.appointmentStatusChange = true,
    this.newPrescription = true,
    this.weeklySummary = false,
    this.quietHoursStart,
    this.quietHoursEnd,
    this.bpSystolicThreshold = 140,
    this.glucoseThreshold = 180,
    this.heartRateMin = 50,
    this.heartRateMax = 110,
  });

  factory CaregiverNotifSettings.fromMap(Map<String, dynamic> m) =>
      CaregiverNotifSettings(
        missedDose: m['missedDose'] as bool? ?? true,
        abnormalVital: m['abnormalVital'] as bool? ?? true,
        upcomingAppointment: m['upcomingAppointment'] as bool? ?? true,
        appointmentStatusChange: m['appointmentStatusChange'] as bool? ?? true,
        newPrescription: m['newPrescription'] as bool? ?? true,
        weeklySummary: m['weeklySummary'] as bool? ?? false,
        quietHoursStart: m['quietHoursStart'] as String?,
        quietHoursEnd: m['quietHoursEnd'] as String?,
        bpSystolicThreshold:
            (m['bpSystolicThreshold'] as num?)?.toDouble() ?? 140,
        glucoseThreshold: (m['glucoseThreshold'] as num?)?.toDouble() ?? 180,
        heartRateMin: (m['heartRateMin'] as num?)?.toDouble() ?? 50,
        heartRateMax: (m['heartRateMax'] as num?)?.toDouble() ?? 110,
      );

  Map<String, dynamic> toMap() => {
        'missedDose': missedDose,
        'abnormalVital': abnormalVital,
        'upcomingAppointment': upcomingAppointment,
        'appointmentStatusChange': appointmentStatusChange,
        'newPrescription': newPrescription,
        'weeklySummary': weeklySummary,
        if (quietHoursStart != null) 'quietHoursStart': quietHoursStart,
        if (quietHoursEnd != null) 'quietHoursEnd': quietHoursEnd,
        'bpSystolicThreshold': bpSystolicThreshold,
        'glucoseThreshold': glucoseThreshold,
        'heartRateMin': heartRateMin,
        'heartRateMax': heartRateMax,
      };

  CaregiverNotifSettings copyWith({
    bool? missedDose,
    bool? abnormalVital,
    bool? upcomingAppointment,
    bool? appointmentStatusChange,
    bool? newPrescription,
    bool? weeklySummary,
    String? quietHoursStart,
    String? quietHoursEnd,
    double? bpSystolicThreshold,
    double? glucoseThreshold,
    double? heartRateMin,
    double? heartRateMax,
    bool clearQuietHours = false,
  }) =>
      CaregiverNotifSettings(
        missedDose: missedDose ?? this.missedDose,
        abnormalVital: abnormalVital ?? this.abnormalVital,
        upcomingAppointment: upcomingAppointment ?? this.upcomingAppointment,
        appointmentStatusChange:
            appointmentStatusChange ?? this.appointmentStatusChange,
        newPrescription: newPrescription ?? this.newPrescription,
        weeklySummary: weeklySummary ?? this.weeklySummary,
        quietHoursStart:
            clearQuietHours ? null : (quietHoursStart ?? this.quietHoursStart),
        quietHoursEnd:
            clearQuietHours ? null : (quietHoursEnd ?? this.quietHoursEnd),
        bpSystolicThreshold: bpSystolicThreshold ?? this.bpSystolicThreshold,
        glucoseThreshold: glucoseThreshold ?? this.glucoseThreshold,
        heartRateMin: heartRateMin ?? this.heartRateMin,
        heartRateMax: heartRateMax ?? this.heartRateMax,
      );
}

class CaregiverConnection {
  final String id;
  final String patientId;
  final String patientName;
  final String? caregiverUid;
  final String caregiverEmail;
  final String? caregiverName;
  final String relationship;
  final CaregiverPermissions permissions;
  final CaregiverNotifSettings notifSettings;
  final String status; // pending / connected / removed
  final DateTime invitedAt;
  final DateTime? connectedAt;
  final String? personalMessage;

  const CaregiverConnection({
    required this.id,
    required this.patientId,
    required this.patientName,
    this.caregiverUid,
    required this.caregiverEmail,
    this.caregiverName,
    required this.relationship,
    required this.permissions,
    required this.notifSettings,
    required this.status,
    required this.invitedAt,
    this.connectedAt,
    this.personalMessage,
  });

  bool get isPending => status == 'pending';
  bool get isConnected => status == 'connected';

  factory CaregiverConnection.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return CaregiverConnection(
      id: doc.id,
      patientId: d['patientId'] as String,
      patientName: d['patientName'] as String? ?? '',
      caregiverUid: d['caregiverUid'] as String?,
      caregiverEmail: d['caregiverEmail'] as String,
      caregiverName: d['caregiverName'] as String?,
      relationship: d['relationship'] as String? ?? 'other',
      permissions: d['permissions'] != null
          ? CaregiverPermissions.fromMap(
              Map<String, dynamic>.from(d['permissions'] as Map))
          : const CaregiverPermissions(),
      notifSettings: d['notifSettings'] != null
          ? CaregiverNotifSettings.fromMap(
              Map<String, dynamic>.from(d['notifSettings'] as Map))
          : const CaregiverNotifSettings(),
      status: d['status'] as String? ?? 'pending',
      invitedAt: (d['invitedAt'] as Timestamp).toDate(),
      // C4: Default to epoch when connectedAt is missing so orderBy never fails.
      connectedAt: d['connectedAt'] != null
          ? (d['connectedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      personalMessage: d['personalMessage'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'patientId': patientId,
        'patientName': patientName,
        if (caregiverUid != null) 'caregiverUid': caregiverUid,
        'caregiverEmail': caregiverEmail,
        if (caregiverName != null) 'caregiverName': caregiverName,
        'relationship': relationship,
        'permissions': permissions.toMap(),
        'notifSettings': notifSettings.toMap(),
        'status': status,
        'invitedAt': Timestamp.fromDate(invitedAt),
        if (connectedAt != null) 'connectedAt': Timestamp.fromDate(connectedAt!),
        if (personalMessage != null) 'personalMessage': personalMessage,
      };
}

extension RelationshipLabel on String {
  String get relationshipLabel {
    switch (this) {
      case 'spouse':
        return 'Spouse / Partner';
      case 'parent':
        return 'Parent';
      case 'child':
        return 'Child / Adult child';
      case 'sibling':
        return 'Sibling';
      case 'professional':
        return 'Professional Caregiver';
      default:
        return 'Other';
    }
  }
}
