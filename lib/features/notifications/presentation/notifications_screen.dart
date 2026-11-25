import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/live_state.dart';
import '../../../core/services/push_notification_service.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static int get unreadCount =>
      LiveState.notifications.where((row) => row['isRead'] != true).length +
      PushNotificationService.instance.messages.length;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = false;
  int page = 1, totalPages = 1;
  String? apiError;

  @override
  void initState() {
    super.initState();
    PushNotificationService.instance.addListener(_onPushChanged);
    if (MedilinkApi.instance.isConfigured) {
      LiveState.notifications.clear();
      _load();
    }
  }

  @override
  void dispose() {
    PushNotificationService.instance.removeListener(_onPushChanged);
    super.dispose();
  }

  void _onPushChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load({bool append = false}) async {
    setState(() => loading = true);
    try {
      final response = await MedilinkApi.instance
          .notificationsList(page: page, pageSize: 20);
      final raw = response['items'];
      totalPages = (response['totalPages'] as num?)?.toInt() ?? 1;
      final rows = raw is List
          ? raw.whereType<Map>().map((row) {
              final item = Map<String, dynamic>.from(row);
              return {...item, 'isRead': item['readAt'] != null};
            }).toList()
          : <Map<String, dynamic>>[];
      if (append) {
        final ids = LiveState.notifications.map((v) => v['id']).toSet();
        LiveState.notifications
            .addAll(rows.where((v) => !ids.contains(v['id'])));
      } else {
        LiveState.notifications
          ..clear()
          ..addAll(rows);
      }
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
      if (append && page > 1) page--;
      if (MedilinkApi.instance.isConfigured) LiveState.notifications.clear();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _refresh() {
    page = 1;
    return _load();
  }

  Future<void> markAllRead() async {
    try {
      await MedilinkApi.instance.notificationsReadAll();
      if (mounted)
        setState(() {
          for (final row in LiveState.notifications) {
            row['isRead'] = true;
          }
        });
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Mise à jour impossible : $exception')),
      );
    }
  }

  Future<void> _markRead(Map<String, dynamic> row) async {
    if (row['isRead'] == true) return;
    try {
      await MedilinkApi.instance.notificationRead(row['id'].toString());
      if (mounted) setState(() => row['isRead'] = true);
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Notification non mise à jour : $exception')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Notifications'), actions: [
          IconButton(
              tooltip: 'Actualiser',
              onPressed: loading ? null : _refresh,
              icon: const Icon(Icons.refresh)),
          TextButton(
              onPressed:
                  NotificationsScreen.unreadCount == 0 ? null : markAllRead,
              child: const Text('Tout lire'))
        ]),
        body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            children: [
              _buildNovuCard(),
              const SizedBox(height: 12),
              _buildPushMessagesSection(),
              if (loading) const LinearProgressIndicator(),
              if (apiError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Chargement impossible : $apiError'),
                ),
              const Padding(
                padding: EdgeInsets.only(top: 8, bottom: 8),
                child: Text(
                  'Notifications du compte',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (LiveState.notifications.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(48),
                    child:
                        Center(child: Text('Aucune notification à afficher.')))
              else
                ...LiveState.notifications.map((row) {
                  final unread = row['isRead'] != true;
                  return Card(
                      color: unread ? const Color(0xffeff7fd) : Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                            backgroundColor: AppTheme.primary.withOpacity(.1),
                            child: Icon(_icon(row['type']?.toString()),
                                color: AppTheme.primary, size: 19)),
                        title: Text(row['title'].toString(),
                            style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.w700
                                    : FontWeight.w500)),
                        subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                                '${row['body']}\n${_date(row['createdAt']?.toString())}')),
                        isThreeLine: true,
                        trailing: unread
                            ? const Icon(LineAwesomeIcons.circle_solid,
                                size: 9, color: AppTheme.primary)
                            : null,
                        onTap: () => _markRead(row),
                      ));
                }),
              if (MedilinkApi.instance.isConfigured && page < totalPages)
                Center(
                    child: TextButton(
                        onPressed: loading
                            ? null
                            : () {
                                page++;
                                _load(append: true);
                              },
                        child: const Text('Charger plus de notifications'))),
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                      'Notifications chargées depuis le serveur. Le flux temps réel n’est pas proposé par l’API.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12))),
            ]),
      );

  Widget _buildNovuCard() {
    final push = PushNotificationService.instance;
    final isRegistered = push.registeredWithBackend;
    final hasToken = push.token?.isNotEmpty == true;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isRegistered
              ? const Color(0xffc2e7ff)
              : const Color(0xffe0e0e0),
        ),
      ),
      color: isRegistered ? const Color(0xfff0f7ff) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    LineAwesomeIcons.bell_solid,
                    color: AppTheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Notifications push',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      Text(
                        'Firebase Cloud Messaging · MediLink',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isRegistered
                        ? const Color(0xffe6f4ea)
                        : const Color(0xfffef7e0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isRegistered
                        ? 'Connecté'
                        : (hasToken ? 'À enregistrer' : 'En attente'),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isRegistered
                          ? const Color(0xff137333)
                          : const Color(0xffb06000),
                    ),
                  ),
                ),
              ],
            ),
            if (push.error != null) ...[
              const SizedBox(height: 8),
              Text(
                push.error!,
                style: const TextStyle(color: Colors.red, fontSize: 11),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isRegistered ? null : push.retryRegistration,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Réessayer l’enregistrement'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPushMessagesSection() {
    final push = PushNotificationService.instance;
    if (push.messages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Push reçus en direct (${push.messages.length})',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            TextButton(
              onPressed: () {
                setState(() => push.messages.clear());
              },
              child: const Text('Effacer'),
            ),
          ],
        ),
        ...push.messages.map((message) {
          final title = message.notification?.title ??
              message.data['title']?.toString() ??
              'Notification MedLink';
          final body = message.notification?.body ??
              message.data['body']?.toString() ??
              '';
          return Card(
            color: const Color(0xffe8f0fe),
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: AppTheme.primary,
                child: Icon(
                  LineAwesomeIcons.bell_solid,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: body.isNotEmpty ? Text(body) : null,
              trailing: const Icon(
                LineAwesomeIcons.check_circle_solid,
                size: 16,
                color: AppTheme.primary,
              ),
            ),
          );
        }),
        const Divider(height: 24),
      ],
    );
  }

  IconData _icon(String? type) => switch (type) {
        'new_message' => LineAwesomeIcons.comment_dots_solid,
        'proposal_received' => LineAwesomeIcons.clipboard_check_solid,
        'appointment_confirmed' => LineAwesomeIcons.calendar_check_solid,
        _ => LineAwesomeIcons.bell_solid,
      };

  String _date(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    if (parsed == null) return 'Récemment';
    final date = parsed.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
