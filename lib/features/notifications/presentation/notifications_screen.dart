import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/demo_data.dart';
import '../../../core/theme/app_theme.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  static int get unreadCount =>
      DemoData.notifications.where((row) => row['isRead'] != true).length;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool loading = false;
  String? apiError;

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response = await MedilinkApi.instance.get(
        'notifications/v2',
        query: const {'page': '1', 'pageSize': '20'},
      );
      final raw = response is Map ? response['items'] : null;
      final rows = raw is List ? raw.whereType<Map>().map((row) {
        final item = Map<String, dynamic>.from(row);
        return {...item, 'isRead': item['readAt'] != null};
      }).toList() : <Map<String, dynamic>>[];
      DemoData.notifications
        ..clear()
        ..addAll(rows);
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> markAllRead() async {
    try {
      if (MedilinkApi.instance.isConfigured) {
        await MedilinkApi.instance.patch('notifications/v2/read-all');
      }
      if (mounted) setState(() {
        for (final row in DemoData.notifications) { row['isRead'] = true; }
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
      if (MedilinkApi.instance.isConfigured) {
        await MedilinkApi.instance.patch(
          'notifications/v2/${Uri.encodeComponent(row['id'].toString())}/read',
        );
      }
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
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text('API indisponible · notifications template affichées.'),
                ),
              if (DemoData.notifications.isEmpty)
                const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: Text('Aucune notification.')))
              else
                ...DemoData.notifications.map((row) {
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
                            ? const Icon(Icons.circle,
                                size: 9, color: AppTheme.primary)
                            : null,
                        onTap: () => _markRead(row),
                      ));
                }),
              const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                      'Données de démonstration · aucun push réel n’est envoyé.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 12))),
            ]),
      );

  IconData _icon(String? type) => switch (type) {
        'new_message' => LucideIcons.messageCircle,
        'proposal_received' => LucideIcons.clipboardCheck,
        'appointment_confirmed' => LucideIcons.calendarCheck,
        _ => LucideIcons.bell,
      };

  String _date(String? raw) {
    final parsed = DateTime.tryParse(raw ?? '');
    if (parsed == null) return 'Récemment';
    final date = parsed.toLocal();
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
