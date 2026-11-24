import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/demo_data.dart';
import '../../../core/theme/app_theme.dart';

class ProposalsScreen extends StatefulWidget {
  const ProposalsScreen({super.key});

  @override
  State<ProposalsScreen> createState() => _ProposalsScreenState();
}

class _ProposalsScreenState extends State<ProposalsScreen> {
  String status = 'Toutes';
  List<Map<String, dynamic>> proposals = DemoData.doctorProposals;
  bool loading = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response = await MedilinkApi.instance.get('needs/v2/doctor/proposals');
      final raw = response is Map ? response['items'] : null;
      proposals = raw is List
          ? raw.whereType<Map>().map((row) {
              final item = Map<String, dynamic>.from(row);
              return {
                ...item,
                'patient': item['patient'] ?? 'Patient',
                'scheduledAt': item['proposedAppointmentAt'] ?? item['proposedAt'],
              };
            }).toList()
          : <Map<String, dynamic>>[];
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = proposals.where((row) => status == 'Toutes' || _label(row['status'].toString()) == status).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 28), children: [
      Text('Mes propositions', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Suivez les réponses envoyées aux patients.'),
      if (loading) const LinearProgressIndicator(),
      if (apiError != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('API indisponible · propositions template affichées.')),
      const SizedBox(height: 14),
      Wrap(spacing: 8, children: ['Toutes', 'En attente', 'Envoyées', 'Annulées'].map((value) => ChoiceChip(label: Text(value), selected: status == value, onSelected: (_) => setState(() => status = value))).toList()),
      const SizedBox(height: 10),
      if (rows.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: Text('Aucune proposition dans ce statut.')))
      else ...rows.map((row) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text((row['needTitle'] ?? 'Besoin médical').toString(), style: const TextStyle(fontWeight: FontWeight.w700))), Chip(label: Text(_label(row['status'].toString())))]),
        Text('${row['patient'] ?? 'Patient'} · ${row['specialty'] ?? ''}'),
        const SizedBox(height: 8),
        Text('${_format(row['scheduledAt']?.toString())} · ${row['consultationMode'] == 'home' ? 'À domicile' : 'Téléconsultation'}'),
        const SizedBox(height: 4),
        Text('${row['fee']} ${row['currency'] ?? 'XAF'}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w700)),
        if (row['status'] == 'sent' || row['status'] == 'pending') Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _cancel(row), icon: const Icon(LucideIcons.circleX, size: 18), label: const Text('Annuler la proposition'))),
      ])))),
      const SizedBox(height: 8),
      const Text('Données template conservées si l’API n’est pas configurée.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ]);
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Annuler cette proposition ?'), content: const Text('Cette action annulera la proposition.'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Garder')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Annuler'))]));
    if (confirmed != true || !mounted) return;
    try {
      if (MedilinkApi.instance.isConfigured) await MedilinkApi.instance.patch('needs/v2/doctor/proposals/${Uri.encodeComponent(row['id'].toString())}/cancel');
      if (mounted) setState(() => row['status'] = 'cancelled');
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Annulation impossible : $exception')));
    }
  }

  String _label(String status) => switch (status) {'pending' => 'En attente', 'sent' => 'Envoyée', 'cancelled' => 'Annulée', 'accepted' => 'Acceptée', 'rejected' => 'Refusée', 'expired' => 'Expirée', _ => status};
  String _format(String? value) { final date = DateTime.tryParse(value ?? '')?.toLocal(); return date == null ? 'Date à confirmer' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'; }
}

class PatientProposalsScreen extends StatefulWidget {
  const PatientProposalsScreen({super.key, required this.needId});
  final String needId;

  @override
  State<PatientProposalsScreen> createState() => _PatientProposalsScreenState();
}

