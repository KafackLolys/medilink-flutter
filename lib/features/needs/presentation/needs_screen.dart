import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/live_state.dart';
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
  String specialty = 'Toutes';
  int page = 1, totalPages = 1;
  List<String> doctorSpecialties = [];
  bool hasApiResponse = false;
  bool loadingApi = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) _loadNeeds();
  }

  Future<void> _loadNeeds({bool append = false}) async {
    setState(() => loadingApi = true);
    try {
      final Map<String, dynamic> response;
      if (widget.doctor && filter == 'Urgent') {
        final results = await Future.wait([
          MedilinkApi.instance.needsForDoctor(
              q: search.text.trim(),
              specialty: specialty == 'Toutes' ? null : specialty,
              priority: 'urgent',
              page: page,
              pageSize: 5),
          MedilinkApi.instance.needsForDoctor(
              q: search.text.trim(),
              specialty: specialty == 'Toutes' ? null : specialty,
              priority: 'emergency',
              page: page,
              pageSize: 5),
        ]);
        final urgentRows = results[0]['items'] as List? ?? [];
        final emergencyRows = results[1]['items'] as List? ?? [];
        final total = ((results[0]['total'] as num?)?.toInt() ?? 0) +
            ((results[1]['total'] as num?)?.toInt() ?? 0);
        response = {
          ...results[0],
          'items': [...urgentRows, ...emergencyRows],
          'total': total,
          'totalPages': (total / 10).ceil()
        };
      } else if (widget.doctor) {
        response = await MedilinkApi.instance.needsForDoctor(
          q: search.text.trim().isEmpty ? null : search.text.trim(),
          specialty: specialty == 'Toutes' ? null : specialty,
          priority: filter == 'Routine' ? 'routine' : null,
          mode: filter == 'Domicile'
              ? 'home'
              : filter == 'Téléconsultation'
                  ? 'teleconsultation'
                  : null,
          page: page,
          pageSize: 10,
        );
      } else {
        final value = await MedilinkApi.instance.get('needs/v2');
        response =
            value is Map ? Map<String, dynamic>.from(value) : {'items': value};
      }
      final raw = response['items'];
      final items = raw is List
          ? raw
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : <Map<String, dynamic>>[];
      if (widget.doctor) {
        doctorSpecialties = (response['specialties'] as List? ?? [])
            .map((v) => v.toString())
            .toList();
        totalPages = (response['totalPages'] as num?)?.toInt() ?? 1;
        final existing = append
            ? List<Map<String, dynamic>>.from(
                LiveState.doctorNeeds['items'] as List)
            : <Map<String, dynamic>>[];
        final ids = existing.map((r) => r['id']).toSet();
        LiveState.doctorNeeds['items'] = [
          ...existing,
          ...items.where((r) => !ids.contains(r['id']))
        ];
      } else {
        LiveState.patientNeeds
          ..clear()
          ..addAll(items);
      }
      hasApiResponse = true;
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
      if (MedilinkApi.instance.isConfigured) hasApiResponse = true;
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
    final source = MedilinkApi.instance.isConfigured &&
            (apiError != null || !hasApiResponse)
        ? <Map<String, dynamic>>[]
        : widget.doctor
            ? List<Map<String, dynamic>>.from(
                LiveState.doctorNeeds['items'] as List)
            : LiveState.patientNeeds;
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
        if (filter == 'En cours')
          return row['status'] == 'published' ||
              row['status'] == 'awaiting_proposals' ||
              row['status'] == 'proposals_received';
        if (filter == 'Confirmées')
          return row['status'] == 'appointment_confirmed' ||
              row['status'] == 'confirmed';
        if (filter == 'Brouillons') return row['status'] == 'draft';
        if (filter == 'Clôturées')
          return row['status'] == 'closed' || row['status'] == 'cancelled';
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
        : ['Tous', 'En cours', 'Confirmées', 'Brouillons', 'Clôturées'];

    return ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(widget.doctor ? 'Demandes de patients' : 'Mes besoins médicaux',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800, color: const Color(0xff17324d))),
          const SizedBox(height: 14),
          if (loadingApi) const LinearProgressIndicator(),
          if (apiError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chargement impossible : $apiError'),
                    TextButton.icon(
                        onPressed: loadingApi ? null : () => _loadNeeds(),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'))
                  ]),
            ),
          TextField(
              controller: search,
              onSubmitted: (_) {
                page = 1;
                if (MedilinkApi.instance.isConfigured) {
                  _loadNeeds();
                } else {
                  setState(() {});
                }
              },
              decoration: const InputDecoration(
                  hintText: 'Rechercher par titre, spécialité ou ville',
                  prefixIcon: Icon(LineAwesomeIcons.search_solid))),
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
                          onSelected: (_) {
                            setState(() {
                              filter = value;
                              page = 1;
                            });
                            if (widget.doctor &&
                                MedilinkApi.instance.isConfigured) _loadNeeds();
                          },
                        ),
                      ))
                  .toList(),
            ),
          ),
          if (widget.doctor && doctorSpecialties.isNotEmpty)
            Padding(
                padding: const EdgeInsets.only(top: 10),
                child: DropdownButtonFormField<String>(
                    value: specialty,
                    decoration: const InputDecoration(labelText: 'Spécialité'),
                    items: ['Toutes', ...doctorSpecialties]
                        .toSet()
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    onChanged: (v) {
                      setState(() => specialty = v ?? 'Toutes');
                      page = 1;
                      if (MedilinkApi.instance.isConfigured) _loadNeeds();
                    })),
          const SizedBox(height: 10),
          Text('${rows.length} résultat(s)',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          if (rows.isEmpty && loadingApi)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()))
          else if (rows.isEmpty)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                    child: Text('Aucun besoin ne correspond à ces critères.')))
          else
            ...rows.map((row) => NeedCard(
                  row: row,
                  doctor: widget.doctor,
                  onUpdated: () {
                    if (MedilinkApi.instance.isConfigured) {
                      _loadNeeds();
                    } else {
                      setState(() {});
                    }
                  },
                )),
          if (widget.doctor && page < totalPages)
            Center(
                child: TextButton(
                    onPressed: loadingApi
                        ? null
                        : () {
                            page++;
                            _loadNeeds(append: true);
                          },
                    child: const Text('Charger plus de demandes'))),
        ]);
  }
}

