import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/theme/app_theme.dart';

/// Espace professionnel : profil, vérification, disponibilités, zone et avis.
class DoctorWorkspaceScreen extends StatefulWidget {
  const DoctorWorkspaceScreen({super.key});
  @override
  State<DoctorWorkspaceScreen> createState() => _DoctorWorkspaceScreenState();
}

class _DoctorWorkspaceScreenState extends State<DoctorWorkspaceScreen> {
  final api = MedilinkApi.instance;
  Map<String, dynamic> profile = {};
  Map<String, dynamic> zone = {};
  List<Map<String, dynamic>> reviews = [],
      modes = [],
      weekly = [],
      blocked = [],
      appointments = [];
  bool loading = false;
  int durationMinutes = 30;
  Set<String> selectedModes = <String>{};
  String? error;
  final bio = TextEditingController(),
      address = TextEditingController(),
      city = TextEditingController(),
      districts = TextEditingController();
  final years = TextEditingController(),
      fee = TextEditingController(),
      radius = TextEditingController(),
      maxDistance = TextEditingController();
  static const days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday'
  ];
  static const dayNames = [
    'Lundi',
    'Mardi',
    'Mercredi',
    'Jeudi',
    'Vendredi',
    'Samedi',
    'Dimanche'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      bio,
      address,
      city,
      districts,
      years,
      fee,
      radius,
      maxDistance
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (!api.isConfigured) {
      setState(() {
        profile = {};
        zone = {};
        modes = [];
        weekly = [];
        blocked = [];
        appointments = [];
        reviews = [];
        error = 'API_BASE_URL n’est pas configurée.';
      });
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    final failures = <String>[];
    Future<Object?> safe<T>(Future<T> request) async {
      try {
        return await request;
      } catch (e) {
        failures.add('$e');
        return null;
      }
    }

    try {
      final results = await Future.wait<Object?>([
        safe(api.doctorMe()),
        safe(api.availabilityModes()),
        safe(api.availabilityWeekly()),
        safe(api.availabilityBlocked()),
        safe(api.availabilityAppointments()),
        safe(api.integrationDoctorZone()),
        safe(api.doctorReviews()),
        safe(api.availabilityDuration()),
      ]);
      if (results[0] is Map<String, dynamic>)
        profile = results[0] as Map<String, dynamic>;
      if (results[1] is List<Map<String, dynamic>>) {
        modes = results[1] as List<Map<String, dynamic>>;
        selectedModes = modes
            .map((item) => '${item['mode'] ?? item['name'] ?? ''}'.trim())
            .where((value) => value == 'home' || value == 'teleconsultation')
            .toSet();
      }
      if (results[2] is List<Map<String, dynamic>>)
        weekly = results[2] as List<Map<String, dynamic>>;
      if (results[3] is List<Map<String, dynamic>>)
        blocked = results[3] as List<Map<String, dynamic>>;
      if (results[4] is List<Map<String, dynamic>>)
        appointments = results[4] as List<Map<String, dynamic>>;
      if (results[5] is Map<String, dynamic>)
        zone = results[5] as Map<String, dynamic>;
      if (results[6] is List<Map<String, dynamic>>)
        reviews = results[6] as List<Map<String, dynamic>>;
      if (results[7] is Map)
        durationMinutes = (results[7] as Map)['durationMinutes'] as int? ?? 30;
      if (failures.isNotEmpty)
        error =
            'Certaines sections n’ont pas pu être actualisées : ${failures.first}';
      _fill();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _fill() {
    bio.text = '${profile['bio'] ?? ''}';
    address.text = '${profile['professionalAddress'] ?? ''}';
    years.text = '${profile['yearsOfExperience'] ?? 0}';
    fee.text = '${profile['consultationFee'] ?? 0}';
    city.text = '${zone['city'] ?? ''}';
    final ds = zone['districts'];
    districts.text = ds is List ? ds.join(', ') : '';
    radius.text = '${zone['radiusKm'] ?? 0}';
    maxDistance.text = '${zone['maxDistanceKm'] ?? 0}';
  }

  Future<void> _save(Future<Object?> Function() action, String message) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
        _load();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Enregistrement impossible : $e')));
    }
  }

  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: RefreshIndicator(
      onRefresh: _load,
      child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
          children: [
            Text('Espace professionnel',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
            const SizedBox(height: 6),
            const Text(
                'Gérez votre profil, vos disponibilités et votre zone d’intervention.'),
            if (loading)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator()),
            if (error != null)
              Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text('Chargement partiel : $error',
                      style: const TextStyle(color: Colors.deepOrange))),
            const SizedBox(height: 14),
            _section(
                'Vérification du compte', LineAwesomeIcons.shield_alt_solid, [
              Text('Statut : ${_verification(profile['verificationStatus'])}'),
              const SizedBox(height: 4),
              const Text(
                  'Ajoutez vos justificatifs pour permettre la vérification de votre compte et l’envoi de propositions.')
            ]),
            _section('Justificatifs', LineAwesomeIcons.file_alt_solid, [
              ...(profile['documents'] is List
                      ? (profile['documents'] as List)
                          .whereType<Map>()
                          .map((d) => Map<String, dynamic>.from(d))
                      : <Map<String, dynamic>>[])
                  .map((d) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(_docType(d['type'])),
                      subtitle: Text(
                          '${d['fileName'] ?? d['name'] ?? ''} · ${d['status'] ?? 'Transmis'}'),
                      trailing: Wrap(spacing: 0, children: [
                        if (d['downloadUrl'] != null)
                          IconButton(
                              icon: const Icon(Icons.open_in_new),
                              onPressed: () => launchUrl(
                                  Uri.parse('${d['downloadUrl']}'),
                                  mode: LaunchMode.externalApplication)),
                        IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _save(
                                () => api.doctorDeleteDocument('${d['id']}'),
                                'Justificatif supprimé.'))
                      ]))),
              OutlinedButton.icon(
                  onPressed: _uploadDocument,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Ajouter un justificatif'))
            ]),
            _section('Profil professionnel', LineAwesomeIcons.user_md_solid, [
              _field(bio, 'Biographie', lines: 3),
              _field(years, 'Années d’expérience', numeric: true),
              _field(fee, 'Tarif de consultation (XAF)', numeric: true),
              _field(address, 'Adresse professionnelle'),
              Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                      onPressed: () => _save(
                          () => api.doctorUpdate(
                              bio: bio.text,
                              yearsOfExperience: num.tryParse(years.text),
                              consultationFee: num.tryParse(fee.text),
                              professionalAddress: address.text),
                          'Profil enregistré.'),
                      child: const Text('Enregistrer le profil')))
            ]),
            _section('Modes et durée des consultations',
                LineAwesomeIcons.stethoscope_solid, [
              const Text(
                  'Choisissez le mode de consultation que vous souhaitez proposer. Vous pouvez accepter les deux.'),
              const SizedBox(height: 12),
              LayoutBuilder(builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final options = [
                  ('home', 'À domicile', Icons.home_outlined),
                  ('teleconsultation', 'Téléconsultation',
                      Icons.videocam_outlined),
                  ('both', 'Les deux', Icons.done_all),
                ];
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: options.map((option) {
                    final value = option.$1;
                    final active = value == 'both'
                        ? selectedModes.length == 2
                        : selectedModes.length == 1 &&
                            selectedModes.contains(value);
                    final values = value == 'both'
                        ? <String>{'home', 'teleconsultation'}
                        : <String>{value};
                    return SizedBox(
                      width: compact
                          ? constraints.maxWidth
                          : (constraints.maxWidth - 16) / 3,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => selectedModes = values),
                        icon: Icon(option.$3,
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : null),
                        label: Text(option.$2),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 54),
                          foregroundColor: active
                              ? Theme.of(context).colorScheme.primary
                              : null,
                          backgroundColor: active
                              ? Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: .10)
                              : Colors.transparent,
                          side: BorderSide(
                            color: active
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).dividerColor,
                            width: active ? 2 : 1,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }),
              const SizedBox(height: 8),
              Text(
                selectedModes.length == 2
                    ? 'Consultations à domicile et téléconsultations acceptées.'
                    : selectedModes.contains('home')
                        ? 'Consultations à domicile acceptées.'
                        : selectedModes.contains('teleconsultation')
                            ? 'Téléconsultations acceptées.'
                            : 'Aucun mode configuré : choisissez une option.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: selectedModes.isEmpty
                      ? null
                      : () => _save(
                          () => api.availabilitySetModes(
                              selectedModes.toList()..sort()),
                          'Modes de consultation enregistrés.'),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Enregistrer les modes'),
                ),
              ),
            ]),
            _section('Horaires hebdomadaires',
                LineAwesomeIcons.calendar_check_solid, [
              ...List.generate(7, (i) {
                final row = weekly.firstWhere((r) => r['weekday'] == days[i],
                    orElse: () => {
                          'weekday': days[i],
                          'isAvailable': false,
                          'startTime': '08:00',
                          'endTime': '17:00'
                        });
                return SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(dayNames[i]),
                    secondary: IconButton(
                      tooltip: 'Modifier les heures',
                      icon: const Icon(Icons.schedule),
                      onPressed: () => _editWeeklyTimes(i, row),
                    ),
                    subtitle: Text(
                        '${row['startTime'] ?? '08:00'} – ${row['endTime'] ?? '17:00'}'),
                    value: row['isAvailable'] == true,
                    onChanged: (value) {
                      final updated = days.map((d) {
                        final old = weekly.firstWhere((r) => r['weekday'] == d,
                            orElse: () => {
                                  'weekday': d,
                                  'isAvailable': false,
                                  'startTime': '08:00',
                                  'endTime': '17:00'
                                });
                        return <String, dynamic>{
                          ...old,
                          'isAvailable':
                              d == days[i] ? value : old['isAvailable']
                        };
                      }).toList();
                      _save(() => api.availabilitySetWeekly(updated),
                          'Horaires enregistrés.');
                    });
              }),
              OutlinedButton.icon(
                  onPressed: () async {
                    final value = await showDialog<int>(
                        context: context,
                        builder: (c) {
                          int selected = durationMinutes;
                          return AlertDialog(
                              title: const Text('Durée des rendez-vous'),
                              content: StatefulBuilder(
                                builder: (c, s) => DropdownButton<int>(
                                    value: selected,
                                    items: [15, 20, 30, 45, 60]
                                        .map((v) => DropdownMenuItem(
                                            value: v,
                                            child: Text('$v minutes')))
                                        .toList(),
                                    onChanged: (v) =>
                                        s(() => selected = v ?? 30)),
                              ),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(c),
                                    child: const Text('Annuler')),
                                FilledButton(
                                    onPressed: () => Navigator.pop(c, selected),
                                    child: const Text('Enregistrer'))
                              ]);
                        });
                    if (value != null) {
                      durationMinutes = value;
                      _save(() => api.availabilitySetDuration(value),
                          'Durée enregistrée.');
                    }
                  },
                  icon: const Icon(Icons.timelapse),
                  label: const Text('Modifier la durée'))
            ]),
            _section('Dates indisponibles', LineAwesomeIcons.ban_solid, [
              ...blocked.map((b) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${b['date'] ?? ''}'),
                  subtitle: Text('${b['reason'] ?? 'Indisponible'}'),
                  trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _save(
                          () => api.availabilityDeleteBlocked('${b['id']}'),
                          'Date supprimée.')))),
              OutlinedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                        context: context,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                        initialDate: DateTime.now());
                    if (date != null)
                      _save(
                          () => api.availabilityCreateBlocked(
                              date:
                                  '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}'),
                          'Date bloquée.');
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Bloquer une date'))
            ]),
            _section(
                'Zone d’intervention', LineAwesomeIcons.map_marker_alt_solid, [
              _field(city, 'Ville'),
              _field(districts, 'Quartiers (séparés par des virgules)'),
              _field(radius, 'Rayon (km)', numeric: true),
              _field(maxDistance, 'Distance maximale (km)', numeric: true),
              Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                      onPressed: () => _save(
                          () => api.integrationSaveDoctorZone({
                                'city': city.text.trim(),
                                'districts': districts.text
                                    .split(',')
                                    .map((s) => s.trim())
                                    .where((s) => s.isNotEmpty)
                                    .toList(),
                                'radiusKm': num.tryParse(radius.text) ?? 0,
                                'maxDistanceKm':
                                    num.tryParse(maxDistance.text) ?? 0
                              }),
                          'Zone enregistrée.'),
                      child: const Text('Enregistrer la zone')))
            ]),
            _section(
                'Rendez-vous planifiés',
                LineAwesomeIcons.calendar_alt_solid,
                appointments.isEmpty
                    ? [const Text('Aucun rendez-vous à venir.')]
                    : appointments
                        .take(5)
                        .map((a) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${a['patient'] ?? 'Patient'}'),
                            subtitle: Text(
                                '${a['date'] ?? ''} · ${a['time'] ?? ''} · ${a['status'] ?? ''}')))
                        .toList()),
            _section(
                'Avis reçus',
                LineAwesomeIcons.star_solid,
                reviews.isEmpty
                    ? [
                        Text(
                            'Note moyenne : ${profile['rating'] ?? '-'} · ${profile['reviewsCount'] ?? reviews.length} avis'),
                        const Text('Vos avis récents apparaîtront ici.')
                      ]
                    : reviews
                        .take(10)
                        .map((r) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.star,
                                color: Color(0xfff2a900)),
                            title: Text(
                                '${r['rating'] ?? ''}/5 · ${r['patientName'] ?? r['patient'] ?? 'Patient'}'),
                            subtitle: Text('${r['comment'] ?? ''}')))
                        .toList()),
          ])));

  Widget _section(String title, IconData icon, List<Widget> children) => Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(icon, color: AppTheme.primary),
              const SizedBox(width: 10),
              Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)))
            ]),
            const SizedBox(height: 12),
            ...children
          ])));
  Widget _field(TextEditingController c, String label,
          {bool numeric = false, int lines = 1}) =>
      Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextField(
              controller: c,
              maxLines: lines,
              keyboardType: numeric ? TextInputType.number : TextInputType.text,
              decoration: InputDecoration(
                  labelText: label,
                  border: const OutlineInputBorder(),
                  isDense: true)));
  Future<void> _editWeeklyTimes(int index, Map<String, dynamic> row) async {
    TimeOfDay parse(String? value) {
      final parts = (value ?? '08:00').split(':');
      return TimeOfDay(
          hour: int.tryParse(parts.first) ?? 8,
          minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
    }

    final start = await showTimePicker(
        context: context, initialTime: parse(row['startTime']?.toString()));
    if (start == null || !mounted) return;
    final end = await showTimePicker(
        context: context, initialTime: parse(row['endTime']?.toString()));
    if (end == null) return;
    String format(TimeOfDay value) =>
        '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
    final updated = days.map((day) {
      final existing = weekly.firstWhere((item) => item['weekday'] == day,
          orElse: () => {
                'weekday': day,
                'isAvailable': false,
                'startTime': '08:00',
                'endTime': '17:00'
              });
      return <String, dynamic>{
        ...existing,
        if (day == days[index]) 'startTime': format(start),
        if (day == days[index]) 'endTime': format(end)
      };
    }).toList();
    await _save(
        () => api.availabilitySetWeekly(updated), 'Horaires enregistrés.');
  }

  Future<void> _uploadDocument() async {
    final type = await showDialog<String>(
        context: context,
        builder: (c) =>
            SimpleDialog(title: const Text('Type de justificatif'), children: [
              for (final e in const {
                'medical_license': 'Licence / ordre médical',
                'medical_degree': 'Diplôme médical',
                'identity_document': 'Pièce d’identité',
                'other': 'Autre'
              }.entries)
                SimpleDialogOption(
                    onPressed: () => Navigator.pop(c, e.key),
                    child: Text(e.value))
            ]));
    if (type == null) return;
    final selection = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: true);
    if (selection == null || selection.files.isEmpty) return;
    final f = selection.files.single;
    final ext = (f.extension ?? '').toLowerCase();
    const mimes = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp'
    };
    final bytes = f.bytes;
    if (bytes == null ||
        mimes[ext] == null ||
        bytes.length > 10 * 1024 * 1024) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Choisissez un PDF, JPEG, PNG ou WEBP de 10 Mo maximum.')));
      return;
    }
    await _save(
        () => api.doctorUploadDocument(
            type: type,
            file: http.MultipartFile.fromBytes('file', bytes,
                filename: f.name, contentType: MediaType.parse(mimes[ext]!))),
        'Justificatif transmis pour vérification.');
  }

  String _docType(dynamic type) => switch ('$type') {
        'medical_license' => 'Licence / ordre médical',
        'medical_degree' => 'Diplôme médical',
        'identity_document' => 'Pièce d’identité',
        _ => 'Autre justificatif'
      };
  String _verification(dynamic status) => switch ('$status') {
        'verified' => 'Vérifié',
        'rejected' => 'Refusé · justificatifs à corriger',
        'pending' => 'En attente de vérification',
        'null' => 'Non renseigné',
        _ => 'À compléter'
      };
}
