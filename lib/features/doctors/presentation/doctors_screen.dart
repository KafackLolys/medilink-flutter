import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/live_state.dart';
import '../../../core/theme/app_theme.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key, this.onAppointmentCreated});

  final VoidCallback? onAppointmentCreated;

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final search = TextEditingController();
  String specialty = 'Toutes';
  String city = 'Toutes';
  String mode = 'Tous';
  List<Map<String, dynamic>> apiDoctors = [];
  List<String> apiSpecialties = [];
  bool hasApiResponse = false;
  bool loadingApi = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) _loadDoctors();
  }

  Future<void> _loadDoctors() async {
    setState(() => loadingApi = true);
    try {
      final response = await MedilinkApi.instance.doctorsList(
        q: search.text.trim().isEmpty ? null : search.text.trim(),
        specialty: specialty == 'Toutes' ? null : specialty,
        city: city == 'Toutes' ? null : city,
      );
      final raw = response['doctors'] ?? response['items'];
      apiDoctors = raw is List
          ? raw
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : <Map<String, dynamic>>[];
      apiSpecialties = response['specialties'] is List
          ? (response['specialties'] as List)
              .map((value) => value.toString())
              .toList()
          : [];
      hasApiResponse = true;
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
      if (MedilinkApi.instance.isConfigured) {
        hasApiResponse = true;
        apiDoctors = [];
        apiSpecialties = [];
      }
    } finally {
      if (mounted) setState(() => loadingApi = false);
    }
  }

  List<Map<String, dynamic>> get filteredDoctors {
    final doctors = MedilinkApi.instance.isConfigured && !hasApiResponse
        ? <Map<String, dynamic>>[]
        : hasApiResponse
            ? apiDoctors
            : List<Map<String, dynamic>>.from(
                LiveState.recommendedDoctors['doctors'] as List,
              );
    return doctors.where((doctor) {
      final query = search.text.trim().toLowerCase();
      final modes = (doctor['modes'] as List? ?? const [])
          .map((value) => value == 'home' ? 'domicile' : 'téléconsultation');
      final districts =
          (doctor['serviceDistricts'] as List? ?? const []).join(' ');
      final matchesQuery = query.isEmpty ||
          '${doctor['name']} ${doctor['specialty']} ${doctor['serviceCity']} $districts'
              .toLowerCase()
              .contains(query);
      return matchesQuery &&
          (specialty == 'Toutes' || doctor['specialty'] == specialty) &&
          (city == 'Toutes' || doctor['serviceCity'] == city) &&
          (mode == 'Tous' || modes.contains(mode.toLowerCase()));
    }).toList();
  }

  List<String> get cityOptions {
    final values = (hasApiResponse
            ? apiDoctors
            : LiveState.recommendedDoctors['doctors'] as List)
        .whereType<Map>()
        .map((doctor) => doctor['serviceCity']?.toString() ?? '')
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    return ['Toutes', ...values];
  }

  List<String> get specialtyOptions {
    final values = MedilinkApi.instance.isConfigured
        ? apiSpecialties
        : LiveState.specialties;
    return ['Toutes', ...values.toSet()];
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final doctors = filteredDoctors;
    final activeFilters = [
      specialty != 'Toutes',
      city != 'Toutes',
      mode != 'Tous'
    ].where((active) => active).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text('Trouver un médecin',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Recherchez selon votre besoin et votre zone.'),
        if (loadingApi) const LinearProgressIndicator(),
        if (apiError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chargement impossible : $apiError',
                  style: Theme.of(context).textTheme.bodySmall),
              TextButton.icon(
                  onPressed: loadingApi ? null : _loadDoctors,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Réessayer'))
            ]),
          ),
        const SizedBox(height: 18),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => MedilinkApi.instance.isConfigured
              ? _loadDoctors()
              : setState(() {}),
          decoration: InputDecoration(
            hintText: 'Nom, spécialité ou ville',
            prefixIcon: const Icon(LineAwesomeIcons.search_solid),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    onPressed: () {
                      search.clear();
                      setState(() {});
                    },
                    icon: const Icon(LineAwesomeIcons.times_solid),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openFilters,
          icon: const Icon(LineAwesomeIcons.sliders_h_solid),
          label: Text(activeFilters == 0
              ? 'Filtrer les résultats'
              : 'Filtres appliqués ($activeFilters)'),
        ),
        const SizedBox(height: 12),
        Text('${doctors.length} médecin(s)',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (doctors.isEmpty && loadingApi)
          const Padding(
              padding: EdgeInsets.all(42),
              child: Center(child: CircularProgressIndicator()))
        else if (doctors.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 42),
            child: Center(
                child: Text('Aucun médecin ne correspond à ces filtres.')),
          )
        else
          ...doctors.map(_doctorCard),
      ],
    );
  }

  Widget _doctorCard(Map<String, dynamic> doctor) {
    final modes = (doctor['modes'] as List? ?? const [])
        .map((value) => value == 'home' ? 'À domicile' : 'Téléconsultation')
        .join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const CircleAvatar(child: Icon(LineAwesomeIcons.stethoscope_solid)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(doctor['name'].toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(doctor['specialty'].toString(),
                      style: const TextStyle(color: AppTheme.textSecondary)),
                ])),
            const Icon(LineAwesomeIcons.check_circle_solid,
                color: AppTheme.primary),
          ]),
          const SizedBox(height: 12),
          Text(
              '${doctor['serviceCity']} · ${doctor['yearsOfExperience']} ans d’expérience'),
          const SizedBox(height: 5),
          Text(
              '$modes · ${doctor['rating']} ★ (${doctor['reviewsCount']} avis)',
              style: const TextStyle(color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
                child: Text('${doctor['consultationFee']} XAF',
                    style: const TextStyle(fontWeight: FontWeight.w700))),
            TextButton.icon(
              onPressed: () => _showDoctorDetails(doctor),
              icon: const Icon(LineAwesomeIcons.external_link_alt_solid,
                  size: 18),
              label: const Text('Voir le profil'),
            ),
          ]),
        ]),
      ),
    );
  }

  Future<void> _openFilters() async {
    var nextSpecialty = specialty;
    var nextCity = city;
    var nextMode = mode;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => SafeArea(
                  child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                          child: Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(4)))),
                      const SizedBox(height: 18),
                      Text('Filtres de recherche',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: nextSpecialty,
                        decoration:
                            const InputDecoration(labelText: 'Spécialité'),
                        items: specialtyOptions
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) => setSheetState(
                            () => nextSpecialty = value ?? 'Toutes'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: nextCity,
                        decoration: const InputDecoration(labelText: 'Ville'),
                        items: cityOptions
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setSheetState(() => nextCity = value ?? 'Toutes'),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: nextMode,
                        decoration: const InputDecoration(
                            labelText: 'Mode de consultation'),
                        items: const ['Tous', 'Domicile', 'Téléconsultation']
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setSheetState(() => nextMode = value ?? 'Tous'),
                      ),
                      const SizedBox(height: 18),
                      Row(children: [
                        Expanded(
                            child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    specialty = 'Toutes';
                                    city = 'Toutes';
                                    mode = 'Tous';
                                  });
                                  if (MedilinkApi.instance.isConfigured)
                                    _loadDoctors();
                                  Navigator.pop(sheetContext);
                                },
                                child: const Text('Tout effacer'))),
                        const SizedBox(width: 10),
                        Expanded(
                            child: FilledButton(
                                onPressed: () {
                                  setState(() {
                                    specialty = nextSpecialty;
                                    city = nextCity;
                                    mode = nextMode;
                                  });
                                  if (MedilinkApi.instance.isConfigured)
                                    _loadDoctors();
                                  Navigator.pop(sheetContext);
                                },
                                child: const Text('Afficher les résultats'))),
                      ]),
                    ]),
              ))),
    );
  }

  Future<void> _showDoctorDetails(Map<String, dynamic> doctor) async {
    var details = doctor;
    if (MedilinkApi.instance.isConfigured) {
      try {
        details =
            await MedilinkApi.instance.doctorDetail(doctor['id'].toString());
      } catch (_) {
        // Keep the directory result visible if the optional detail request fails.
      }
      if (!mounted) return;
    }
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
                child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(details['name'].toString(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(details['specialty'].toString(),
                        style: const TextStyle(color: AppTheme.primary)),
                    const SizedBox(height: 14),
                    Text(details['bio']?.toString().isNotEmpty == true
                        ? details['bio'].toString()
                        : 'Aucune présentation renseignée.'),
                    const SizedBox(height: 12),
                    Text(
                        '${details['professionalAddress'] ?? details['serviceCity'] ?? 'Secteur non renseigné'} · ${details['consultationFee'] ?? 0} ${details['currency'] ?? 'XAF'}'),
                    const SizedBox(height: 8),
                    Text(
                        '${details['rating'] ?? '—'} ★ · ${details['reviewsCount'] ?? 0} avis'),
                    const SizedBox(height: 16),
                    const Text(
                        'Choisissez un créneau pour envoyer une demande au médecin.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                        onPressed: () async {
                          final sheetNavigator = Navigator.of(context);
                          final scaffoldMessenger =
                              ScaffoldMessenger.of(context);
                          final selected = await showDialog<_BookingSelection>(
                            context: context,
                            builder: (dialogContext) => _BookingDialog(
                              doctor: details,
                            ),
                          );
                          if (selected == null || !mounted) return;
                          try {
                            if (!MedilinkApi.instance.isConfigured) {
                              throw const MedilinkApiException(
                                  'API_BASE_URL n’est pas configurée.');
                            }
                            await MedilinkApi.instance.appointmentCreate({
                                'doctorId': details['id'].toString(),
                                'scheduledAt':
                                    selected.date.toUtc().toIso8601String(),
                                'timeZone': 'Africa/Douala',
                                'consultationMode': selected.mode,
                                'reason': selected.reason,
                              });
                            if (sheetNavigator.mounted) sheetNavigator.pop();
                            scaffoldMessenger.showSnackBar(SnackBar(
                              content: const Text(
                                  'Demande de rendez-vous envoyée.'),
                            ));
                            widget.onAppointmentCreated?.call();
                          } catch (exception) {
                            scaffoldMessenger.showSnackBar(SnackBar(
                              content:
                                  Text('Impossible de réserver : $exception'),
                            ));
                          }
                        },
                        icon: const Icon(LineAwesomeIcons.calendar_plus_solid),
                        label: const Text('Prendre rendez-vous')),
                  ]),
            )));
  }
}