class NeedCard extends StatelessWidget {
  const NeedCard(
      {super.key, required this.row, required this.doctor, this.onUpdated});
  final Map<String, dynamic> row;
  final bool doctor;
  final VoidCallback? onUpdated;

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
              if (!doctor)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.push<bool>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PatientNeedDetailScreen(need: row),
                        ),
                      );
                      if (changed == true) onUpdated?.call();
                    },
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Suivre la demande'),
                  ),
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
                    icon: const Icon(LineAwesomeIcons.external_link_alt_solid,
                        size: 18),
                    label: const Text('Voir les propositions'),
                  ),
                ),
              if (doctor)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _showProposal(context, row),
                    icon: const Icon(LineAwesomeIcons.paper_plane_solid),
                    label: const Text('Faire une proposition'),
                  ),
                ),
            ],
          ),
        ),
      );

  Future<void> _showProposal(
      BuildContext context, Map<String, dynamic> need) async {
    List<String> availableModes = [
      need['mode'] == 'home' ? 'home' : 'teleconsultation'
    ];
    {
      try {
        final profile = await MedilinkApi.instance.doctorMe();
        if (profile['verificationStatus'] != 'verified') {
          if (context.mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text(
                      'Votre compte doit être vérifié avant d’envoyer une proposition. Ajoutez vos justificatifs dans votre profil professionnel.')),
            );
          return;
        }
        final rawModes = profile['modes'];
        if (rawModes is List) {
          final parsed = rawModes
              .map((v) => v is Map ? '${v['mode'] ?? v['name']}' : '$v')
              .where((v) => v == 'home' || v == 'teleconsultation')
              .toSet()
              .toList();
          if (parsed.isNotEmpty) availableModes = parsed;
        }
      } catch (e) {
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Vérification du compte impossible : $e')));
        return;
      }
    }
    final draft = await showDialog<_ProposalDraft>(
        context: context,
        builder: (_) => _ProposalDialog(
            modes: availableModes, initialMode: availableModes.first));
    if (draft != null && context.mounted) {
      {
        try {
          await MedilinkApi.instance.needPropose(
              id: need['id'].toString(),
              message: draft.message,
              details: draft.details.isEmpty ? null : draft.details,
              proposedAppointmentAt: draft.dateTime.toUtc().toIso8601String(),
              consultationMode: draft.mode,
              fee: draft.fee);
        } catch (exception) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content:
                  Text('Envoi de la proposition impossible : $exception')));
          return;
        }
        onUpdated?.call();
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Proposition envoyée au serveur.')));
      }
    }
  }
}

