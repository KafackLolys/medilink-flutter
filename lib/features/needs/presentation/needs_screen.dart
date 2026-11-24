import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/demo_data.dart';
import '../../doctor/presentation/proposals_screen.dart';

class NeedsScreen extends StatefulWidget {
  const NeedsScreen({super.key, required this.doctor});
  final bool doctor;

  @override
  State<NeedsScreen> createState() => _NeedsScreenState();
}

class _NeedsScreenState extends State<NeedsScreen> {
  final search = TextEditingController();
  String filter = 'Tous';
  bool hasApiResponse = false;
  bool loadingApi = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) _loadNeeds();
  }

  Future<void> _loadNeeds() async {
    setState(() => loadingApi = true);
    try {
      final response = await MedilinkApi.instance.get(
        widget.doctor ? 'needs/v2/doctor' : 'needs/v2',
      );
      final raw = widget.doctor && response is Map
          ? response['items']
          : response is List
              ? response
              : response is Map
                  ? response['items']
                  : null;
      final items = raw is List
          ? raw.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList()
          : <Map<String, dynamic>>[];
      if (widget.doctor) {
        DemoData.doctorNeeds['items'] = items;
      } else {
        DemoData.patientNeeds
          ..clear()
          ..addAll(items);
      }
      hasApiResponse = true;
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
    } finally {
      if (mounted) setState(() => loadingApi = false);
    }
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final source = widget.doctor
        ? List<Map<String, dynamic>>.from(DemoData.doctorNeeds['items'] as List)
        : DemoData.patientNeeds;
    final rows = source.where((row) {
      final query = search.text.trim().toLowerCase();
      final matchesQuery = query.isEmpty ||
          '${row['title']} ${row['specialty']} ${row['city'] ?? ''}'
              .toLowerCase()
              .contains(query);
      if (!matchesQuery) return false;
      if (filter == 'Tous') return true;
      if (widget.doctor) {
        if (filter == 'Routine') return row['priority'] == 'routine';
        if (filter == 'Urgent')
          return row['priority'] == 'urgent' || row['priority'] == 'emergency';
        if (filter == 'Domicile') return row['mode'] == 'home';
        if (filter == 'Téléconsultation')
          return row['mode'] == 'teleconsultation';
      } else {
        if (filter == 'En attente')
          return row['status'] == 'awaiting_proposals';
        if (filter == 'Propositions reçues')
          return row['status'] == 'proposals_received';
        if (filter == 'Confirmé')
          return row['status'] == 'appointment_confirmed' ||
              row['status'] == 'confirmed';
      }
      return true;
    }).toList();
    final filters = widget.doctor
        ? ['Tous', 'Routine', 'Urgent', 'Domicile', 'Téléconsultation']
        : ['Tous', 'En attente', 'Propositions reçues', 'Confirmé'];

    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(widget.doctor ? 'Demandes de patients' : 'Mes besoins médicaux',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: const Color(0xff17324d))),
          const SizedBox(height: 14),
      if (loadingApi) const LinearProgressIndicator(),
      if (apiError != null)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: Text('API indisponible · données template affichées.'),
        ),
          TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  hintText: 'Rechercher par titre, spécialité ou ville',
                  prefixIcon: Icon(LucideIcons.search))),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters
                  .map((value) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(value),
                          selected: filter == value,
                          onSelected: (_) => setState(() => filter = value),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text('${rows.length} résultat(s)',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (rows.isEmpty)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: Text('Aucun besoin ne correspond à ces critères.')))
          else
            ...rows.map((row) => NeedCard(row: row, doctor: widget.doctor)),
        ]);
  }
}

