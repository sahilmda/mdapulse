import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/widgets/app_drawer.dart';
import 'package:mda_crm/shared/widgets/app_user_menu.dart';

const Color _mdaBlue = Color(0xFF0257E6);

// ─────────────────────────────────────────────────────────────────────────────
// Contact list screen
// ─────────────────────────────────────────────────────────────────────────────

class MessagingScreen extends StatefulWidget {
  const MessagingScreen({super.key});

  @override
  State<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends State<MessagingScreen> {
  String _companyName = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _contacts = [];
  List<Map<String, dynamic>> _filtered = [];
  String _tableName = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _fetchContacts();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) setState(() => _companyName = prefs.getString('O_Name') ?? '');
  }

  Future<void> _fetchContacts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final clientId = prefs.getString('CLIENTID') ?? 'Demo';
      final db = prefs.getString('D_Database') ?? 'mdapulse';

      final response = await http.post(
        Uri.parse('https://mdapulse.com/Messaging.aspx/fillList'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({'ClientId': clientId, 'senderName': '', 'DB': db}),
      );
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body)['d']?.toString() ?? '';
        _parseList(raw);
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  void _parseList(String data) {
    if (data.isEmpty) {
      _contacts = [];
      _filtered = [];
      return;
    }
    final sections = data.split('~');
    final tableInfo = sections.length > 1 ? sections[1] : '';
    final tableArr = tableInfo.split('^');
    _tableName = tableArr.isNotEmpty ? tableArr[0] : '';

    _contacts = (sections.isNotEmpty ? sections[0] : '')
        .split('#')
        .where((r) => r.isNotEmpty)
        .map((r) {
          final a = r.split('^');
          return {
            'name': a.isNotEmpty ? a[0] : '',
            'altName': a.length > 1 ? a[1] : '',
            'phone': a.length > 2 ? a[2] : '',
            'phone2': a.length > 3 ? a[3] : '',
            'wappActive': a.length > 4 ? a[4] : '1',
            'sno': a.length > 5 ? a[5] : '0',
          };
        })
        .toList();
    _filtered = List.from(_contacts);
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = q.isEmpty
          ? List.from(_contacts)
          : _contacts.where((c) {
              final name = (c['name'] as String).toLowerCase();
              final phone = (c['phone'] as String).toLowerCase();
              return name.contains(q.toLowerCase()) ||
                  phone.contains(q.toLowerCase());
            }).toList();
    });
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Messaging',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        actions: const [AppUserMenu()],
      ),
      drawer:
          AppDrawer(currentRoute: 'Messaging', companyName: _companyName),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Description banner
          Container(
            color: const Color(0xFFF8F9FA),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'This tab shows the message history between the automated assistant and the customers. '
              'Switching to "Manual" for any customer will disable automated replies completely, '
              'and enable a chat window. Please switch back to "Auto", once the conversation is complete.',
              style:
                  TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
          ),
          const Divider(height: 1),
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search contact...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              onChanged: _onSearch,
            ),
          ),
          // Contact list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const Center(child: Text('No contacts found.'))
                    : RefreshIndicator(
                        onRefresh: _fetchContacts,
                        child: ListView.separated(
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) =>
                              const Divider(height: 1),
                          itemBuilder: (ctx, i) {
                            final c = _filtered[i];
                            final name = c['name'] as String;
                            final phone = c['phone'] as String;
                            final isAuto =
                                (c['wappActive'] as String) == '1';
                            return ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  ctx,
                                  MaterialPageRoute(
                                    builder: (_) => _ChatScreen(
                                      contact: Map.from(c),
                                      tableName: _tableName,
                                    ),
                                  ),
                                );
                                _fetchContacts();
                              },
                              leading: CircleAvatar(
                                backgroundColor: _mdaBlue,
                                child: Text(
                                  _initials(name),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14),
                                ),
                              ),
                              title: Text(name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(phone,
                                  style: const TextStyle(fontSize: 12)),
                              trailing: _statusChip(isAuto),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  static Widget _statusChip(bool isAuto) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAuto
            ? Colors.green.shade50
            : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isAuto ? Colors.green : Colors.orange),
      ),
      child: Text(
        isAuto ? 'Auto' : 'Manual',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isAuto
              ? Colors.green.shade700
              : Colors.orange.shade700,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat screen (pushed on contact tap)
// ─────────────────────────────────────────────────────────────────────────────

class _ChatScreen extends StatefulWidget {
  final Map<String, dynamic> contact;
  final String tableName;

  const _ChatScreen({required this.contact, required this.tableName});

  @override
  State<_ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<_ChatScreen> {
  bool _isLoadingChat = false;
  bool _isSending = false;
  List<Map<String, dynamic>> _messages = [];
  final TextEditingController _msgCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  String _wappActive = '1';
  String _clientId = '';
  String _db = '';
  String _ucode = '';
  late String _senderID;

  @override
  void initState() {
    super.initState();
    _wappActive = widget.contact['wappActive'] as String;
    _senderID = '91${_last10(widget.contact['phone'] as String)}';
    _loadAndFetch();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  String _last10(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10
        ? digits.substring(digits.length - 10)
        : digits;
  }

  Future<void> _loadAndFetch() async {
    final prefs = await SharedPreferences.getInstance();
    _clientId = prefs.getString('CLIENTID') ?? 'Demo';
    _db = prefs.getString('D_Database') ?? 'mdapulse';
    _ucode = prefs.getString('UCODE') ?? '';
    await _fetchChat();
  }

  Future<void> _fetchChat() async {
    if (!mounted) return;
    setState(() => _isLoadingChat = true);
    try {
      final response = await http.post(
        Uri.parse('https://mdapulse.com/Messaging.aspx/fillChat'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': _clientId,
          'senderID': _senderID,
          'Table_name': widget.tableName,
          'DB': _db,
        }),
      );
      if (response.statusCode == 200) {
        final raw = jsonDecode(response.body)['d']?.toString() ?? '';
        _parseMessages(raw);
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _isLoadingChat = false);
      _scrollToBottom();
    }
  }

  void _parseMessages(String data) {
    if (data.isEmpty) {
      _messages = [];
      return;
    }
    _messages = data
        .split('#')
        .where((r) => r.isNotEmpty)
        .map((r) {
          final a = r.split('^');
          final execCode = a.length > 6 ? a[6] : '';
          String initials = a.length > 7 ? a[7] : '';
          if (execCode == 'WA' ||
              execCode.isEmpty ||
              execCode == 'null') {
            initials = 'Auto';
          }
          return {
            'id': a.isNotEmpty ? a[0] : '',
            'senderName': a.length > 1 ? a[1] : '',
            'senderId': a.length > 2 ? a[2] : '',
            'time': a.length > 3 ? a[3] : '',
            'text': a.length > 4 ? a[4] : '',
            'status': a.length > 5 ? a[5] : '',
            'execCode': execCode,
            'initials': initials,
          };
        })
        .toList();
  }

  // A message is incoming if its sender_ID ends with the customer's last 10 digits
  bool _isIncoming(Map<String, dynamic> msg) {
    final senderId = (msg['senderId'] as String).replaceAll(RegExp(r'\D'), '');
    final last10 = _last10(widget.contact['phone'] as String);
    return senderId.endsWith(last10);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients &&
          _scrollCtrl.position.maxScrollExtent > 0) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _setMode(String targetMode) async {
    if (_wappActive == targetMode) return;
    setState(() => _wappActive = targetMode);
    try {
      await http.post(
        Uri.parse(
            'https://mdapulse.com/Messaging.aspx/updateWapp_Active'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': _clientId,
          'sno_11':
              int.tryParse(widget.contact['sno'].toString()) ?? 0,
          'DB': _db,
          'val': int.parse(targetMode),
        }),
      );
    } catch (_) {
      // Network error — UI already updated, silently continue
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _isSending = true);
    try {
      final response = await http.post(
        Uri.parse('https://mdapulse.com/Messaging.aspx/saveMessage'),
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'ClientId': _clientId,
          'msg': text,
          'TableName': widget.tableName,
          'ReceiverId': _senderID,
          'ExCode': _ucode,
        }),
      );
      if (response.statusCode == 200) {
        final result =
            jsonDecode(response.body)['d']?.toString() ?? '';
        if (result == '1') {
          _msgCtrl.clear();
          await _fetchChat();
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to send message.')));
          }
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Network error.')));
      }
    }
    if (mounted) setState(() => _isSending = false);
  }

  static String _formatTime(String raw) {
    try {
      final dt = DateTime.parse(raw);
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final min = dt.minute.toString().padLeft(2, '0');
      final ampm = dt.hour < 12 ? 'AM' : 'PM';
      return '$hour:$min $ampm';
    } catch (_) {
      return raw;
    }
  }

  static String _initials(String name) {
    final parts =
        name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final contactName = widget.contact['name'] as String;
    final isManual = _wappActive == '0';

    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: AppBar(
        backgroundColor: _mdaBlue,
        foregroundColor: Colors.white,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withValues(alpha: 0.25),
              child: Text(
                _initials(contactName),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                contactName,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Toggle bar — lives in the body so taps always register
          Container(
            color: _mdaBlue,
            padding:
                const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _modeBtn('Auto', !isManual, '1'),
                _modeBtn('Manual', isManual, '0'),
              ],
            ),
          ),
          if (_isLoadingChat)
            const Expanded(
                child: Center(child: CircularProgressIndicator()))
          else ...[
            Expanded(child: _buildChatView()),
            if (isManual) _buildMessageInput(),
          ],
        ],
      ),
    );
  }

  Widget _modeBtn(String label, bool isActive, String targetMode) {
    final isLeft = label == 'Auto';
    final radius = BorderRadius.horizontal(
      left: isLeft ? const Radius.circular(6) : Radius.zero,
      right: !isLeft ? const Radius.circular(6) : Radius.zero,
    );
    return Material(
      color: isActive ? Colors.white : Colors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: () => _setMode(targetMode),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white),
            borderRadius: radius,
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? _mdaBlue : Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatView() {
    if (_messages.isEmpty) {
      return const Center(
          child: Text('No messages yet.',
              style: TextStyle(color: Colors.black54)));
    }
    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        final msg = _messages[i];
        return _buildBubble(msg, _isIncoming(msg));
      },
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg, bool incoming) {
    final text = msg['text'] as String;
    final time = _formatTime(msg['time'] as String);
    final initials = msg['initials'] as String;

    if (incoming) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6, right: 72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(0),
                    topRight: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 2,
                        offset: const Offset(0, 1))
                  ],
                ),
                child: Text(text,
                    style: const TextStyle(fontSize: 14)),
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(time,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      );
    } else {
      final isAuto = initials == 'Auto';
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6, left: 72),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFFDCF8C6),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(0),
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Text(text,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    const SizedBox(height: 2),
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(time,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              CircleAvatar(
                radius: 16,
                backgroundColor:
                    isAuto ? const Color(0xFF20C997) : _mdaBlue,
                child: Text(
                  isAuto ? 'AUTO' : initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isAuto ? 7 : 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        border:
            Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _msgCtrl,
                style: const TextStyle(fontSize: 14),
                maxLines: 4,
                minLines: 1,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _isSending
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2)))
              : InkWell(
                  onTap: _sendMessage,
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      color: _mdaBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send,
                        color: Colors.white, size: 20),
                  ),
                ),
        ],
      ),
    );
  }
}