class _ProposalDraft {
  const _ProposalDraft(
      this.message, this.details, this.fee, this.mode, this.dateTime);
  final String message, details, mode;
  final num fee;
  final DateTime dateTime;
}

class _ProposalDialog extends StatefulWidget {
  const _ProposalDialog({required this.modes, required this.initialMode});
  final List<String> modes;
  final String initialMode;
  @override
  State<_ProposalDialog> createState() => _ProposalDialogState();
}

class _ProposalDialogState extends State<_ProposalDialog> {
  final message = TextEditingController(),
      details = TextEditingController(),
      fee = TextEditingController();
  final formKey = GlobalKey<FormState>();
  late DateTime dateTime = DateTime.now().add(const Duration(days: 2));
  late String mode = widget.initialMode;
  @override
  void dispose() {
    message.dispose();
    details.dispose();
    fee.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Proposer un rendez-vous'),
          content: Form(
              key: formKey,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                    controller: message,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration:
                        const InputDecoration(labelText: 'Message au patient'),
                    validator: (v) => v == null || v.trim().length < 10
                        ? 'Saisissez au moins 10 caractères.'
                        : null),
                TextFormField(
                    controller: details,
                    maxLines: 2,
                    maxLength: 2000,
                    decoration: const InputDecoration(
                        labelText: 'Détails complémentaires (facultatif)')),
                TextFormField(
                    controller: fee,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Honoraires (XAF)'),
                    validator: (v) {
                      final n = num.tryParse(v ?? '');
                      return n == null || n < 0 ? 'Montant invalide.' : null;
                    }),
                DropdownButtonFormField<String>(
                    value: mode,
                    decoration: const InputDecoration(
                        labelText: 'Mode de consultation'),
                    items: widget.modes
                        .map((v) => DropdownMenuItem(
                            value: v,
                            child: Text(v == 'home'
                                ? 'À domicile'
                                : 'Téléconsultation')))
                        .toList(),
                    onChanged: (v) => setState(() => mode = v ?? mode)),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        'Date : ${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}'),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: _pickDate),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                        'Heure : ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}'),
                    trailing: const Icon(Icons.schedule),
                    onTap: _pickTime)
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () {
                  if (formKey.currentState!.validate() &&
                      dateTime.isAfter(DateTime.now()))
                    Navigator.pop(
                        context,
                        _ProposalDraft(message.text.trim(), details.text.trim(),
                            num.parse(fee.text), mode, dateTime));
                },
                child: const Text('Envoyer'))
          ]);
  Future<void> _pickDate() async {
    final v = await showDatePicker(
        context: context,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        initialDate: dateTime);
    if (v != null)
      setState(() => dateTime =
          DateTime(v.year, v.month, v.day, dateTime.hour, dateTime.minute));
  }

  Future<void> _pickTime() async {
    final v = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(dateTime));
    if (v != null)
      setState(() => dateTime = DateTime(
          dateTime.year, dateTime.month, dateTime.day, v.hour, v.minute));
  }
}

