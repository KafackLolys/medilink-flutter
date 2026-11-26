import 'dart:math';

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
    socket.off('connection:ready');
    socket.on('conversation:updated', _onConversationUpdated);
    socket.on('conversation:read', _onConversationRead);
    socket.on('connection:ready', (_) => _load());
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
                      backgroundColor: (widget.doctor
                              ? const Color(0xff2563eb)
                              : AppTheme.primary)
                          .withOpacity(.1),
                      child: Icon(
                          widget.doctor
                              ? LineAwesomeIcons.user_circle
                              : LineAwesomeIcons.stethoscope_solid,
                          color: (widget.doctor
                              ? const Color(0xff2563eb)
                              : AppTheme.primary))),
                  title: Row(children: [
                    Expanded(
                        child: Text(name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700))),
                    if (unread > 0)
                      CircleAvatar(
                          radius: 11,
                          backgroundColor: (widget.doctor
                              ? const Color(0xff2563eb)
                              : AppTheme.primary),
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
        m['clientMessageId']?.toString() ==
            item['clientMessageId']?.toString() &&
        item['clientMessageId'] != null);
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
          .conversationMarkRead(widget.conversation['id'].toString())
          .catchError((_) => <String, dynamic>{});
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
    socket.off('connection:ready');
    socket.on('message:new', _onSocketMessage);
    socket.on('message:read', _onSocketRead);
    socket.on('connection:ready', (_) {
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
      final loaded = raw is List
          ? raw.whereType<Map>().map((row) {
              final item = Map<String, dynamic>.from(row);
              return {
                ...item,
                'senderId': item['senderUserId'],
                'content': item['body'],
                'createdAt': item['sentAt'],
                'deliveryStatus': 'sent',
              };
            }).toList()
          : <Map<String, dynamic>>[];
      // Keep local pending/failed messages when a socket reconnect triggers a reload.
      final localPending = messages.where((message) =>
          message['deliveryStatus'] == 'sending' ||
          message['deliveryStatus'] == 'failed');
      for (final pending in localPending) {
        final key = pending['clientMessageId']?.toString();
        if (!loaded.any((message) =>
            key != null && message['clientMessageId']?.toString() == key)) {
          loaded.add(pending);
        }
      }
      messages = loaded;
      apiError = null;
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

  String _createClientMessageId() {
    final random = Random.secure();
    final suffix = List<int>.generate(16, (_) => random.nextInt(256))
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${DateTime.now().microsecondsSinceEpoch}-$suffix';
  }

  Future<void> send() async {
    final text = controller.text.trim();
    if (text.isEmpty || sending) return;
    final clientMessageId = _createClientMessageId();
    final pending = {
      'id': 'pending-$clientMessageId',
      'clientMessageId': clientMessageId,
      'senderId': currentUserId,
      'content': text,
      'createdAt': DateTime.now().toIso8601String(),
      'deliveryStatus': 'sending',
    };
    setState(() {
      messages.add(pending);
      controller.clear();
    });
    await _sendPending(pending);
  }

  Future<void> _sendPending(Map<String, dynamic> pending) async {
    if (sending) return;
    final clientMessageId = pending['clientMessageId'].toString();
    final conversationId = widget.conversation['id'].toString();
    setState(() {
      sending = true;
      final index =
          messages.indexWhere((m) => m['clientMessageId'] == clientMessageId);
      if (index >= 0)
        messages[index] = {...messages[index], 'deliveryStatus': 'sending'};
    });
    try {
      final sent = await MedilinkApi.instance.messageSend(
        conversationId,
        pending['content'].toString(),
        clientMessageId: clientMessageId,
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
        final pendingIndex =
            messages.indexWhere((m) => m['clientMessageId'] == clientMessageId);
        final confirmedIndex =
            messages.indexWhere((m) => m['id'] == item['id']);
        if (pendingIndex >= 0) {
          messages[pendingIndex] = item;
          if (confirmedIndex >= 0 && confirmedIndex != pendingIndex)
            messages.removeAt(confirmedIndex);
        } else if (confirmedIndex < 0) {
          messages.add(item);
        }
        sending = false;
      });
    } catch (exception) {
      // The server may have persisted the message even if the HTTP response
      // timed out or failed afterwards. Reconcile from the conversation API
      // before marking the message as failed.
      try {
        final refreshed =
            await MedilinkApi.instance.conversationMessages(conversationId);
        final raw = refreshed['items'];
        if (raw is List) {
          final match = raw.whereType<Map>().cast<Map>().where(
              (row) => row['clientMessageId']?.toString() == clientMessageId);
          if (match.isNotEmpty) {
            final row = Map<String, dynamic>.from(match.first);
            final confirmed = {
              ...row,
              'senderId': row['senderUserId'],
              'content': row['body'],
              'createdAt': row['sentAt'],
              'deliveryStatus': 'sent',
            };
            if (!mounted) return;
            setState(() {
              final pendingIndex = messages
                  .indexWhere((m) => m['clientMessageId'] == clientMessageId);
              final confirmedIndex =
                  messages.indexWhere((m) => m['id'] == confirmed['id']);
              if (pendingIndex >= 0) {
                messages[pendingIndex] = confirmed;
                if (confirmedIndex >= 0 && confirmedIndex != pendingIndex) {
                  messages.removeAt(confirmedIndex);
                }
              } else if (confirmedIndex < 0) {
                messages.add(confirmed);
              }
              sending = false;
            });
            return;
          }
        }
      } catch (_) {
        // Keep the original error and failed state if reconciliation fails.
      }
      if (!mounted) return;
      setState(() {
        final index =
            messages.indexWhere((m) => m['clientMessageId'] == clientMessageId);
        // A real-time confirmation may arrive even if the HTTP response times out.
        if (index >= 0 && messages[index]['deliveryStatus'] != 'sent') {
          messages[index] = {...messages[index], 'deliveryStatus': 'failed'};
        }
        sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Envoi non confirmé : $exception. Vous pouvez réessayer sans créer de doublon.')),
      );
    }
  }

  Future<void> _retryMessage(Map<String, dynamic> message) async {
    if (sending || message['deliveryStatus'] != 'failed') return;
    await _sendPending(message);
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
                            color: mine
                                ? (widget.doctor
                                    ? const Color(0xff2563eb)
                                    : AppTheme.primary)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18).copyWith(
                                bottomRight:
                                    mine ? const Radius.circular(4) : null,
                                bottomLeft:
                                    mine ? null : const Radius.circular(4))),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(message['content'].toString(),
                                  style: TextStyle(
                                      color: mine
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                                      height: 1.35)),
                              if (message['deliveryStatus'] == 'sending' ||
                                  message['deliveryStatus'] == 'failed')
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: message['deliveryStatus'] == 'failed'
                                      ? TextButton.icon(
                                          onPressed: sending
                                              ? null
                                              : () => _retryMessage(message),
                                          style: TextButton.styleFrom(
                                            foregroundColor: mine
                                                ? Colors.white
                                                : const Color(0xffb45309),
                                            padding: EdgeInsets.zero,
                                            minimumSize: const Size(0, 28),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          icon: const Icon(
                                              Icons.refresh_rounded,
                                              size: 14),
                                          label: const Text('Échec · Réessayer',
                                              style: TextStyle(fontSize: 11)),
                                        )
                                      : Text('Envoi…',
                                          style: TextStyle(
                                              color: mine
                                                  ? Colors.white70
                                                  : AppTheme.textSecondary,
                                              fontSize: 10)),
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
