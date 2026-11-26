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
import '../../../core/widgets/doctor_page_background.dart';

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
      final notification =
          PushNotificationService.instance.takePendingNotificationData();
      if (notification != null) _openNotification(notification);
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

  Future<void> _openNotification(Map<String, dynamic> data) async {
    final type = data['type']?.toString();
    final targetUrl = (data['targetUrl'] ?? data['url'])?.toString() ?? '';
    final uri = Uri.tryParse(targetUrl);
    final conversationId = data['conversationId']?.toString() ??
        uri?.queryParameters['conversation'];

    final path = uri?.path ?? '';
    final isMessagesTarget = path.contains('/messages') ||
        uri?.queryParameters['activeContent'] == 'messages';

    if (isMessagesTarget && conversationId != null &&
        conversationId.isNotEmpty) {
      await _openConversation(conversationId);
      return;
    }

    if (!mounted) return;

    // Les targetUrl sont les mêmes chemins internes que ceux utilisés sur le Web.
    // On les interprète localement : aucun navigateur externe n'est ouvert.
    if (path.startsWith('/medecin/besoins')) {
      setState(() {
        selected = 1;
        needsRefresh++;
      });
      return;
    }
    if (path.startsWith('/patient/demandes')) {
      setState(() {
        selected = 2;
        needsRefresh++;
      });
      return;
    }
    if (path.contains('/rendez-vous')) {
      setState(() {
        selected = 4;
        appointmentRefresh++;
      });
      return;
    }
    if (isMessagesTarget) {
      setState(() {
        selected = 3;
        messagesRefresh++;
      });
      return;
    }

    switch (type) {
      case 'appointment_updated':
        setState(() {
          selected = 4;
          appointmentRefresh++;
        });
        break;
      case 'proposal_received':
        setState(() {
          selected = 2;
          if (widget.auth.role == 'doctor') {
            proposalsRefresh++;
          } else {
            needsRefresh++;
          }
        });
        break;
      case 'proposal_accepted':
        setState(() {
          selected = 4;
          appointmentRefresh++;
        });
        break;
      case 'relevant_need':
        setState(() {
          selected = widget.auth.role == 'doctor' ? 1 : 2;
          needsRefresh++;
        });
        break;
      default:
        setState(() => selected = 0);
    }
  }

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
      await _refreshUnreadCount();
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
    final notification =
        PushNotificationService.instance.takePendingNotificationData();
    if (notification != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openNotification(notification);
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
                    builder: (_) => NotificationsScreen(onNotificationTap: _openNotification)),
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
    final visiblePages = doctor
        ? pages.map((page) => DoctorPageBackground(child: page)).toList()
        : pages;
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
      backgroundColor: doctor ? const Color(0xfff5f7fc) : null,
      appBar: AppBar(
        backgroundColor: doctor ? Colors.white : null,
        surfaceTintColor: doctor ? Colors.transparent : null,
        elevation: doctor ? 0 : null,
        title: Row(
          children: [
            if (doctor)
              const _HeartPulseBrandMark()
            else
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xffe7f2fb),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const MedilinkLogoMark(size: 20),
              ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  doctor ? 'MediLink' : 'MedLink',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: doctor ? const Color(0xff172554) : null,
                    fontSize: doctor ? 18 : null,
                    height: 1.1,
                  ),
                ),
                if (doctor)
                  const Text(
                    'ESPACE MÉDECIN',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(0xff64748b),
                      fontSize: 9,
                      letterSpacing: 1.1,
                    ),
                  ),
              ],
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
            PopupMenuButton<String>(
              tooltip: 'Compte médecin',
              icon: const Icon(LineAwesomeIcons.user_circle_solid),
              onSelected: (value) {
                if (value == 'profile') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const DoctorWorkspaceScreen(),
                    ),
                  );
                } else if (value == 'logout') {
                  _confirmDoctorSignOut();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, color: Color(0xff2563eb)),
                      SizedBox(width: 12),
                      Text('Mon profil'),
                    ],
                  ),
                ),
                PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Color(0xffdc2626)),
                      SizedBox(width: 12),
                      Text('Déconnexion'),
                    ],
                  ),
                ),
              ],
            ),
          if (!doctor)
            IconButton(
              tooltip: 'Déconnexion',
              onPressed: () => widget.auth.signOut(),
              icon: const Icon(LineAwesomeIcons.sign_out_alt_solid),
            ),
          IconButton(
            tooltip: 'Notifications',
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => NotificationsScreen(onNotificationTap: _openNotification)));
              if (mounted) setState(() {});
            },
            icon: Badge(
              label: Text(
                  '${NotificationsScreen.unreadCount}'),
              isLabelVisible: NotificationsScreen.unreadCount > 0,
              child: const Icon(LineAwesomeIcons.bell_solid),
            ),
          ),
        ],
      ),
      body: _bodyWithStartupStatus(
        IndexedStack(index: selected, children: visiblePages),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: doctor ? Colors.white : null,
        surfaceTintColor: doctor ? Colors.transparent : null,
        indicatorColor: doctor ? const Color(0xffeaf1ff) : null,
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
        backgroundColor: const Color(0xfff5f7fc),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Row(children: [
            _HeartPulseBrandMark(),
            SizedBox(width: 9),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MediLink', style: TextStyle(
                    fontWeight: FontWeight.w900, color: Color(0xff172554),
                    fontSize: 18, height: 1.1)),
                Text('ADMINISTRATION', style: TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xff64748b),
                    fontSize: 9, letterSpacing: 1.1)),
              ],
            ),
          ]),
          actions: [
            IconButton(
                tooltip: 'Notifications',
                onPressed: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NotificationsScreen(onNotificationTap: _openNotification)));
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
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            indicatorColor: const Color(0xffeaf1ff),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: selected.clamp(0, 1),
            onDestinationSelected: (v) => setState(() => selected = v),
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.manage_accounts_outlined), label: 'Comptes'),
              NavigationDestination(
                  icon: Icon(Icons.person_outline), label: 'Mon profil')
            ]),
      );

  Future<void> _confirmDoctorSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmer la déconnexion'),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter de votre compte médecin ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffdc2626),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Me déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await widget.auth.signOut();
    }
  }

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