class PatientNeedDetailScreen extends StatefulWidget {
  const PatientNeedDetailScreen({super.key, required this.need});
  final Map<String, dynamic> need;

  @override
  State<PatientNeedDetailScreen> createState() =>
      _PatientNeedDetailScreenState();
}

class _PatientNeedDetailScreenState extends State<PatientNeedDetailScreen> {
  late Map<String, dynamic> need = Map<String, dynamic>.from(widget.need);
  bool loading = false;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      need =
          await MedilinkApi.instance.needDetail(widget.need['id'].toString());
    } catch (exception) {
      error = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  bool get canEdit => const {
        'draft',
        'published',
        'awaiting_proposals',
        'proposals_received'
      }.contains(need['status']);
  bool get isDraft => need['status'] == 'draft';
  bool get canClose => canEdit && !isDraft;

  Future<void> _edit() async {
    final title = TextEditingController(text: need['title']?.toString());
    final description =
        TextEditingController(text: need['description']?.toString());
    final formKey = GlobalKey<FormState>();
    var specialty = need['specialty']?.toString() ?? LiveState.specialties.first;
    var mode = need['mode'] == 'domicile' ? 'domicile' : 'tele';
    final data = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
                title: const Text('Modifier la demande'),
                content: Form(
                    key: formKey,
                    child: SingleChildScrollView(
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                      TextFormField(
                          controller: title,
                          decoration: const InputDecoration(labelText: 'Titre'),
                          validator: (v) => (v?.trim().length ?? 0) < 5
                              ? 'Minimum 5 caractères.'
                              : null),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          value: specialty,
                          decoration:
                              const InputDecoration(labelText: 'Spécialité'),
                          items: LiveState.specialties
                              .map((v) =>
                                  DropdownMenuItem(value: v, child: Text(v)))
                              .toList(),
                          onChanged: (v) =>
                              setDialogState(() => specialty = v ?? specialty)),
                      const SizedBox(height: 10),
                      TextFormField(
                          controller: description,
                          minLines: 3,
                          maxLines: 5,
                          decoration:
                              const InputDecoration(labelText: 'Description'),
                          validator: (v) => (v?.trim().length ?? 0) < 20
                              ? 'Minimum 20 caractères.'
                              : null),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                          value: mode,
                          decoration: const InputDecoration(labelText: 'Mode'),
                          items: const [
                            DropdownMenuItem(
                                value: 'domicile', child: Text('À domicile')),
                            DropdownMenuItem(
                                value: 'tele', child: Text('Téléconsultation'))
                          ],
                          onChanged: (v) =>
                              setDialogState(() => mode = v ?? mode)),
                    ]))),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: () {
                        if (formKey.currentState!.validate())
                          Navigator.pop(dialogContext, {
                            'title': title.text.trim(),
                            'specialty': specialty,
                            'description': description.text.trim(),
                            'mode': mode
                          });
                      },
                      child: const Text('Enregistrer')),
                ],
              )),
    );
    title.dispose();
    description.dispose();
    if (data == null || !mounted) return;
    setState(() => busy = true);
    try {
      need = await MedilinkApi.instance.needUpdate(
          id: need['id'].toString(),
          title: data['title']!,
          specialty: data['specialty']!,
          description: data['description']!,
          mode: data['mode']!,
        );
      LiveState.patientNeeds
        ..removeWhere((row) => row['id'] == need['id'])
        ..insert(0, need);
      if (mounted) setState(() {});
    } catch (exception) {
      _toast('Modification impossible : $exception');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _closeNeed() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Clôturer cette demande ?'),
              content: const Text(
                  'Les médecins ne pourront plus envoyer de propositions.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Garder ouverte')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Clôturer'))
              ],
            ));
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    try {
      await MedilinkApi.instance.needClose(need['id'].toString());
      need['status'] = 'closed';
      for (final row
          in LiveState.patientNeeds.where((row) => row['id'] == need['id'])) {
        row['status'] = 'closed';
      }
      if (mounted) {
        setState(() {});
        Navigator.pop(context, true);
      }
    } catch (exception) {
      _toast('Clôture impossible : $exception');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _deleteDraft() async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
              title: const Text('Supprimer le brouillon ?'),
              content: const Text('Cette action est définitive.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(c, false),
                    child: const Text('Annuler')),
                FilledButton(
                    onPressed: () => Navigator.pop(c, true),
                    child: const Text('Supprimer'))
              ],
            ));
    if (ok != true || !mounted) return;
    try {
      await MedilinkApi.instance.needDelete(need['id'].toString());
      LiveState.patientNeeds.removeWhere((row) => row['id'] == need['id']);
      if (mounted) Navigator.pop(context, true);
    } catch (exception) {
      _toast('Suppression impossible : $exception');
    }
  }

  Future<void> _openAttachment(Map<String, dynamic> item) async {
    final url = item['downloadUrl']?.toString();
    if (url == null || url.isEmpty) {
      _toast('Le fichier n’est pas disponible.');
      return;
    }
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  void _toast(String value) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Suivi de la demande')),
        body: loading
            ? const Center(child: CircularProgressIndicator())
            : error != null
                ? Center(
                    child: Padding(
                        padding: const EdgeInsets.all(24),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                              onPressed: _load,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Réessayer'))
                        ])))
                : ListView(padding: const EdgeInsets.all(18), children: [
                    Card(
                        child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      need['title']?.toString() ??
                                          'Besoin médical',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                              fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 8, runSpacing: 6, children: [
                                    Chip(
                                        label: Text(
                                            need['specialty']?.toString() ??
                                                '')),
                                    Chip(
                                        label: Text(_statusLabel(
                                            need['status']?.toString()))),
                                    Chip(
                                        label: Text(_priorityLabel(
                                            need['priority']?.toString() ??
                                                'normal')))
                                  ]),
                                  Text(
                                      '${need['city'] ?? ''} · ${need['district'] ?? ''}'),
                                  const Divider(height: 24),
                                  Text(need['description']?.toString() ??
                                      'Aucune description.'),
                                  if ((need['durationDescription'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                            'Depuis : ${need['durationDescription']}')),
                                  if (need['symptoms'] is List &&
                                      (need['symptoms'] as List).isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Wrap(
                                            spacing: 6,
                                            children: (need['symptoms'] as List)
                                                .map((s) => Chip(
                                                    label: Text(s.toString())))
                                                .toList())),
                                  if ((need['privateAddress'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                        padding: const EdgeInsets.only(top: 10),
                                        child: Text(
                                            'Adresse communiquée : ${need['privateAddress']}')),
                                ]))),
                    if ((need['attachments'] as List? ?? const [])
                        .isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('Documents joints',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      for (final attachment
                          in (need['attachments'] as List).whereType<Map>())
                        Card(
                            child: ListTile(
                          leading: const Icon(Icons.attach_file),
                          title: Text(
                              attachment['fileName']?.toString() ?? 'Document'),
                          trailing: const Icon(Icons.open_in_new),
                          onTap: () => _openAttachment(
                              Map<String, dynamic>.from(attachment)),
                        )),
                    ],
                    const SizedBox(height: 12),
                    if ((need['interested'] as num? ?? 0) > 0)
                      FilledButton.icon(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => PatientProposalsScreen(
                                      needId: need['id'].toString()))),
                          icon: const Icon(Icons.markunread_mailbox_outlined),
                          label: Text(
                              'Voir ${need['interested']} proposition(s)')),
                    if (canEdit)
                      OutlinedButton.icon(
                          onPressed: busy ? null : _edit,
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Modifier la demande')),
                    if (canClose)
                      OutlinedButton.icon(
                          onPressed: busy ? null : _closeNeed,
                          icon: const Icon(Icons.close),
                          label: const Text('Clôturer la demande')),
                    if (isDraft)
                      TextButton.icon(
                          onPressed: busy ? null : _deleteDraft,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Supprimer le brouillon')),
                  ]),
      );
}