class _BookingSelection {
  const _BookingSelection({
    required this.date,
    required this.mode,
    required this.reason,
  });

  final DateTime date;
  final String mode;
  final String reason;
}

class _BookingDialog extends StatefulWidget {
  const _BookingDialog({required this.doctor});

  final Map<String, dynamic> doctor;

  @override
  State<_BookingDialog> createState() => _BookingDialogState();
}

class _BookingDialogState extends State<_BookingDialog> {
  DateTime date = DateTime.now().add(const Duration(days: 1));
  late String mode;
  final reason = TextEditingController();
  TimeOfDay time = const TimeOfDay(hour: 10, minute: 0);

  static const weekdays = <int, String>{
    DateTime.monday: 'monday',
    DateTime.tuesday: 'tuesday',
    DateTime.wednesday: 'wednesday',
    DateTime.thursday: 'thursday',
    DateTime.friday: 'friday',
    DateTime.saturday: 'saturday',
    DateTime.sunday: 'sunday',
  };

  List<String> get availableModes {
    final configured = (widget.doctor['modes'] as List? ?? const [])
        .map((value) => value.toString())
        .where((value) => value == 'home' || value == 'teleconsultation')
        .toList();
    if (configured.isEmpty && !MedilinkApi.instance.isConfigured) {
      return ['teleconsultation', 'home'];
    }
    return configured;
  }

