import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/live_state.dart';
import '../../../core/theme/app_theme.dart';

class ProposalsScreen extends StatefulWidget {
  const ProposalsScreen({super.key});

  @override
  State<ProposalsScreen> createState() => _ProposalsScreenState();
}

class _ProposalsScreenState extends State<ProposalsScreen> {
  String status = '';
  int page = 1, totalPages = 1;
  List<Map<String, dynamic>> proposals = LiveState.doctorProposals;
  bool loading = false;
  bool hasApiResponse = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response = await MedilinkApi.instance.needsProposals(
          status: status.isEmpty ? null : status, page: page, pageSize: 10);
      final raw = response['items'];
      totalPages = (response['totalPages'] as num?)?.toInt() ?? 1;
      proposals = raw is List
          ? raw.whereType<Map>().map((row) {
              final item = Map<String, dynamic>.from(row);
              return {
                ...item,
                'patient': item['patient'] ?? 'Patient',
                'scheduledAt':
                    item['proposedAppointmentAt'] ?? item['proposedAt'],
              };
            }).toList()
          : <Map<String, dynamic>>[];
      apiError = null;
      hasApiResponse = true;
    } catch (exception) {
      apiError = exception.toString();
      if (MedilinkApi.instance.isConfigured) hasApiResponse = true;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = MedilinkApi.instance.isConfigured &&
            (apiError != null || !hasApiResponse)
        ? <Map<String, dynamic>>[]
        : proposals
            .where((row) => status.isEmpty || row['status'] == status)
            .toList();
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xffe5f5ff), Color(0xffedf3ff)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xffdbe6f7)),
            ),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.85),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.assignment_turned_in_outlined,
                    color: Color(0xff2563eb), size: 26),
              ),
              const SizedBox(width: 13),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vos propositions',
                        style: TextStyle(
                            color: Color(0xff172554),
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                    SizedBox(height: 3),
                    Text('Suivez les échanges et les réponses de vos patients.',
                        style: TextStyle(color: Color(0xff64748b), height: 1.3)),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Text('Mes propositions',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Suivez les réponses envoyées aux patients.'),
          if (loading) const LinearProgressIndicator(),
          if (apiError != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chargement impossible : $apiError'),
                      TextButton.icon(
                          onPressed: loading ? null : _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'))
                    ])),
          const SizedBox(height: 14),
          Wrap(
              spacing: 8,
              children: const {
                '': 'Toutes',
                'sent': 'Envoyée',
                'pending': 'En attente',
                'accepted': 'Acceptée',
                'rejected': 'Refusée',
                'expired': 'Expirée',
                'cancelled': 'Annulée'
              }
                  .entries
                  .map((entry) => ChoiceChip(
                      label: Text(entry.value),
                      selected: status == entry.key,
                      onSelected: (_) {
                        setState(() {
                          status = entry.key;
                          page = 1;
                        });
                        if (MedilinkApi.instance.isConfigured) _load();
                      }))
                  .toList()),
          const SizedBox(height: 10),
          if (rows.isEmpty && loading)
            const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()))
          else if (rows.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child:
                    Center(child: Text('Aucune proposition dans ce statut.')))
          else
            ...rows.map((row) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                                child: Text(
                                    (row['needTitle'] ?? 'Besoin médical')
                                        .toString(),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700))),
                            Chip(label: Text(_label(row['status'].toString())))
                          ]),
                          Text(
                              '${row['patient'] ?? 'Patient'} · ${row['specialty'] ?? ''}'),
                          const SizedBox(height: 8),
                          Text(
                              '${_format(row['scheduledAt']?.toString())} · ${row['consultationMode'] == 'home' ? 'À domicile' : 'Téléconsultation'}'),
                          const SizedBox(height: 4),
                          Text('${row['fee']} ${row['currency'] ?? 'XAF'}',
                              style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontWeight: FontWeight.w700)),
                          if (row['status'] == 'sent' ||
                              row['status'] == 'pending')
                            Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                    onPressed: () => _cancel(row),
                                    icon: const Icon(
                                        LineAwesomeIcons.times_circle,
                                        size: 18),
                                    label:
                                        const Text('Annuler la proposition'))),
                        ])))),
          const SizedBox(height: 8),
          if (MedilinkApi.instance.isConfigured && page < totalPages)
            Center(
                child: TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            page++;
                            _load();
                          },
                    child: const Text('Charger plus'))),
        ]));
  }

  Future<void> _cancel(Map<String, dynamic> row) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Annuler cette proposition ?'),
                content: const Text('Cette action annulera la proposition.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Garder')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Annuler'))
                ]));
    if (confirmed != true || !mounted) return;
    try {
      await MedilinkApi.instance.needCancelProposal(row['id'].toString());
      await _load();
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Annulation impossible : $exception')));
    }
  }

  String _label(String status) => switch (status) {
        'pending' => 'En attente',
        'sent' => 'Envoyée',
        'cancelled' => 'Annulée',
        'accepted' => 'Acceptée',
        'rejected' => 'Refusée',
        'expired' => 'Expirée',
        _ => status
      };
  String _format(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    return date == null
        ? 'Date à confirmer'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
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
  bool hasApiResponse = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    proposals = LiveState.patientProposals
        .where((row) => row['needId'] == widget.needId)
        .toList();
    if (MedilinkApi.instance.isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response = await MedilinkApi.instance
          .get('needs/v2/${Uri.encodeComponent(widget.needId)}/proposals');
      final raw = response is Map ? response['items'] : null;
      proposals = raw is List
          ? raw.whereType<Map>().map((row) {
              final item = Map<String, dynamic>.from(row);
              final doctor = item['doctor'] is Map
                  ? Map<String, dynamic>.from(item['doctor'] as Map)
                  : <String, dynamic>{};
              return {
                ...item,
                'doctorName': doctor['name'] ?? 'Médecin',
                'specialty': doctor['specialty'] ?? '',
                'scheduledAt': item['proposedAppointmentAt']
              };
            }).toList()
          : <Map<String, dynamic>>[];
      apiError = null;
      hasApiResponse = true;
    } catch (exception) {
      apiError = exception.toString();
      if (MedilinkApi.instance.isConfigured) hasApiResponse = true;
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Propositions reçues')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          if (loading) const LinearProgressIndicator(),
          if (apiError != null)
            Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child:
                    Text('Chargement des propositions impossible : $apiError')),
          if (MedilinkApi.instance.isConfigured && !hasApiResponse && loading)
            const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()))
          else if ((MedilinkApi.instance.isConfigured &&
                  (apiError != null || !hasApiResponse)) ||
              proposals.isEmpty)
            const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('Aucune proposition à afficher.')))
          else
            ...proposals.map((row) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text((row['doctorName'] ?? 'Médecin').toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          Text((row['specialty'] ?? '').toString(),
                              style: const TextStyle(color: AppTheme.primary)),
                          const SizedBox(height: 8),
                          Text((row['message'] ?? '').toString()),
                          const SizedBox(height: 8),
                          Text(
                              '${row['fee']} ${row['currency'] ?? 'XAF'} · ${_format(row['scheduledAt']?.toString())}'),
                          const SizedBox(height: 12),
                          if (row['status'] == 'sent' ||
                              row['status'] == 'pending')
                            Row(children: [
                              Expanded(
                                  child: FilledButton.icon(
                                      onPressed: () => _accept(row),
                                      icon: const Icon(
                                          LineAwesomeIcons.check_solid,
                                          size: 18),
                                      label: const Text('Accepter'))),
                            ]),
                          if (row['status'] != 'sent' &&
                              row['status'] != 'pending')
                            Chip(
                                label: Text(row['status'] == 'accepted'
                                    ? 'Acceptée'
                                    : 'Déclinée')),
                        ])))),
        ]),
      );

  Future<void> _accept(Map<String, dynamic> row) async {
    try {
      await MedilinkApi.instance
          .needAcceptProposal(widget.needId, row['id'].toString());
      if (!mounted) return;
      setState(() => row['status'] = 'accepted');
      try {
        final appointments = await MedilinkApi.instance.appointmentsList();
        LiveState.patientAppointments
          ..clear()
          ..addAll(appointments);
      } catch (_) {
        // The server action succeeded; appointments reload when the tab opens.
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Proposition acceptée et rendez-vous créé.')));
      Navigator.pop(context, true);
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossible d’accepter : $exception')));
    }
  }

  String _format(String? value) {
    final date = DateTime.tryParse(value ?? '')?.toLocal();
    return date == null
        ? 'Date à confirmer'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')} à ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