Future<void> createNeed(BuildContext context, {VoidCallback? onCreated}) async {
  final title = TextEditingController();
  final description = TextEditingController();
  final district = TextEditingController();
  final city = TextEditingController();
  final address = TextEditingController();
  final formKey = GlobalKey<FormState>();
  String? selectedSpecialty;
  String priority = 'normal';
  String mode = 'domicile';
  bool consent = false;
  final symptoms = <String>[];
  final attachments = <PlatformFile>[];
  String? since;
  const symptomOptions = [
    'Fièvre',
    'Douleur',
    'Fatigue',
    'Toux',
    'Maux de tête',
    'Vertiges',
    'Nausées',
    'Autre'
  ];
  const sinceOptions = [
    'Aujourd’hui',
    '2 à 3 jours',
    'Environ une semaine',
    'Plus d’une semaine',
    'Plus d’un mois'
  ];

  final created = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
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
                        validator: (value) => (value?.trim().length ?? 0) < 5
                            ? 'Minimum 5 caractères.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        value: selectedSpecialty,
                        decoration: const InputDecoration(
                          labelText: 'Spécialité',
                          prefixIcon: Icon(LineAwesomeIcons.stethoscope_solid),
                        ),
                        hint: const Text('Sélectionner une spécialité'),
                        items: LiveState.specialties
                            .map((value) => DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                ))
                            .toList(),
                        onChanged: (value) => selectedSpecialty = value,
                        validator: (value) => value == null
                            ? 'Sélectionnez une spécialité.'
                            : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: city,
                        decoration: const InputDecoration(labelText: 'Ville'),
                        validator: _requiredField,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: district,
                        decoration: const InputDecoration(
                          labelText: 'Quartier',
                        ),
                        validator: _requiredField,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: address,
                        decoration: const InputDecoration(
                            labelText: 'Adresse précise (facultatif)'),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: description,
                        minLines: 3,
                        maxLines: 5,
                        decoration:
                            const InputDecoration(labelText: 'Votre situation'),
                        validator: (value) => (value?.trim().length ?? 0) < 20
                            ? 'Décrivez votre situation (20 caractères minimum).'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: since,
                        decoration: const InputDecoration(
                            labelText: 'Depuis quand ? (facultatif)'),
                        items: sinceOptions
                            .map((value) => DropdownMenuItem(
                                value: value, child: Text(value)))
                            .toList(),
                        onChanged: (value) =>
                            setSheetState(() => since = value),
                      ),
                      const SizedBox(height: 12),
                      const Text('Symptômes',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      Wrap(
                          spacing: 7,
                          children: symptomOptions
                              .map((value) => FilterChip(
                                    label: Text(value),
                                    selected: symptoms.contains(value),
                                    onSelected: (selected) => setSheetState(() {
                                      if (selected) {
                                        symptoms.add(value);
                                      } else {
                                        symptoms.remove(value);
                                      }
                                    }),
                                  ))
                              .toList()),
                      const SizedBox(height: 8),
                      const Text('Priorité',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      ...const [
                        (
                          'normal',
                          'Consultation normale · dans les prochains jours'
                        ),
                        ('rapide', 'Prise en charge rapide'),
                        ('urgence', 'Urgence médicale'),
                      ].map((entry) => RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: entry.$1,
                            groupValue: priority,
                            title: Text(entry.$2),
                            onChanged: (value) => setSheetState(
                                () => priority = value ?? priority),
                          )),
                      const Text('Mode de consultation',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      SegmentedButton<String>(
                        segments: const [
                          ButtonSegment(
                              value: 'domicile',
                              label: Text('À domicile'),
                              icon: Icon(Icons.home_outlined)),
                          ButtonSegment(
                              value: 'tele',
                              label: Text('À distance'),
                              icon: Icon(Icons.video_call_outlined)),
                        ],
                        selected: {mode},
                        onSelectionChanged: (values) =>
                            setSheetState(() => mode = values.first),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final selection = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowMultiple: true,
                            withData: true,
                            allowedExtensions: const [
                              'pdf',
                              'jpg',
                              'jpeg',
                              'png',
                              'webp',
                              'heic',
                              'heif'
                            ],
                          );
                          if (selection == null || !sheetContext.mounted)
                            return;
                          final picked = selection.files;
                          if (attachments.length + picked.length > 5) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                    content: Text('Maximum 5 fichiers.')));
                            return;
                          }
                          if (picked.any((file) =>
                              file.bytes == null ||
                              file.bytes!.length > 10 * 1024 * 1024)) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Chaque fichier doit être disponible et ne pas dépasser 10 Mo.')));
                            return;
                          }
                          setSheetState(() => attachments.addAll(picked));
                        },
                        icon: const Icon(Icons.attach_file),
                        label: Text(attachments.isEmpty
                            ? 'Ajouter des documents (facultatif)'
                            : '${attachments.length} fichier(s) ajouté(s)'),
                      ),
                      if (attachments.isNotEmpty)
                        ...attachments.map((file) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.description_outlined),
                              title: Text(file.name,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              trailing: IconButton(
                                  tooltip: 'Retirer',
                                  onPressed: () => setSheetState(
                                      () => attachments.remove(file)),
                                  icon: const Icon(Icons.close)),
                            )),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: consent,
                        title: const Text(
                            'J’accepte de partager ces informations avec les médecins concernés.'),
                        onChanged: (value) =>
                            setSheetState(() => consent = value ?? false),
                      ),
                      const SizedBox(height: 14),
                      FilledButton(
                        onPressed: () {
                          if (formKey.currentState!.validate() && consent) {
                            Navigator.pop(sheetContext, true);
                          } else if (!consent) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Votre accord est nécessaire pour publier.')));
                          }
                        },
                        child: const Text('Publier mon besoin'),
                      ),
                    ],
                  ),
                ),
              ),
            )),
  );

  final titleValue = title.text.trim();
  final descriptionValue = description.text.trim();
  final specialtyValue = selectedSpecialty?.trim() ?? '';
  final districtValue = district.text.trim();
  final cityValue = city.text.trim();
  final addressValue = address.text.trim();

  title.dispose();
  description.dispose();
  district.dispose();
  city.dispose();
  address.dispose();

  if (created == true && context.mounted) {
    final payload = <String, dynamic>{
      'title': titleValue,
      'specialty': specialtyValue,
      'description': descriptionValue,
      'symptoms': symptoms,
      if (since != null) 'since': since,
      'city': cityValue,
      'district': districtValue,
      if (addressValue.isNotEmpty) 'address': addressValue,
      'priority': priority,
      'mode': mode,
      'consent': consent,
    };
    Map<String, dynamic> apiNeed;
    try {
        final response = await MedilinkApi.instance.postMultipart(
          'needs/v2',
          fields: {'data': jsonEncode(payload)},
          files: attachments.map((file) {
            final ext = (file.extension ?? '').toLowerCase();
            final mime = switch (ext) {
              'pdf' => 'application/pdf',
              'jpg' || 'jpeg' => 'image/jpeg',
              'png' => 'image/png',
              'webp' => 'image/webp',
              'heic' => 'image/heic',
              'heif' => 'image/heif',
              _ => 'application/octet-stream',
            };
            return http.MultipartFile.fromBytes('files', file.bytes!,
                filename: file.name, contentType: MediaType.parse(mime));
          }).toList(),
        );
        if (response is! Map) {
          throw const MedilinkApiException('Réponse de création invalide.');
        }
        apiNeed = Map<String, dynamic>.from(response);
      } catch (exception) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Impossible de publier le besoin : $exception')),
        );
        return;
      }
    LiveState.patientNeeds.insert(0, apiNeed);
    onCreated?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Besoin publié avec succès.'),
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
