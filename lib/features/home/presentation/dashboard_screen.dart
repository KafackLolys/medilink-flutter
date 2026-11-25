import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../appointments/presentation/appointments_screen.dart';
import '../../auth/application/auth_controller.dart';
import '../../doctors/presentation/doctors_screen.dart';
import '../../needs/presentation/needs_screen.dart';
import 'patient_profile_screen.dart';
import '../../doctor/presentation/doctor_workspace_screen.dart';
import '../../doctor/presentation/proposals_screen.dart';
import '../../../core/api/medilink_api.dart';
import '../../../core/data/live_state.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Text(
            'Bonjour' + (auth.name.isEmpty ? '' : ', ' + auth.name),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff17324d),
                  letterSpacing: -.4,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            auth.role == 'doctor'
                ? 'Votre espace médecin'
                : 'Votre espace santé',
          ),
          if (auth.role == 'doctor') ...[
            const SizedBox(height: 14),
            const _DoctorOverview(),
          ],
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xff1769aa), Color(0xff238ac4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xff1769aa).withOpacity(.18),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.16),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'VOTRE SANTÉ, EN CONFIANCE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        auth.role == 'doctor'
                            ? 'Accompagnez vos patients.'
                            : 'Un accompagnement de santé, plus simple.',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        auth.role == 'doctor'
                            ? 'Consultez les demandes et proposez votre expertise.'
                            : 'Décrivez votre besoin pour recevoir des propositions adaptées.',
                        style: const TextStyle(
                          color: Color(0xffe5f4ff),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    LineAwesomeIcons.heartbeat_solid,
                    color: Colors.white,
                    size: 25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Vos raccourcis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xff17324d),
                ),
          ),
          const SizedBox(height: 12),
          if (auth.role != 'doctor')
            quick(context, 'Trouver un médecin', 'Profils et spécialités',
                LineAwesomeIcons.search_solid, const DoctorsScreen()),
          quick(
            context,
            'Mes besoins médicaux',
            'Demandes et propositions',
            LineAwesomeIcons.clipboard_list_solid,
            NeedsScreen(doctor: auth.role == 'doctor'),
          ),
          if (auth.role == 'doctor') ...[
            quick(context, 'Mes propositions', 'Suivre ou annuler vos offres',
                LineAwesomeIcons.paper_plane_solid, const ProposalsScreen()),
            quick(
                context,
                'Profil et disponibilités',
                'Vérification, horaires et zone',
                LineAwesomeIcons.user_md_solid,
                const DoctorWorkspaceScreen()),
          ],
          quick(
            context,
            'Rendez-vous',
            'Consultez votre agenda',
            LineAwesomeIcons.calendar_alt_solid,
            AppointmentsScreen(doctor: auth.role == 'doctor'),
          ),
          if (auth.role == 'patient')
            quick(
              context,
              'Profil et dossier médical',
              'Informations, conditions et documents',
              LineAwesomeIcons.folder_open_solid,
              PatientProfileScreen(
                user: Map<String, dynamic>.from(auth.user ?? const {}),
              ),
            ),
        ],
      );
  Widget quick(
    BuildContext c,
    String title,
    String sub,
    IconData icon,
    Widget page,
  ) =>
      Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(title),
          subtitle: Text(sub),
          trailing: const Icon(LineAwesomeIcons.angle_right_solid),
          onTap: () =>
              Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
        ),
      );
}

class _DoctorOverview extends StatefulWidget {
  const _DoctorOverview();
  @override
  State<_DoctorOverview> createState() => _DoctorOverviewState();
}

class _DoctorOverviewState extends State<_DoctorOverview> {
  bool loading = false;
  String verification = 'À vérifier';
  String? loadError;
  int openNeeds = 0, proposals = 0, appointments = 0;

  @override
  void initState() {
    super.initState();
    if (!MedilinkApi.instance.isConfigured) {
      openNeeds = (LiveState.doctorNeeds['items'] as List).length;
      proposals = LiveState.doctorProposals.length;
      appointments = LiveState.doctorAppointments
          .where((row) =>
              row['status'] == 'pending_confirmation' ||
              row['status'] == 'confirmed')
          .length;
    }
    _load();
  }

  Future<void> _load() async {
    if (!MedilinkApi.instance.isConfigured) return;
    setState(() => loading = true);
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
      final values = await Future.wait<Object?>([
        safe(MedilinkApi.instance.doctorMe()),
        safe(MedilinkApi.instance.needsForDoctor(page: 1, pageSize: 1)),
        safe(MedilinkApi.instance.needsProposals(page: 1, pageSize: 1)),
        safe(MedilinkApi.instance.appointmentsForDoctor()),
      ]);
      final needPage =
          values[1] is Map ? values[1] as Map : const <String, dynamic>{};
      final proposalPage = values[2];
      final proposalItems =
          proposalPage is Map ? proposalPage['items'] : proposalPage;
      final appointmentsList = values[3] is List ? values[3] as List : const [];
      if (!mounted) return;
      setState(() {
        if (values[0] is Map)
          verification =
              '${(values[0] as Map)['verificationStatus'] ?? 'pending'}';
        if (values[1] is Map)
          openNeeds = (needPage['total'] as num?)?.toInt() ??
              (needPage['items'] as List? ?? []).length;
        if (proposalPage is Map)
          proposals = (proposalPage['total'] as num?)?.toInt() ??
              (proposalItems is List ? proposalItems.length : 0);
        if (values[3] is List)
          appointments = appointmentsList
              .where((a) =>
                  a is Map &&
                  (a['status'] == 'pending_confirmation' ||
                      a['status'] == 'confirmed'))
              .length;
        loadError = failures.isEmpty
            ? null
            : 'Certaines données ne sont pas accessibles.';
      });
    } catch (e) {
      loadError = '$e';
      openNeeds = 0;
      proposals = 0;
      appointments = 0;
      verification = 'Inconnue';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Text('Vue d’ensemble',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16))),
              if (loading)
                const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
            ]),
            const SizedBox(height: 6),
            Text('Vérification : ${_status(verification)}',
                style: const TextStyle(color: Color(0xff52677a))),
            if (loadError != null)
              Text(loadError!,
                  style:
                      const TextStyle(color: Colors.deepOrange, fontSize: 12)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _metric('$openNeeds', 'Besoins')),
              Expanded(child: _metric('$proposals', 'Propositions')),
              Expanded(child: _metric('$appointments', 'Rendez-vous'))
            ]),
          ]),
        ),
      );

  Widget _metric(String value, String label) => Column(children: [
        Text(value,
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xff1769aa))),
        Text(label, style: const TextStyle(fontSize: 12))
      ]);
  String _status(String value) => switch (value) {
        'verified' => 'Vérifié',
        'rejected' => 'Refusé',
        'pending' => 'En attente',
        _ => value
      };
}
