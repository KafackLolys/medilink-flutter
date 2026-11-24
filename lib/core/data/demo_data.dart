class DemoData {
  const DemoData._();

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

  // Mirrors the public endpoint response: { doctors: DoctorDirectoryItem[] }.
  static final recommendedDoctors = <String, dynamic>{
    'doctors': <Map<String, dynamic>>[
      {
        'id': 'doctor-demo-01',
        'name': 'Dr. Amina Nguema',
        'specialty': 'Médecine générale',
        'bio': 'Médecin généraliste, attentive à votre suivi au quotidien.',
        'yearsOfExperience': 12,
        'consultationFee': 15000,
        'currency': 'XAF',
        'professionalAddress': 'Centre médical, Yaoundé',
        'serviceCity': 'Yaoundé',
        'serviceDistricts': ['Bastos', 'Centre-ville'],
        'blockedDates': <String>[],
        'appointmentDurationMinutes': 30,
        'modes': ['home', 'teleconsultation'],
        'availability': <Map<String, dynamic>>[],
        'rating': 4.9,
        'reviewsCount': 128,
      },
      {
        'id': 'doctor-demo-02',
        'name': 'Dr. Paul Ndongo',
        'specialty': 'Cardiologie',
        'bio': 'Spécialiste du suivi cardiovasculaire.',
        'yearsOfExperience': 15,
        'consultationFee': 25000,
        'currency': 'XAF',
        'professionalAddress': 'Clinique du Centre, Yaoundé',
        'serviceCity': 'Yaoundé',
        'serviceDistricts': ['Centre-ville', 'Mvan'],
        'blockedDates': <String>[],
        'appointmentDurationMinutes': 45,
        'modes': ['home'],
        'availability': <Map<String, dynamic>>[],
        'rating': 4.8,
        'reviewsCount': 96,
      },
      {
        'id': 'doctor-demo-03',
        'name': 'Dr. Aïcha Kamga',
        'specialty': 'Pédiatrie',
        'bio': 'Accompagnement médical des enfants et des familles.',
        'yearsOfExperience': 9,
        'consultationFee': 18000,
        'currency': 'XAF',
        'professionalAddress': 'Quartier Bastos, Yaoundé',
        'serviceCity': 'Yaoundé',
        'serviceDistricts': ['Bastos', 'Ngoa-Ekellé'],
        'blockedDates': <String>[],
        'appointmentDurationMinutes': 30,
        'modes': ['home', 'teleconsultation'],
        'availability': <Map<String, dynamic>>[],
        'rating': 5.0,
        'reviewsCount': 74,
      },
    ],
  };

  // Mirrors PatientNeedListItem responses from GET /needs.
  static final patientNeeds = <Map<String, dynamic>>[
    {
      'id': 'need-demo-01',
      'title': 'Suivi de la tension artérielle',
      'specialty': 'Cardiologie',
      'createdAt': '2026-11-18T09:00:00.000Z',
      'interested': 2,
      'mode': 'domicile',
      'status': 'proposals_received',
      'attachmentsCount': 0,
      'description': 'Je souhaite faire le point sur ma tension cette semaine.',
      'priority': 'normal',
    },
    {
      'id': 'need-demo-02',
      'title': 'Consultation pédiatrique',
      'specialty': 'Pédiatrie',
      'createdAt': '2026-11-20T14:30:00.000Z',
      'interested': 0,
      'mode': 'teleconsultation',
      'status': 'awaiting_proposals',
      'attachmentsCount': 0,
      'description': 'Conseil médical pour une fièvre persistante.',
      'priority': 'normal',
    },
  ];

  // Mirrors PaginatedDoctorNeeds returned by GET /needs/doctor.
  static final doctorNeeds = <String, dynamic>{
    'items': <Map<String, dynamic>>[
      {
        'id': 'need-patient-demo-01',
        'title': 'Maux de tête fréquents',
        'summary': 'Maux de tête récurrents depuis une semaine.',
        'specialty': 'Neurologie',
        'city': 'Yaoundé',
        'district': 'Bastos',
        'mode': 'teleconsultation',
        'priority': 'routine',
        'publishedAt': '2026-11-21T08:45:00.000Z',
        'availableFrom': null,
        'documentsCount': 0,
        'publicLocation': null,
      },
      {
        'id': 'need-patient-demo-02',
        'title': 'Douleurs au bas du dos',
        'summary': 'Recherche un accompagnement à domicile.',
        'specialty': 'Kinésithérapie',
        'city': 'Yaoundé',
        'district': 'Mvan',
        'mode': 'home',
        'priority': 'urgent',
        'publishedAt': '2026-11-22T10:15:00.000Z',
        'availableFrom': null,
        'documentsCount': 0,
        'publicLocation': null,
      },
    ],
    'specialties': ['Kinésithérapie', 'Neurologie'],
    'page': 1,
    'pageSize': 10,
    'total': 2,
    'totalPages': 1,
  };

  // Mirrors GET /needs/doctor/proposals; status values stay backend-shaped.
  static final doctorProposals = <Map<String, dynamic>>[
    {
      'id': 'proposal-demo-01',
      'needId': 'need-patient-demo-01',
      'needTitle': 'Maux de tête fréquents',
      'patient': 'Patient Demo',
      'specialty': 'Neurologie',
      'scheduledAt': '2026-11-28T10:00:00.000Z',
      'consultationMode': 'teleconsultation',
      'fee': 20000,
      'currency': 'XAF',
      'status': 'sent',
      'createdAt': '2026-11-23T10:15:00.000Z',
    },
    {
      'id': 'proposal-demo-02',
      'needId': 'need-patient-demo-02',
      'needTitle': 'Douleurs au bas du dos',
      'patient': 'Patient Demo',
      'specialty': 'Kinésithérapie',
      'scheduledAt': '2026-11-29T14:00:00.000Z',
      'consultationMode': 'home',
      'fee': 18000,
      'currency': 'XAF',
      'status': 'pending',
      'createdAt': '2026-11-24T09:00:00.000Z',
    },
  ];

  static final patientProposals = <Map<String, dynamic>>[
    {
      'id': 'proposal-patient-demo-01',
      'needId': 'need-demo-01',
      'doctorId': 'doctor-demo-02',
      'doctorName': 'Dr. Paul Ndongo',
      'specialty': 'Cardiologie',
      'message':
          'Je peux vous recevoir pour un bilan et un suivi de votre tension.',
      'scheduledAt': '2026-11-28T10:00:00.000Z',
      'consultationMode': 'home',
      'fee': 25000,
      'currency': 'XAF',
      'status': 'sent',
    },
  ];

  // Mirrors PatientAppointmentView items returned by GET /appointments.
  static final patientAppointments = <Map<String, dynamic>>[
    {
      'id': 'appointment-demo-01',
      'doctor': {
        'id': 'doctor-demo-01',
        'name': 'Dr. Amina Nguema',
        'specialty': 'Médecine générale',
        'professionalAddress': 'Centre médical, Yaoundé',
      },
      'scheduledAt': '2026-11-27T09:30:00.000Z',
      'durationMinutes': 30,
      'consultationMode': 'home',
      'status': 'confirmed',
      'fee': 15000,
      'currency': 'XAF',
      'reason': 'Consultation de suivi',
    },
    {
      'id': 'appointment-demo-02',
      'doctor': {
        'id': 'doctor-demo-03',
        'name': 'Dr. Aïcha Kamga',
        'specialty': 'Pédiatrie',
        'professionalAddress': 'Yaoundé',
      },
      'scheduledAt': '2026-11-16T10:00:00.000Z',
      'durationMinutes': 30,
      'consultationMode': 'teleconsultation',
      'status': 'completed',
      'fee': 18000,
      'currency': 'XAF',
      'reason': 'Consultation de suivi',
      'review': null,
    },
  ];

  // Mirrors DoctorAppointmentView items returned by GET /appointments/doctor.
  static final doctorAppointments = <Map<String, dynamic>>[
    {
      'id': 'appointment-doctor-demo-01',
      'date': '2026-11-27',
      'time': '09:30',
      'patient': 'Patient Demo',
      'district': 'Bastos',
      'mode': 'home',
      'status': 'confirmed',
    },
    {
      'id': 'appointment-doctor-demo-02',
      'date': '2026-11-16',
      'time': '10:00',
      'patient': 'Patient Demo',
      'district': 'Bastos',
      'mode': 'teleconsultation',
      'status': 'completed',
    },
  ];

  // Mirrors GET /messages/conversations and the bounded conversation response.
  static final conversations = <Map<String, dynamic>>[
    {
      'id': 'conversation-demo-01',
      'participantName': 'Dr. Amina Nguema',
      'participantRole': 'doctor',
      'appointmentId': 'appointment-demo-01',
      'lastMessage': 'Je vous confirme notre rendez-vous vendredi.',
      'lastMessageAt': '2026-11-24T08:30:00.000Z',
      'unreadCount': 2,
      'messages': <Map<String, dynamic>>[
        {
          'id': 'message-demo-01',
          'senderId': 'doctor-demo-01',
          'content': 'Bonjour, avez-vous des questions avant la consultation ?',
          'createdAt': '2026-11-23T15:10:00.000Z',
        },
        {
          'id': 'message-demo-02',
          'senderId': 'user-demo-01',
          'content': 'Merci, je viendrai avec mes derniers résultats.',
          'createdAt': '2026-11-23T16:02:00.000Z',
        },
        {
          'id': 'message-demo-03',
          'senderId': 'doctor-demo-01',
          'content': 'Je vous confirme notre rendez-vous vendredi.',
          'createdAt': '2026-11-24T08:30:00.000Z',
        },
      ],
    },
    {
      'id': 'conversation-demo-02',
      'participantName': 'Dr. Paul Ndongo',
      'participantRole': 'doctor',
      'appointmentId': null,
      'lastMessage': 'Votre demande de cardiologie est bien reçue.',
      'lastMessageAt': '2026-11-22T11:20:00.000Z',
      'unreadCount': 0,
      'messages': <Map<String, dynamic>>[
        {
          'id': 'message-demo-04',
          'senderId': 'doctor-demo-02',
          'content': 'Votre demande de cardiologie est bien reçue.',
          'createdAt': '2026-11-22T11:20:00.000Z',
        },
      ],
    },
  ];

  // Mirrors NotificationView items from GET /notifications.
  static final notifications = <Map<String, dynamic>>[
    {
      'id': 'notification-demo-01',
      'type': 'appointment_confirmed',
      'title': 'Rendez-vous confirmé',
      'body': 'Dr. Amina Nguema vous recevra vendredi à 09:30.',
      'createdAt': '2026-11-24T08:32:00.000Z',
      'isRead': false,
      'destination': '/appointments/appointment-demo-01',
    },
    {
      'id': 'notification-demo-02',
      'type': 'new_message',
      'title': 'Nouveau message',
      'body': 'Dr. Amina Nguema vous a envoyé un message.',
      'createdAt': '2026-11-23T15:10:00.000Z',
      'isRead': false,
      'destination': '/messages/conversation-demo-01',
    },
    {
      'id': 'notification-demo-03',
      'type': 'proposal_received',
      'title': 'Nouvelle proposition',
      'body': 'Un médecin a répondu à votre besoin médical.',
      'createdAt': '2026-11-21T12:00:00.000Z',
      'isRead': true,
      'destination': '/needs/need-demo-01',
    },
  ];

  // Mirrors the user object embedded in the backend AuthSession response.
  static Map<String, dynamic> authSession({
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String role,
    String? specialty,
    String? registrationNumber,
  }) {
    return {
      'user': {
        'id': 'user-demo-01',
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': role,
        'specialty': role == 'doctor' ? specialty : null,
        'registrationNumber': role == 'doctor' ? registrationNumber : null,
        'status': role == 'doctor' ? 'pending' : 'active',
        'emailVerified': false,
        'phoneVerified': false,
      },
      'idToken': 'demo-id-token',
      'refreshToken': 'demo-refresh-token',
      'expiresIn': 3600,
      'tokenType': 'Bearer',
    };
  }
}
