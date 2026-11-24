import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/demo_data.dart';
import '../../../core/theme/app_theme.dart';

class DoctorsScreen extends StatefulWidget {
  const DoctorsScreen({super.key});

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  final search = TextEditingController();
  String specialty = 'Toutes';
  String city = 'Toutes';
  String mode = 'Tous';
  List<Map<String, dynamic>> apiDoctors = [];
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
      final response = await MedilinkApi.instance.get('doctors/v2');
      final raw = response is Map ? response['doctors'] ?? response['items'] : response;
      apiDoctors = raw is List
          ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
      hasApiResponse = true;
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
    } finally {
      if (mounted) setState(() => loadingApi = false);
    }
  }

  List<Map<String, dynamic>> get filteredDoctors {
    final doctors = hasApiResponse
        ? apiDoctors
        : List<Map<String, dynamic>>.from(
            DemoData.recommendedDoctors['doctors'] as List,
          );
    return doctors.where((doctor) {
      final query = search.text.trim().toLowerCase();
      final modes = (doctor['modes'] as List? ?? const [])
          .map((value) => value == 'home' ? 'domicile' : 'téléconsultation');
      final matchesQuery = query.isEmpty ||
          '${doctor['name']} ${doctor['specialty']} ${doctor['serviceCity']}'
              .toLowerCase()
              .contains(query);
      return matchesQuery &&
          (specialty == 'Toutes' || doctor['specialty'] == specialty) &&
          (city == 'Toutes' || doctor['serviceCity'] == city) &&
          (mode == 'Tous' || modes.contains(mode.toLowerCase()));
    }).toList();
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
            child: Text('API indisponible · données template affichées.',
                style: Theme.of(context).textTheme.bodySmall),
          ),
        const SizedBox(height: 18),
        TextField(
          controller: search,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Nom, spécialité ou ville',
            prefixIcon: const Icon(LucideIcons.search),
            suffixIcon: search.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Effacer',
                    onPressed: () {
                      search.clear();
                      setState(() {});
                    },
                    icon: const Icon(LucideIcons.x),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _openFilters,
          icon: const Icon(LucideIcons.slidersHorizontal),
          label: Text(activeFilters == 0
              ? 'Filtrer les résultats'
              : 'Filtres appliqués ($activeFilters)'),
        ),
        const SizedBox(height: 12),
        Text('${doctors.length} médecin(s)',
            style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        if (doctors.isEmpty)
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
            const CircleAvatar(child: Icon(LucideIcons.stethoscope)),
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
            const Icon(LucideIcons.badgeCheck, color: AppTheme.primary),
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
              icon: const Icon(LucideIcons.arrowUpRight, size: 18),
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
                        items: ['Toutes', ...DemoData.specialties]
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
                        items: const ['Toutes', 'Yaoundé']
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
                                  Navigator.pop(sheetContext);
                                },
                                child: const Text('Afficher les résultats'))),
                      ]),
                    ]),
              ))),
    );
  }

  void _showDoctorDetails(Map<String, dynamic> doctor) {
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
                    Text(doctor['name'].toString(),
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    Text(doctor['specialty'].toString(),
                        style: const TextStyle(color: AppTheme.primary)),
                    const SizedBox(height: 14),
                    Text(doctor['bio'].toString()),
                    const SizedBox(height: 12),
                    Text(
                        '${doctor['professionalAddress']} · ${doctor['consultationFee']} XAF'),
                    const SizedBox(height: 16),
                    const Text(
                        'Mode démonstration : la réservation sera simulée.'),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(LucideIcons.calendarPlus),
                        label: const Text('Prendre rendez-vous')),
                  ]),
            )));
  }
}