class _PatientProposalsScreenState extends State<PatientProposalsScreen> {
  late List<Map<String, dynamic>> proposals;
  bool loading = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    proposals = DemoData.patientProposals.where((row) => row['needId'] == widget.needId).toList();
    if (MedilinkApi.instance.isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response = await MedilinkApi.instance.get('needs/v2/${Uri.encodeComponent(widget.needId)}/proposals');
      final raw = response is Map ? response['items'] : null;
      proposals = raw is List ? raw.whereType<Map>().map((row) {
        final item = Map<String, dynamic>.from(row);
        final doctor = item['doctor'] is Map ? Map<String, dynamic>.from(item['doctor'] as Map) : <String, dynamic>{};
        return {...item, 'doctorName': doctor['name'] ?? 'Médecin', 'specialty': doctor['specialty'] ?? '', 'scheduledAt': item['proposedAppointmentAt']};
      }).toList() : <Map<String, dynamic>>[];
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Propositions reçues')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      if (loading) const LinearProgressIndicator(),
      if (apiError != null) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('API indisponible · propositions template affichées.')),
      if (proposals.isEmpty) const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Aucune proposition reçue pour ce besoin.')))
      else ...proposals.map((row) => Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((row['doctorName'] ?? 'Médecin').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
        Text((row['specialty'] ?? '').toString(), style: const TextStyle(color: AppTheme.primary)),
        const SizedBox(height: 8),
        Text((row['message'] ?? '').toString()),
        const SizedBox(height: 8),
        Text('${row['fee']} ${row['currency'] ?? 'XAF'} · ${_format(row['scheduledAt']?.toString())}'),
        const SizedBox(height: 12),
        if (row['status'] == 'sent' || row['status'] == 'pending') Row(children: [
          if (!MedilinkApi.instance.isConfigured) Expanded(child: OutlinedButton(onPressed: () => setState(() => row['status'] = 'rejected'), child: const Text('Décliner'))),
          if (!MedilinkApi.instance.isConfigured) const SizedBox(width: 8),
          Expanded(child: FilledButton.icon(onPressed: () => _accept(row), icon: const Icon(LucideIcons.check, size: 18), label: const Text('Accepter'))),
        ]),
        if (row['status'] != 'sent' && row['status'] != 'pending') Chip(label: Text(row['status'] == 'accepted' ? 'Acceptée' : 'Déclinée')),
      ])))),
      const Padding(padding: EdgeInsets.only(top: 8), child: Text('Les réponses sont locales sans API configurée.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12))),
    ]),
  );

  Future<void> _accept(Map<String, dynamic> row) async {
    try {
      Map<String, dynamic>? result;
      if (MedilinkApi.instance.isConfigured) {
        final response = await MedilinkApi.instance.patch('needs/v2/${Uri.encodeComponent(widget.needId)}/proposals/${Uri.encodeComponent(row['id'].toString())}/accept');
        if (response is Map) result = Map<String, dynamic>.from(response);
      }
      if (!mounted) return;
      setState(() {
        row['status'] = 'accepted';
        DemoData.patientAppointments.insert(0, {
          'id': result?['appointmentId'] ?? 'appointment-demo-${DateTime.now().microsecondsSinceEpoch}',
          'doctor': {'id': row['doctor'] is Map ? row['doctor']['id'] : row['doctorId'], 'name': row['doctorName'], 'specialty': row['specialty'], 'professionalAddress': 'Yaoundé'},
          'scheduledAt': row['scheduledAt'],
          'durationMinutes': 30,
          'consultationMode': row['consultationMode'] ?? 'teleconsultation',
          'status': 'confirmed',
          'fee': row['fee'],
          'currency': row['currency'] ?? 'XAF',
          'reason': 'Rendez-vous issu d’une proposition',
        });
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(MedilinkApi.instance.isConfigured ? 'Proposition acceptée.' : 'Rendez-vous ajouté à la démonstration.')));
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Impossible d’accepter : $exception')));
    }
  }

  String _format(String? value) { final date = DateTime.tryParse(value ?? '')?.toLocal(); return date == null ? 'Date à confirmer' : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'; }
}
