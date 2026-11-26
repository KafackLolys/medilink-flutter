import 'package:flutter/material.dart';
import 'package:line_awesome_flutter/line_awesome_flutter.dart';

import '../../../core/api/medilink_api.dart';
import '../../../core/data/live_state.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/messaging_socket_service.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key, required this.doctor});
  final bool doctor;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> conversations = LiveState.conversations;
  bool loading = false;
  bool hasApiResponse = false;
  String? apiError;
  final messagingSocket = MessagingSocketService.instance;
  void _onConversationUpdated(dynamic payload) {
    if (!mounted || payload is! Map) return;
    final data = Map<String, dynamic>.from(payload);
    setState(() {
      conversations = conversations
          .map((item) =>
              item['id']?.toString() == data['conversationId']?.toString()
                  ? {
                      ...item,
                      'lastMessage': data['preview'] ?? item['lastMessage'],
                      'lastMessageAt': data['lastMessageAt'],
                      'unreadCount': data['unreadCount'] ?? item['unreadCount']
                    }
                  : item)
          .toList();
    });
  }

  void _onConversationRead(dynamic payload) {
    if (!mounted || payload is! Map) return;
    final data = Map<String, dynamic>.from(payload);
    if (data['readerUserId']?.toString() != MedilinkApi.instance.userId) return;
    setState(() {
      conversations = conversations
          .map((item) =>
              item['id']?.toString() == data['conversationId']?.toString()
                  ? {...item, 'unreadCount': 0}
                  : item)
          .toList();
    });
  }

  @override
  void initState() {
    super.initState();
    if (MedilinkApi.instance.isConfigured) {
      _load();
      _connectConversationEvents();
    }
  }

  Future<void> _connectConversationEvents() async {
    await messagingSocket.connect();
    final socket = messagingSocket.socket;
    if (socket == null) return;
    socket.off('conversation:updated', _onConversationUpdated);
    socket.off('conversation:read', _onConversationRead);
    socket.on('conversation:updated', _onConversationUpdated);
    socket.on('conversation:read', _onConversationRead);
    socket.on('connect', (_) => _load());
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final response =
          await MedilinkApi.instance.get('messages/v2/conversations');
      final raw = response is Map ? response['items'] : null;
      conversations = raw is List
          ? raw.whereType<Map>().map((row) {
              final item = Map<String, dynamic>.from(row);
              return {
                ...item,
                'participantName': item['peerName'] ?? 'Conversation',
                'lastMessage': item['preview'] ?? '',
                'messages': <Map<String, dynamic>>[],
              };
            }).toList()
          : <Map<String, dynamic>>[];
      apiError = null;
      hasApiResponse = true;
    } catch (exception) {
      apiError = exception.toString();
      if (MedilinkApi.instance.isConfigured) {
        conversations = <Map<String, dynamic>>[];
        hasApiResponse = true;
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    final socket = messagingSocket.socket;
    socket?.off('conversation:updated', _onConversationUpdated);
    socket?.off('conversation:read', _onConversationRead);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleConversations =
        MedilinkApi.instance.isConfigured && !hasApiResponse
            ? <Map<String, dynamic>>[]
            : conversations;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Text('Messagerie',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        const Text('Échangez au sujet de vos demandes et rendez-vous.'),
        if (loading) const LinearProgressIndicator(),
        if (apiError != null)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Chargement des conversations impossible : $apiError'),
                    TextButton.icon(
                        onPressed: loading ? null : _load,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Réessayer'))
                  ])),
        const SizedBox(height: 16),
        if (visibleConversations.isEmpty && loading)
          const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()))
        else if (visibleConversations.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: Text('Aucune conversation à afficher.')))
        else
          ...visibleConversations.map((conversation) {
            final unread = (conversation['unreadCount'] as num?)?.toInt() ?? 0;
            final name =
                conversation['participantName']?.toString() ?? 'Conversation';
            return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  leading: CircleAvatar(
                      backgroundColor: AppTheme.primary.withOpacity(.1),
                      child: Icon(
                          widget.doctor
                              ? LineAwesomeIcons.user_circle
                              : LineAwesomeIcons.stethoscope_solid,
                          color: AppTheme.primary)),
                  title: Row(children: [
                    Expanded(
                        child: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    if (unread > 0)
                      CircleAvatar(
                          radius: 11,
                          backgroundColor: AppTheme.primary,
                          child: Text('$unread',
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 11)))
                  ]),
                  subtitle: Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(conversation['lastMessage']?.toString() ?? '',
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                  trailing:
                      const Icon(LineAwesomeIcons.angle_right_solid, size: 18),
                  onTap: () async {
                    await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                                conversation: conversation,
                                doctor: widget.doctor)));
                    if (mounted && MedilinkApi.instance.isConfigured) {
                      await _load();
                    }
                    if (mounted) setState(() {});
                  },
                ));
          }),
        const SizedBox(height: 10),
      ],
    );
  }
}

