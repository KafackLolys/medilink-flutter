import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/services/push_notification_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../appointments/presentation/appointments_screen.dart';
import '../../doctors/presentation/doctors_screen.dart';
import '../../needs/presentation/needs_screen.dart';
import '../../messaging/presentation/messages_screen.dart';
import '../../notifications/presentation/notifications_screen.dart';
import 'patient_profile_screen.dart';
import '../../doctor/presentation/proposals_screen.dart';
import '../../doctor/presentation/doctor_workspace_screen.dart';
import 'dashboard_screen.dart';
import 'admin_accounts_screen.dart';
import 'admin_profile_screen.dart';
import '../../../core/widgets/medilink_logo_mark.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.auth});
  final AuthController auth;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int selected = 0;
  int appointmentRefresh = 0;
  int needsRefresh = 0, proposalsRefresh = 0, messagesRefresh = 0;
  RemoteMessage? _lastHandledPush;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    PushNotificationService.instance.addListener(_onPushUpdate);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshUnreadCount());
      final conversationId =
          PushNotificationService.instance.takePendingConversationId();
      if (conversationId != null) _openConversation(conversationId);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    PushNotificationService.instance.removeListener(_onPushUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshUnreadCount());
    }
  }

  Future<void> _refreshUnreadCount() async {
    await NotificationsScreen.refreshUnreadCount();
    if (mounted) setState(() {});
  }

  String? _openingConversationId;

  Future<void> _openConversation(String conversationId) async {
    if (!mounted || _openingConversationId == conversationId) return;
    _openingConversationId = conversationId;
    try {
      final response = await MedilinkApi.instance.messagesList();
      final raw = response['items'];
      final rows = raw is List ? raw.whereType<Map>() : const <Map>[];
      final match = rows.cast<Map?>().firstWhere(
            (row) => row?['id']?.toString() == conversationId,
            orElse: () => null,
          );
      final matched = match == null
          ? <String, dynamic>{}
          : Map<String, dynamic>.from(match);
      final conversation = <String, dynamic>{
        ...matched,
        'id': conversationId,
        'participantName':
            matched['peerName'] ?? matched['participantName'] ?? 'Conversation',
        'lastMessage': matched['preview'] ?? matched['lastMessage'] ?? '',
        'messages': <Map<String, dynamic>>[],
      };
      if (!mounted) return;
      setState(() => selected = 3);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConversationScreen(
            conversation: conversation,
            doctor: widget.auth.role == 'doctor',
          ),
        ),
      );
    } catch (exception) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ouverture de la conversation impossible : $exception')),
        );
      }
    } finally {
      _openingConversationId = null;
    }
  }

  void _onPushUpdate() {
    if (!mounted) return;
    setState(() {});
    unawaited(_refreshUnreadCount());
    final conversationId =
        PushNotificationService.instance.takePendingConversationId();
    if (conversationId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openConversation(conversationId);
      });
    }
    final latest = PushNotificationService.instance.latestForegroundMessage;
    if (latest != null && latest != _lastHandledPush) {
      _lastHandledPush = latest;
      final title = latest.notification?.title ??
          latest.data['title']?.toString() ??
          'Notification MedLink';
      final body = latest.notification?.body ??
          latest.data['body']?.toString() ??
          '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              if (body.isNotEmpty) Text(body),
            ],
          ),
          action: SnackBarAction(
            label: 'Voir',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const NotificationsScreen()),
              );
            },
          ),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.auth.role == 'admin') return _adminShell();
    final doctor = widget.auth.role == 'doctor';
    final pages = <Widget>[
      DashboardScreen(auth: widget.auth),
      doctor
          ? NeedsScreen(
              key: ValueKey('doctor-needs-$needsRefresh'), doctor: true)
          : DoctorsScreen(onAppointmentCreated: _showAppointments),
      doctor
          ? ProposalsScreen(key: ValueKey('doctor-proposals-$proposalsRefresh'))
          : NeedsScreen(
              key: ValueKey('patient-needs-$needsRefresh'), doctor: false),
      MessagesScreen(
          key: ValueKey('messages-$messagesRefresh'), doctor: doctor),
      AppointmentsScreen(key: ValueKey(appointmentRefresh), doctor: doctor),
    ];
    final labels = doctor
        ? const ['Accueil', 'Besoins', 'Propositions', 'Messages', 'Agenda']
        : const ['Accueil', 'Médecins', 'Besoins', 'Messages', 'Rendez-vous'];
    final icons = const [
      LineAwesomeIcons.home_solid,
      LineAwesomeIcons.stethoscope_solid,
      LineAwesomeIcons.clipboard_list_solid,
      LineAwesomeIcons.comment_dots_solid,
      LineAwesomeIcons.calendar_alt_solid,
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
              child: const MedilinkLogoMark(size: 20),
            ),
            const SizedBox(width: 10),
            const Text(
              'MedLink',
              style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -.3),
            ),
          ],
        ),
        actions: [
          if (!doctor)
            IconButton(
              tooltip: 'Profil et dossier médical',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PatientProfileScreen(
                    user:
                        Map<String, dynamic>.from(widget.auth.user ?? const {}),
                  ),
                ),
              ),
              icon: const Icon(LineAwesomeIcons.user_circle_solid),
            ),
          if (doctor)
            IconButton(
              tooltip: 'Profil et disponibilités',
              onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const DoctorWorkspaceScreen())),
              icon: const Icon(LineAwesomeIcons.user_md_solid),
            ),
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
              label: Text(
                  '${NotificationsScreen.unreadCount}'),
              isLabelVisible: NotificationsScreen.unreadCount > 0,
              child: const Icon(LineAwesomeIcons.bell_solid),
            ),
          ),
          IconButton(
            tooltip: 'Déconnexion',
            onPressed: () => widget.auth.signOut(),
            icon: const Icon(LineAwesomeIcons.sign_out_alt_solid),
          ),
        ],
      ),
      body: _bodyWithStartupStatus(
        IndexedStack(index: selected, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (v) => setState(() {
          selected = v;
          if (v == 1 && doctor) needsRefresh++;
          if (v == 2 && doctor) proposalsRefresh++;
          if (v == 2 && !doctor) needsRefresh++;
          if (v == 3) messagesRefresh++;
          if (v == 4) appointmentRefresh++;
        }),
        destinations: List.generate(
          5,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
      floatingActionButton: !doctor && selected == 2
          ? FloatingActionButton.extended(
              onPressed: () =>
                  createNeed(context, onCreated: () => setState(() {})),
              icon: const Icon(LineAwesomeIcons.plus_solid),
              label: const Text('Nouveau besoin'),
            )
          : null,
    );
  }

  Widget _adminShell() => Scaffold(
        appBar: AppBar(
          title: const Row(children: [
            MedilinkLogoMark(size: 22),
            SizedBox(width: 8),
            Text('MedLink · Administration',
                style: TextStyle(fontWeight: FontWeight.w800)),
          ]),
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
                    label: Text(
                        '${NotificationsScreen.unreadCount}'),
                    isLabelVisible: NotificationsScreen.unreadCount > 0,
                    child: const Icon(LineAwesomeIcons.bell_solid))),
            IconButton(
                tooltip: 'Déconnexion',
                onPressed: widget.auth.signOut,
                icon: const Icon(LineAwesomeIcons.sign_out_alt_solid)),
          ],
        ),
        body: _bodyWithStartupStatus(
          IndexedStack(index: selected.clamp(0, 1), children: [
            AdminAccountsScreen(auth: widget.auth),
            AdminProfileScreen(auth: widget.auth)
          ]),
        ),
        bottomNavigationBar: NavigationBar(
            selectedIndex: selected.clamp(0, 1),
            onDestinationSelected: (v) => setState(() => selected = v),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.manage_accounts_outlined), label: 'Comptes'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline), label: 'Mon profil')
            ]),
      );

  Widget _bodyWithStartupStatus(Widget child) => Column(
        children: [
          if (widget.auth.startupError != null)
            MaterialBanner(
              backgroundColor: const Color(0xfffff4e5),
              leading: const Icon(Icons.cloud_off, color: Color(0xff9a5b00)),
              content: Text(widget.auth.startupError!),
              actions: [
                TextButton(
                  onPressed: widget.auth.checkingBackend
                      ? null
                      : widget.auth.retryBackendConnection,
                  child: Text(widget.auth.checkingBackend
                      ? 'Vérification…'
                      : 'Réessayer'),
                ),
              ],
            ),
          Expanded(child: child),
        ],
      );

  void _showAppointments() {
    if (!mounted) return;
    setState(() {
      selected = 4;
      appointmentRefresh++;
    });
  }
}