  List<Map<String, dynamic>> _matchingSlots(DateTime selectedDate) {
    final day = weekdays[selectedDate.weekday];
    final blocked = (widget.doctor['blockedDates'] as List? ?? const []).any(
        (value) => value.toString().startsWith(
            '${selectedDate.year.toString().padLeft(4, '0')}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'));
    if (blocked) return [];
    return (widget.doctor['availability'] as List? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .where((slot) =>
            slot['isAvailable'] == true &&
            slot['weekday']?.toString().toLowerCase() == day)
        .toList();
  }

  bool get slotAvailable {
    final selectedDateTime =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!selectedDateTime.isAfter(DateTime.now())) return false;
    if (!MedilinkApi.instance.isConfigured) return true;
    final chosen = time.hour * 60 + time.minute;
    final duration =
        (widget.doctor['appointmentDurationMinutes'] as num?)?.toInt() ?? 30;
    return _matchingSlots(date).any((slot) {
      final start = _minutes(slot['startTime']?.toString());
      final end = _minutes(slot['endTime']?.toString());
      return start != null &&
          end != null &&
          chosen >= start &&
          chosen + duration <= end;
    });
  }

  int? _minutes(String? value) {
    final pieces = value?.split(':') ?? const [];
    if (pieces.length < 2) return null;
    final hour = int.tryParse(pieces[0]);
    final minute = int.tryParse(pieces[1]);
    return hour == null || minute == null ? null : hour * 60 + minute;
  }