class ConversationScreen extends StatefulWidget {
  const ConversationScreen(
      {super.key, required this.conversation, required this.doctor});
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
  bool sending = false;
  String get currentUserId => MedilinkApi.instance.userId ?? '';
  final messagingSocket = MessagingSocketService.instance;
  void _onSocketMessage(dynamic payload) {
    if (!mounted || payload is! Map) return;
    final data = Map<String, dynamic>.from(payload);
    if (data['conversationId']?.toString() !=
        widget.conversation['id']?.toString()) return;
    final raw = data['message'];
    if (raw is! Map) return;
    final item = Map<String, dynamic>.from(raw);
    if (messages.any((m) => m['id']?.toString() == item['id']?.toString()))
      return;
    // Reconcile retries as well as first sends. A server event is
    // authoritative even if the HTTP response subsequently times out.
    final pendingIndex = messages.indexWhere((m) =>
        (m['deliveryStatus'] == 'sending' || m['deliveryStatus'] == 'failed') &&
        m['senderId']?.toString() == currentUserId &&
        m['content']?.toString() == item['body']?.toString());
    setState(() {
      final confirmed = {
        ...item,
        'senderId': item['senderUserId'],
        'content': item['body'],
        'createdAt': item['sentAt'],
        'deliveryStatus': 'sent',
      };
      if (pendingIndex >= 0) {
        messages[pendingIndex] = confirmed;
      } else {
        messages.add(confirmed);
      }
    });
    if (item['senderUserId']?.toString() != currentUserId) {
      MedilinkApi.instance
          .conversationMarkRead(widget.conversation['id'].toString());
    }
  }

  void _onSocketRead(dynamic payload) {
    if (!mounted || payload is! Map) return;
    final data = Map<String, dynamic>.from(payload);
    if (data['conversationId']?.toString() !=
            widget.conversation['id']?.toString() ||
        data['readerUserId']?.toString() == currentUserId) return;
    setState(() {
      messages = messages
          .map((m) => m['senderId']?.toString() == currentUserId
              ? {...m, 'readAt': data['readAt']}
              : m)
          .toList();
    });
  }

  @override
  void initState() {
    super.initState();
    messages = widget.conversation['messages'] as List<Map<String, dynamic>>? ??
        <Map<String, dynamic>>[];
    if (MedilinkApi.instance.isConfigured) {
      _loadMessages();
      _connectRealtime();
    }
  }

  Future<void> _connectRealtime() async {
    await messagingSocket.connect();
    final socket = messagingSocket.socket;
    if (socket == null) return;
    socket.off('message:new', _onSocketMessage);
    socket.off('message:read', _onSocketRead);
    socket.on('message:new', _onSocketMessage);
    socket.on('message:read', _onSocketRead);
    socket.on('connect', (_) {
      messagingSocket.joinConversation(widget.conversation['id'].toString());
      _loadMessages();
    });
    if (socket.connected)
      messagingSocket.joinConversation(widget.conversation['id'].toString());
  }