class _HeartPulseBrandMark extends StatelessWidget {
  const _HeartPulseBrandMark();

  @override
  Widget build(BuildContext context) => Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xffeff6ff),
          borderRadius: BorderRadius.circular(13),
        ),
        alignment: Alignment.center,
        child: CustomPaint(
          size: const Size(27, 27),
          painter: _HeartPulsePainter(),
        ),
      );
}

class _HeartPulsePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xff2563eb)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.9
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final heart = Path()
      ..moveTo(size.width / 2, size.height * .86)
      ..cubicTo(size.width * .36, size.height * .72, size.width * .08,
          size.height * .52, size.width * .08, size.height * .31)
      ..cubicTo(size.width * .08, size.height * .10, size.width * .34,
          size.height * .04, size.width / 2, size.height * .23)
      ..cubicTo(size.width * .66, size.height * .04, size.width * .92,
          size.height * .10, size.width * .92, size.height * .31)
      ..cubicTo(size.width * .92, size.height * .52, size.width * .64,
          size.height * .72, size.width / 2, size.height * .86);
    canvas.drawPath(heart, stroke);

    final pulse = Path()
      ..moveTo(size.width * .13, size.height * .48)
      ..lineTo(size.width * .31, size.height * .48)
      ..lineTo(size.width * .40, size.height * .34)
      ..lineTo(size.width * .51, size.height * .64)
      ..lineTo(size.width * .62, size.height * .41)
      ..lineTo(size.width * .69, size.height * .48)
      ..lineTo(size.width * .87, size.height * .48);
    canvas.drawPath(pulse, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
