import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/live_state.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static int get unreadCount =>
      LiveState.notifications.where((row) => row['isRead'] != true).length;

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
    if (MedilinkApi.instance.isConfigured) {
      LiveState.notifications.clear();
      _load();
    }
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
              if (loading) const LinearProgressIndicator(),
              if (apiError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text('Chargement impossible : $apiError'),
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
