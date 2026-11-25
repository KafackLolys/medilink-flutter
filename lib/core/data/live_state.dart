/// In-memory caches populated only from successful API responses.
/// This file deliberately contains no fixture or fallback records.
class LiveState {
  const LiveState._();

  static const specialties = <String>[
    'Médecine générale',
    'Cardiologie',
    'Pédiatrie',
    'Neurologie',
    'Dermatologie',
    'Gynécologie',
    'Rhumatologie',
    'Kinésithérapie',
  ];

  static final patientConditions = <Map<String, dynamic>>[];
  static final patientDocuments = <Map<String, dynamic>>[];
  static final recommendedDoctors = <String, dynamic>{
    'doctors': <Map<String, dynamic>>[],
  };
  static final patientNeeds = <Map<String, dynamic>>[];
  static final doctorNeeds = <String, dynamic>{
    'items': <Map<String, dynamic>>[],
    'specialties': <String>[],
    'page': 1,
    'pageSize': 10,
    'total': 0,
    'totalPages': 0,
  };
  static final doctorProposals = <Map<String, dynamic>>[];
  static final patientProposals = <Map<String, dynamic>>[];
  static final patientAppointments = <Map<String, dynamic>>[];
  static final doctorAppointments = <Map<String, dynamic>>[];
  static final conversations = <Map<String, dynamic>>[];
  static final notifications = <Map<String, dynamic>>[];

  static void clearSession() {
    patientConditions.clear();
    patientDocuments.clear();
    (recommendedDoctors['doctors'] as List).clear();
    patientNeeds.clear();
    doctorNeeds['items'] = <Map<String, dynamic>>[];
    doctorProposals.clear();
    patientProposals.clear();
    patientAppointments.clear();
    doctorAppointments.clear();
    conversations.clear();
    notifications.clear();
  }
}
