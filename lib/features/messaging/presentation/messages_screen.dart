import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/demo_data.dart';
import '../../../core/theme/app_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.doctor});
  final bool doctor;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> conversations = DemoData.conversations;
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
      final response = await MedilinkApi.instance.get('messages/v2/conversations');
      final raw = response is Map ? response['items'] : null;
      conversations = raw is List ? raw.whereType<Map>().map((row) {
        final item = Map<String, dynamic>.from(row);
        return {
          ...item,
          'participantName': item['peerName'] ?? 'Conversation',
          'lastMessage': item['preview'] ?? '',
          'messages': <Map<String, dynamic>>[],
        };
      }).toList() : <Map<String, dynamic>>[];
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
    children: [
      Text('Messagerie', style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
      const SizedBox(height: 5),
      const Text('Échangez au sujet de vos demandes et rendez-vous.'),
      if (loading) const LinearProgressIndicator(),
      if (apiError != null) const Padding(padding: EdgeInsets.only(top: 8), child: Text('API indisponible · conversations template affichées.')),
      const SizedBox(height: 16),
      if (conversations.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 48), child: Center(child: Text('Aucune conversation pour le moment.')))
      else ...conversations.map((conversation) {
        final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
        final name = conversation['participantName']?.toString() ?? 'Conversation';
        return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(.1), child: Icon(widget.doctor ? LucideIcons.userRound : LucideIcons.stethoscope, color: AppTheme.primary)),
          title: Row(children: [Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.w700))), if (unread > 0) CircleAvatar(radius: 11, backgroundColor: AppTheme.primary, child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11)))]),
          subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(conversation['lastMessage']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
          trailing: const Icon(LucideIcons.chevronRight, size: 18),
          onTap: () async {
            setState(() => conversation['unreadCount'] = 0);
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ConversationScreen(conversation: conversation, doctor: widget.doctor)));
            if (mounted) setState(() {});
          },
        ));
      }),
      const SizedBox(height: 10),
      Text(MedilinkApi.instance.isConfigured ? 'Messages synchronisés avec l’API Medilink.' : 'Données de démonstration · aucun message n’est envoyé.', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
    ],
  );
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen({super.key, required this.conversation, required this.doctor});
  final Map<String, dynamic> conversation;
  final bool doctor;
  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final controller = TextEditingController();
  late List<Map<String, dynamic>> messages;
  String? apiError;
  bool loading = false;
  String get currentUserId => MedilinkApi.instance.userId ?? (widget.doctor ? 'doctor-demo-01' : 'user-demo-01');

  @override
  void initState() {
    super.initState();
    messages = widget.conversation['messages'] as List<Map<String, dynamic>>? ?? <Map<String, dynamic>>[];
    if (MedilinkApi.instance.isConfigured) _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => loading = true);
    try {
      final response = await MedilinkApi.instance.get('messages/v2/conversations/${Uri.encodeComponent(widget.conversation['id'].toString())}');
      final raw = response is Map ? response['items'] : null;
      messages = raw is List ? raw.whereType<Map>().map((row) {
        final item = Map<String, dynamic>.from(row);
        return {...item, 'senderId': item['senderUserId'], 'content': item['body'], 'createdAt': item['sentAt']};
      }).toList() : <Map<String, dynamic>>[];
      apiError = null;
    } catch (exception) {
      apiError = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() { controller.dispose(); super.dispose(); }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    try {
      Map<String, dynamic>? sent;
      if (MedilinkApi.instance.isConfigured) {
        final response = await MedilinkApi.instance.post(
          'messages/v2/conversations/${Uri.encodeComponent(widget.conversation['id'].toString())}',
          {'body': text},
        );
        if (response is Map) sent = Map<String, dynamic>.from(response);
      }
      if (!mounted) return;
      setState(() {
        messages.add({
          'id': sent?['id'] ?? 'message-demo-${DateTime.now().microsecondsSinceEpoch}',
          'senderId': sent?['senderUserId'] ?? currentUserId,
          'content': sent?['body'] ?? text,
          'createdAt': sent?['sentAt'] ?? DateTime.now().toUtc().toIso8601String(),
        });
        widget.conversation['lastMessage'] = text;
        widget.conversation['preview'] = text;
        controller.clear();
      });
    } catch (exception) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Envoi impossible : $exception')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact = widget.conversation['participantName']?.toString() ?? 'Conversation';
    return Scaffold(
      appBar: AppBar(title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(contact, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)), Text(MedilinkApi.instance.isConfigured ? 'Conversation sécurisée' : 'Conversation de démonstration', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary))])),
      body: Column(children: [
        if (loading) const LinearProgressIndicator(),
        if (apiError != null) Padding(padding: const EdgeInsets.all(10), child: Text('Chargement des messages impossible : $apiError')),
        Expanded(child: ListView.builder(padding: const EdgeInsets.all(16), itemCount: messages.length, itemBuilder: (context, index) {
          final message = messages[index];
          final mine = message['senderId'] == currentUserId;
          return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
            margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(color: mine ? AppTheme.primary : Colors.white, borderRadius: BorderRadius.circular(18).copyWith(bottomRight: mine ? const Radius.circular(4) : null, bottomLeft: mine ? null : const Radius.circular(4))),
            child: Text(message['content'].toString(), style: TextStyle(color: mine ? Colors.white : AppTheme.textPrimary, height: 1.35)),
          ));
        })),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 10), child: Row(children: [
          Expanded(child: TextField(controller: controller, minLines: 1, maxLines: 4, maxLength: 4000, decoration: const InputDecoration(hintText: 'Votre message', counterText: ''))),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: send, tooltip: 'Envoyer le message', icon: const Icon(LucideIcons.send)),
        ]))),
      ]),
    );
  }
}
