import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/live_state.dart';
import '../../../core/theme/app_theme.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key, required this.doctor});
  final bool doctor;
  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  String filter = 'Tous';
  final search = TextEditingController();
  bool loadingApi = false;
  bool hasApiResponse = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) _loadAppointments();
  }

  Future<void> _loadAppointments() async {
    setState(() => loadingApi = true);
    try {
      final response = await MedilinkApi.instance.get(
        widget.doctor ? 'appointments/v2/doctor' : 'appointments/v2',
      );
      final raw = response is List
          ? response
          : response is Map
              ? response['items']
              : null;
      final rows = raw is List
          ? raw
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList()
          : <Map<String, dynamic>>[];
      if (!widget.doctor) {
        for (final row in rows.where((item) => item['status'] == 'completed')) {
          try {
            row['review'] = await MedilinkApi.instance.get(
              'appointments/v2/${Uri.encodeComponent(row['id'].toString())}/review',
            );
          } catch (_) {
            row['review'] = null;
          }
        }
      }
      final destination = widget.doctor
          ? LiveState.doctorAppointments
          : LiveState.patientAppointments;
      destination
        ..clear()
        ..addAll(rows);
      hasApiResponse = true;
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
      hasApiResponse = true;
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
            ? LiveState.doctorAppointments
            : LiveState.patientAppointments;
    final rows = source.where((row) {
      final doctor = row['doctor'] as Map<String, dynamic>?;
      final text =
          '${row['patient'] ?? ''} ${doctor?['name'] ?? ''} ${doctor?['specialty'] ?? ''}'
              .toLowerCase();
      final queryMatches = text.contains(search.text.trim().toLowerCase());
      final rawStatus = row['status']?.toString();
      final statusMatches = filter == 'Tous' ||
          switch (filter) {
            'À confirmer' ||
            'En attente' =>
              rawStatus == 'pending_confirmation',
            'Confirmé' => rawStatus == 'confirmed',
            'Terminé' => rawStatus == 'completed',
            'Annulé' => rawStatus == 'cancelled' ||
                (widget.doctor && rawStatus == 'no_show'),
            'Refusé' => rawStatus == 'rejected',
            'Absent' => rawStatus == 'no_show',
            _ => false,
          };
      return queryMatches && statusMatches;
    }).toList();
    final filters = widget.doctor
        ? const [
            'Tous',
            'À confirmer',
            'Confirmé',
            'Terminé',
            'Annulé',
            'Refusé'
          ]
        : const [
            'Tous',
            'En attente',
            'Confirmé',
            'Terminé',
            'Annulé',
            'Refusé',
            'Absent'
          ];
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        children: [
          Text(widget.doctor ? 'Mon agenda' : 'Mes rendez-vous',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
          if (loadingApi) const LinearProgressIndicator(),
          if (apiError != null)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Chargement impossible : $apiError'),
                      TextButton.icon(
                          onPressed: loadingApi ? null : _loadAppointments,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'))
                    ])),
          const SizedBox(height: 14),
          TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                  hintText: 'Rechercher une consultation',
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
                          onSelected: (_) => setState(() => filter = value),
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 10),
          if (rows.isEmpty && loadingApi)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()))
          else if (rows.isEmpty)
            const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: Text('Aucun rendez-vous correspondant.')))
          else
            ...rows.map((row) {
              final doctor = row['doctor'] as Map<String, dynamic>?;
              final title = widget.doctor
                  ? row['patient']?.toString() ?? 'Patient'
                  : doctor?['name']?.toString() ?? 'Consultation';
              final date = widget.doctor
                  ? '${row['date']} · ${row['time']}'
                  : _format(row['scheduledAt']?.toString());
              final detail = widget.doctor
                  ? '${row['district'] ?? 'Lieu à confirmer'} · ${row['mode'] ?? ''}'
                  : '${doctor?['specialty'] ?? ''} · ${_status(row['status']?.toString())}';
              return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: CircleAvatar(
                        backgroundColor: (widget.doctor ? const Color(0xff2563eb) : AppTheme.primary).withOpacity(.1),
                        child: const Icon(LineAwesomeIcons.calendar_check_solid,
                            color: (widget.doctor ? const Color(0xff2563eb) : AppTheme.primary))),
                    title: Text(title,
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text('$date\n$detail')),
                    isThreeLine: true,
                    trailing: widget.doctor
                        ? Chip(label: Text(_status(row['status']?.toString())))
                        : const Icon(LineAwesomeIcons.angle_right_solid,
                            size: 18),
                    onTap: () => _showDetail(row, title, date, detail),
                  ));
            }),
          const SizedBox(height: 8),
        ]));
  }

  void _showDetail(
      Map<String, dynamic> row, String title, String date, String detail) {
    showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 10),
                      Text(
                          '$date\n$detail\nStatut : ${_status(row['status']?.toString())}'),
                      const SizedBox(height: 16),
                      if (!widget.doctor && row['status'] == 'completed')
                        if (row['review'] == null)
                          FilledButton.icon(
                            onPressed: () => _review(row),
                            icon: const Icon(LineAwesomeIcons.star_solid),
                            label: const Text('Noter cette consultation'),
                          )
                        else
                          Chip(
                            avatar: const Icon(LineAwesomeIcons.star_solid,
                                size: 16),
                            label: Text(
                                'Avis envoyé · ${row['review']['rating']}/5'),
                          ),
                      if (widget.doctor &&
                          row['status'] == 'pending_confirmation')
                        Wrap(spacing: 8, children: [
                          OutlinedButton(
                              onPressed: () => _updateStatus(row, 'rejected'),
                              child: const Text('Refuser')),
                          FilledButton(
                              onPressed: () => _updateStatus(row, 'confirmed'),
                              child: const Text('Confirmer')),
                        ]),
                      if (widget.doctor && row['status'] == 'confirmed')
                        Wrap(spacing: 8, children: [
                          FilledButton(
                              onPressed: () => _updateStatus(row, 'completed'),
                              child: const Text('Marquer terminé')),
                        ]),
                    ]))));
  }

  Future<void> _updateStatus(
    Map<String, dynamic> appointment,
    String status,
  ) async {
    try {
      await MedilinkApi.instance
          .appointmentUpdateStatus(appointment['id'].toString(), status);
      if (!mounted) return;
      setState(() => appointment['status'] = status);
      await _loadAppointments();
      Navigator.pop(context);
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mise à jour impossible : $exception')),
      );
    }
  }

  Future<void> _review(Map<String, dynamic> appointment) async {
    var rating = 5;
    final comment = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Évaluer la consultation'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                    5,
                    (index) => IconButton(
                          tooltip: 'Note ${index + 1}/5',
                          onPressed: () =>
                              setDialogState(() => rating = index + 1),
                          icon: Icon(LineAwesomeIcons.star_solid,
                              color: index < rating
                                  ? const Color(0xfff2a900)
                                  : Colors.black26),
                        ))),
            TextField(
                controller: comment,
                maxLength: 2000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                    labelText: 'Votre commentaire (facultatif)')),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Plus tard')),
            FilledButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, comment.text.trim()),
                child: const Text('Envoyer l’avis')),
          ],
        ),
      ),
    );
    comment.dispose();
    if (result == null || !mounted) return;
    try {
      await MedilinkApi.instance.appointmentSubmitReview(
        appointment['id'].toString(),
        rating: rating,
        comment: result.isEmpty ? null : result,
      );
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Envoi de l’avis impossible : $exception')),
      );
      return;
    }
    setState(() => appointment['review'] = {
          'rating': rating,
          'comment': result,
          'createdAt': DateTime.now().toUtc().toIso8601String()
        });
  }

  String _format(String? raw) {
    final date = DateTime.tryParse(raw ?? '')?.toLocal();
    return date == null
        ? 'Date à confirmer'
        : '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  String _status(String? value) => switch (value) {
        'pending_confirmation' => widget.doctor ? 'À confirmer' : 'En attente',
        'confirmed' => 'Confirmé',
        'completed' => 'Terminé',
        'cancelled' => 'Annulé',
        'rejected' => 'Refusé',
        'no_show' => widget.doctor ? 'Annulé' : 'Absent',
        null || '' => 'À confirmer',
        _ => value.replaceAll('_', ' '),
      };
}