class NeedCard extends StatelessWidget {
  const NeedCard({super.key, required this.row, required this.doctor});
  final Map<String, dynamic> row;
  final bool doctor;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row['title']?.toString() ?? 'Besoin médical',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (row['priority'] != null)
                    Chip(
                        label:
                            Text(_priorityLabel(row['priority'].toString()))),
                ],
              ),
              Text(
                '${row['specialty'] ?? ''} • ${row['city'] ?? row['mode'] ?? ''}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (row['summary'] != null || row['description'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    (row['summary'] ?? row['description']).toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Chip(label: Text(_statusLabel(row['status']?.toString()))),
                  const Spacer(),
                  if (!doctor) Text('${row['interested'] ?? 0} intéressé(s)'),
                ],
              ),
              if (!doctor && ((row['interested'] as num?) ?? 0) > 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PatientProposalsScreen(
                          needId: row['id']?.toString() ?? '',
                        ),
                      ),
                    ),
                    icon: const Icon(LucideIcons.arrowUpRight, size: 18),
                    label: const Text('Voir les propositions'),
                  ),
                ),
              if (doctor)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showDemoProposal(context, row),
                    icon: const Icon(LucideIcons.send),
                    label: const Text('Faire une proposition'),
                  ),
                ),
            ],
          ),
        ),
      );

  Future<void> _showDemoProposal(
      BuildContext context, Map<String, dynamic> need) async {
    final message = TextEditingController();
    final fee = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Proposer un rendez-vous'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: message,
                decoration: const InputDecoration(labelText: 'Message'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Message requis'
                    : null,
              ),
              TextFormField(
                controller: fee,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Honoraires'),
                validator: (value) => double.tryParse(value ?? '') == null
                    ? 'Montant invalide'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const Text('Prévisualiser'),
          ),
        ],
      ),
    );
    final messageText = message.text.trim();
    final feeValue = double.tryParse(fee.text) ?? 0;
    message.dispose();
    fee.dispose();

    if (sent == true && context.mounted) {
      final proposedAt = DateTime.now().add(const Duration(days: 2));
      dynamic apiResult;
      if (MedilinkApi.instance.isConfigured) {
        try {
          apiResult = await MedilinkApi.instance.post(
            'needs/v2/doctor/${Uri.encodeComponent(need['id'].toString())}/proposals',
            {
              'message': messageText,
              'proposedAppointmentAt': proposedAt.toUtc().toIso8601String(),
              'consultationMode': need['mode'] == 'home'
                  ? 'home'
                  : 'teleconsultation',
              'fee': feeValue.round(),
            },
          );
        } catch (exception) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Envoi de la proposition impossible : $exception')),
          );
          return;
        }
      }
      DemoData.doctorProposals.insert(0, {
        'id': apiResult is Map && apiResult['id'] != null
            ? apiResult['id']
            : 'proposal-demo-${DateTime.now().microsecondsSinceEpoch}',
        'needId': need['id'],
        'needTitle': need['title'],
        'patient': 'Patient Demo',
        'specialty': need['specialty'],
        'message': messageText,
        'scheduledAt': proposedAt.toUtc().toIso8601String(),
        'consultationMode': need['mode'] ?? 'teleconsultation',
        'fee': feeValue.round(),
        'currency': 'XAF',
        'status': MedilinkApi.instance.isConfigured ? 'pending' : 'sent',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proposition enregistrée.'),
        ),
      );
    }
  }
}

Future<void> createNeed(BuildContext context, {VoidCallback? onCreated}) async {
  final title = TextEditingController();
  final description = TextEditingController();
  final district = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String? selectedSpecialty;

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        MediaQuery.of(sheetContext).viewInsets.bottom + 20,
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Décrire mon besoin',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: title,
                decoration: const InputDecoration(labelText: 'Titre'),
                validator: _requiredField,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: selectedSpecialty,
                decoration: const InputDecoration(
                  labelText: 'Spécialité',
                  prefixIcon: Icon(LucideIcons.stethoscope),
                ),
                hint: const Text('Sélectionner une spécialité'),
                items: DemoData.specialties
                    .map((value) => DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        ))
                    .toList(),
                onChanged: (value) => selectedSpecialty = value,
                validator: (value) =>
                    value == null ? 'Sélectionnez une spécialité.' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: district,
                decoration: const InputDecoration(
                  labelText: 'Quartier / district',
                ),
                validator: _requiredField,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: description,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Votre situation'),
                validator: _requiredField,
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate()) {
                    Navigator.pop(sheetContext, true);
                  }
                },
                child: const Text('Prévisualiser'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  final titleValue = title.text.trim();
  final descriptionValue = description.text.trim();
  final specialtyValue = selectedSpecialty?.trim() ?? '';
  final districtValue = district.text.trim();

  title.dispose();
  description.dispose();
  district.dispose();

  if (created == true && context.mounted) {
    final payload = <String, dynamic>{
      'title': titleValue,
      'specialty': specialtyValue,
      'description': descriptionValue,
      'symptoms': <String>[],
      'city': districtValue,
      'district': districtValue,
      'priority': 'normal',
      'mode': 'tele',
      'consent': true,
    };
    Map<String, dynamic>? apiNeed;
    if (MedilinkApi.instance.isConfigured) {
      try {
        final response = await MedilinkApi.instance.postMultipart(
          'needs/v2',
          fields: {'data': jsonEncode(payload)},
        );
        if (response is Map) apiNeed = Map<String, dynamic>.from(response);
      } catch (exception) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible de publier le besoin : $exception')),
        );
        return;
      }
    }
    DemoData.patientNeeds.insert(0, {
      ...?apiNeed,
      'id': 'need-demo-${DateTime.now().microsecondsSinceEpoch}',
      'title': titleValue,
      'specialty': specialtyValue,
      'city': districtValue,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'interested': 0,
      'mode': 'teleconsultation',
      'status': 'awaiting_proposals',
      'attachmentsCount': 0,
      'description': descriptionValue,
      'priority': 'normal',
    });
    if (apiNeed != null && apiNeed['id'] != null) {
      DemoData.patientNeeds[0]['id'] = apiNeed['id'];
    }
    onCreated?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Besoin ajouté à vos demandes de démonstration.'),
      ),
    );
  }
}

String? _requiredField(String? value) =>
    value == null || value.trim().isEmpty ? 'Champ requis' : null;

String _statusLabel(String? status) => switch (status) {
      'awaiting_proposals' => 'En attente',
      'proposals_received' => 'Propositions reçues',
      'appointment_confirmed' || 'confirmed' => 'Confirmé',
      'published' => 'Publiée',
      'closed' => 'Clôturée',
      null || '' => 'Statut à confirmer',
      _ => status.replaceAll('_', ' '),
    };

String _priorityLabel(String priority) => switch (priority) {
      'routine' || 'normal' => 'Normale',
      'urgent' || 'rapide' => 'Rapide',
      'emergency' || 'urgence' => 'Urgente',
      _ => priority,
    };
