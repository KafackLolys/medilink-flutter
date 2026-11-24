import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../auth/application/demo_session_controller.dart';
import '../../appointments/presentation/appointments_screen.dart';
import '../../doctors/presentation/doctors_screen.dart';
import '../../needs/presentation/needs_screen.dart';
import '../../messaging/presentation/messages_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../doctor/presentation/proposals_screen.dart';
import 'dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.auth});
  final DemoSessionController auth;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  @override
  Widget build(BuildContext context) {
    final doctor = widget.auth.role == 'doctor';
    final pages = <Widget>[
      DashboardScreen(auth: widget.auth),
      doctor ? NeedsScreen(doctor: true) : const DoctorsScreen(),
      doctor ? const ProposalsScreen() : NeedsScreen(doctor: false),
      MessagesScreen(doctor: doctor),
      AppointmentsScreen(doctor: doctor),
    ];
    final labels = doctor
        ? const ['Accueil', 'Besoins', 'Propositions', 'Messages', 'Agenda']
        : const ['Accueil', 'Médecins', 'Besoins', 'Messages', 'Rendez-vous'];
    final icons = const [
      LucideIcons.house,
      LucideIcons.stethoscope,
      LucideIcons.clipboardList,
      LucideIcons.messageCircle,
      LucideIcons.calendarDays,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xffe7f2fb),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                LucideIcons.heartPulse,
                color: Color(0xff1769aa),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'MedLink',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.3),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const NotificationsScreen()));
              if (mounted) setState(() {});
            },
            icon: Badge(
              label: Text('${NotificationsScreen.unreadCount}'),
              isLabelVisible: NotificationsScreen.unreadCount > 0,
              child: const Icon(LucideIcons.bell),
            ),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => widget.auth.signOut(),
            icon: const Icon(LucideIcons.logOut),
          ),
        ],
      ),
      body: IndexedStack(index: selected, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (v) => setState(() => selected = v),
        destinations: List.generate(
          5,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
      floatingActionButton: !doctor && selected == 2
          ? FloatingActionButton.extended(
              onPressed: () =>
                  createNeed(context, onCreated: () => setState(() {})),
              icon: const Icon(LucideIcons.plus),
              label: const Text('Nouveau besoin'),
            )
          : null,
    );
  }
}