  Future<void> _loadMessages() async {
    setState(() => loading = true);
    try {
      final response = await MedilinkApi.instance.get(
          'messages/v2/conversations/${Uri.encodeComponent(widget.conversation['id'].toString())}');
      final raw = response is Map ? response['items'] : null;
      messages = raw is List
          ? raw.whereType<Map>().map((row) {
              final item = Map<String, dynamic>.from(row);
              return {
                ...item,
                'senderId': item['senderUserId'],
                'content': item['body'],
                'createdAt': item['sentAt']
              };
            }).toList()
          : <Map<String, dynamic>>[];
      apiError = null;
      await MedilinkApi.instance
          .conversationMarkRead(widget.conversation['id'].toString());
    } catch (exception) {
      apiError = exception.toString();
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    final socket = messagingSocket.socket;
    socket?.off('message:new', _onSocketMessage);
    socket?.off('message:read', _onSocketRead);
    messagingSocket.leaveConversation(widget.conversation['id'].toString());
    controller.dispose();
    super.dispose();
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    final pendingId = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final pending = {
      'id': pendingId,
      'senderId': currentUserId,
      'content': text,
      'createdAt': DateTime.now().toIso8601String(),
      'deliveryStatus': 'sending',
    };
    setState(() {
      sending = true;
      messages.add(pending);
      controller.clear();
    });
    try {
      final sent = await MedilinkApi.instance
          .messageSend(widget.conversation['id'].toString(), text);
      if (!mounted) return;
      final item = {
        ...sent,
        'senderId': sent['senderUserId'],
        'content': sent['body'],
        'createdAt': sent['sentAt'],
        'deliveryStatus': 'sent',
      };
      setState(() {
        final pendingIndex = messages.indexWhere((m) => m['id'] == pendingId);
        final confirmedIndex = messages.indexWhere((m) => m['id'] == item['id']);
        if (pendingIndex >= 0) {
          messages[pendingIndex] = item;
          if (confirmedIndex >= 0 && confirmedIndex != pendingIndex) {
            messages.removeAt(confirmedIndex);
          }
        } else if (confirmedIndex < 0) {
          messages.add(item);
        }
        sending = false;
      });
    } catch (exception) {
      if (!mounted) return;
      setState(() {
        final index = messages.indexWhere((m) => m['id'] == pendingId);
        if (index >= 0) {
          messages[index] = {...messages[index], 'deliveryStatus': 'failed'};
        }
        sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Envoi impossible : $exception')));
    }
  }

  Future<void> _retryMessage(String messageId) async {
    if (sending) return;
    final index = messages.indexWhere((message) =>
        message['id']?.toString() == messageId &&
        message['deliveryStatus'] == 'failed');
    if (index < 0) return;
    final body = messages[index]['content']?.toString() ?? '';
    if (body.trim().isEmpty) return;

    setState(() {
      sending = true;
      messages[index] = {...messages[index], 'deliveryStatus': 'sending'};
    });
    try {
      final sent = await MedilinkApi.instance.messageSend(
        widget.conversation['id'].toString(),
        body,
      );
      if (!mounted) return;
      final item = {
        ...sent,
        'senderId': sent['senderUserId'],
        'content': sent['body'],
        'createdAt': sent['sentAt'],
        'deliveryStatus': 'sent',
      };
      setState(() {
        final pendingIndex = messages.indexWhere((message) =>
            message['id']?.toString() == messageId);
        final confirmedIndex = messages.indexWhere((message) =>
            message['id']?.toString() == item['id']?.toString());
        if (pendingIndex >= 0) {
          messages[pendingIndex] = item;
          if (confirmedIndex >= 0 && confirmedIndex != pendingIndex) {
            messages.removeAt(confirmedIndex);
          }
        } else if (confirmedIndex < 0) {
          messages.add(item);
        }
      });
    } catch (exception) {
      if (!mounted) return;
      // The backend can persist and broadcast the message even when the
      // request response is lost. Refresh only this conversation to reconcile.
      var accepted = false;
      try {
        final response = await MedilinkApi.instance.get(
            'messages/v2/conversations/${Uri.encodeComponent(widget.conversation['id'].toString())}');
        final raw = response is Map ? response['items'] : null;
        if (raw is List) {
          final refreshed = raw.whereType<Map>().map((row) {
            final item = Map<String, dynamic>.from(row);
            return {
              ...item,
              'senderId': item['senderUserId'],
              'content': item['body'],
              'createdAt': item['sentAt'],
            };
          }).toList();
          accepted = refreshed.any((message) =>
              message['senderId']?.toString() == currentUserId &&
              message['content']?.toString() == body);
          if (accepted) setState(() => messages = refreshed);
        }
      } catch (_) {
        // Preserve the retry error if reconciliation cannot reach the API.
      }
      if (!accepted) {
        final failedIndex = messages.indexWhere((message) =>
            message['id']?.toString() == messageId);
        if (failedIndex >= 0) {
          setState(() {
            messages[failedIndex] = {
              ...messages[failedIndex],
              'deliveryStatus': 'failed',
            };
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Nouvel essai impossible : $exception')),
        );
      }
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contact =
        widget.conversation['participantName']?.toString() ?? 'Conversation';
    return Scaffold(
      appBar: AppBar(
          title:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(contact,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text('Messagerie en temps réel',
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.textSecondary))
          ]),
          actions: [
            if (MedilinkApi.instance.isConfigured)
              IconButton(
                  tooltip: 'Actualiser',
                  onPressed: _loadMessages,
                  icon: const Icon(Icons.refresh))
          ]),
      body: Column(children: [
        if (loading) const LinearProgressIndicator(),
        if (apiError != null)
          Padding(
              padding: const EdgeInsets.all(10),
              child: Text('Chargement des messages impossible : $apiError')),
        Expanded(
            child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[index];
                  final mine = message['senderId'] == currentUserId;
                  return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        constraints: BoxConstraints(
                            maxWidth: MediaQuery.sizeOf(context).width * .78),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 11),
                        decoration: BoxDecoration(
                            color: mine ? AppTheme.primary : Colors.white,
                            borderRadius: BorderRadius.circular(18).copyWith(
                                bottomRight:
                                    mine ? const Radius.circular(4) : null,
                                bottomLeft:
                                    mine ? null : const Radius.circular(4))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(message['content'].toString(),
                            style: TextStyle(
                                color:
                                    mine ? Colors.white : AppTheme.textPrimary,
                                height: 1.35)),
                          if (message['deliveryStatus'] == 'sending' || message['deliveryStatus'] == 'failed')
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    message['deliveryStatus'] == 'sending'
                                        ? 'Envoi…'
                                        : 'Échec de l’envoi',
                                    style: TextStyle(
                                      color: mine ? Colors.white70 : AppTheme.textSecondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                  if (message['deliveryStatus'] == 'failed') ...[
                                    const SizedBox(width: 8),
                                    TextButton.icon(
                                      onPressed: sending
                                          ? null
                                          : () => _retryMessage(message['id'].toString()),
                                      style: TextButton.styleFrom(
                                        foregroundColor: mine ? Colors.white : AppTheme.primary,
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        minimumSize: Size.zero,
                                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      icon: const Icon(Icons.refresh, size: 13),
                                      label: const Text('Réessayer', style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ]),
                      ));
                })),
        SafeArea(
            top: false,
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: controller,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 4000,
                          decoration: const InputDecoration(
                              hintText: 'Votre message', counterText: ''))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      onPressed: sending ? null : send,
                      tooltip: 'Envoyer le message',
                      icon: const Icon(LineAwesomeIcons.paper_plane_solid)),
                ]))),
      ]),
    );
  }
}
