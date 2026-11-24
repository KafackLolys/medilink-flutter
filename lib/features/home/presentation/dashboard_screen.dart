import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../appointments/presentation/appointments_screen.dart';
import '../../auth/application/demo_session_controller.dart';
import '../../doctors/presentation/doctors_screen.dart';
import '../../needs/presentation/needs_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.auth});
  final DemoSessionController auth;
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
                    LucideIcons.heartPulse,
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
          quick(
            context,
            'Trouver un médecin',
            'Profils et spécialités',
            LucideIcons.search,
            const DoctorsScreen(),
          ),
          quick(
            context,
            'Mes besoins médicaux',
            'Demandes et propositions',
            LucideIcons.clipboardList,
            NeedsScreen(doctor: auth.role == 'doctor'),
          ),
          quick(
            context,
            'Rendez-vous',
            'Consultez votre agenda',
            LucideIcons.calendarDays,
            AppointmentsScreen(doctor: auth.role == 'doctor'),
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
          trailing: const Icon(LucideIcons.chevronRight),
          onTap: () =>
              Navigator.push(c, MaterialPageRoute(builder: (_) => page)),
        ),
      );
}