  @override
  void initState() {
    super.initState();
    mode = availableModes.isEmpty ? '' : availableModes.first;
  }

  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Demander un rendez-vous'),
        content: SingleChildScrollView(
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date et heure'),
              subtitle:
                  Text(MaterialLocalizations.of(context).formatFullDate(date)),
              trailing: const Icon(Icons.calendar_month),
              onTap: () async {
                final pickedDate = await showDatePicker(
                  context: context,
                  initialDate: date,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 90)),
                );
                if (pickedDate == null || !context.mounted) return;
                final pickedTime = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(date),
                );
                if (pickedTime == null) return;
                setState(() {
                  date = DateTime(
                    pickedDate.year,
                    pickedDate.month,
                    pickedDate.day,
                  );
                  time = pickedTime;
                });
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Heure'),
              subtitle: Text(time.format(context)),
              trailing: const Icon(Icons.schedule),
              onTap: () async {
                final value =
                    await showTimePicker(context: context, initialTime: time);
                if (value != null) setState(() => time = value);
              },
            ),
            if (MedilinkApi.instance.isConfigured &&
                _matchingSlots(date).isEmpty)
              const Padding(
                  padding: EdgeInsets.only(bottom: 8),
                  child: Text(
                      'Aucune plage disponible à cette date. Choisissez une autre journée.',
                      style: TextStyle(color: Colors.deepOrange))),
            if (MedilinkApi.instance.isConfigured &&
                _matchingSlots(date).isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                      'Horaires : ${_matchingSlots(date).map((slot) => '${slot['startTime']}–${slot['endTime']}').join(', ')}',
                      style: const TextStyle(color: AppTheme.textSecondary))),
            if (availableModes.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: Text(
                    'Aucun mode de consultation n’est disponible pour ce médecin.'),
              )
            else
              DropdownButtonFormField<String>(
                value: mode,
                decoration: const InputDecoration(labelText: 'Mode'),
                items: availableModes
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(value == 'home'
                              ? 'À domicile'
                              : 'Téléconsultation'),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => mode = value ?? mode),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: reason,
              decoration: const InputDecoration(
                labelText: 'Motif (facultatif)',
              ),
              maxLines: 2,
            ),
          ],
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: availableModes.isEmpty || !slotAvailable
                ? null
                : () => Navigator.pop(
                      context,
                      _BookingSelection(
                        date: DateTime(date.year, date.month, date.day,
                            time.hour, time.minute),
                        mode: mode,
                        reason: reason.text.trim(),
                      ),
                    ),
            child: const Text('Confirmer'),
          ),
        ],
      );
}
