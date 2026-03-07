import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/theme.dart';

class LoginHistoryScreen extends StatefulWidget {
  const LoginHistoryScreen({super.key});

  @override
  State<LoginHistoryScreen> createState() => _LoginHistoryScreenState();
}

class _LoginHistoryScreenState extends State<LoginHistoryScreen> {
  List<Map<String, dynamic>> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('login_history') ?? '[]';
    try {
      final List decoded = jsonDecode(raw);
      setState(() {
        _history = decoded.cast<Map<String, dynamic>>().reversed.toList();
      });
    } catch (_) {}
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('login_history', '[]');
    setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: Color(0xFF00E5FF)),
          onPressed: () => Navigator.pop(context),
        ),
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
          ).createShader(bounds),
          child: const Text(
            'LOG HISTORY',
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 3,
            ),
          ),
        ),
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded,
                  color: Colors.redAccent),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF0D0D0D),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    title: const Text('Hapus History',
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Orbitron',
                            fontSize: 13)),
                    content: const Text('Yakin hapus semua history login?',
                        style: TextStyle(
                            color: Color(0xFF64B5F6),
                            fontFamily: 'ShareTechMono')),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Batal',
                              style: TextStyle(color: Colors.grey))),
                      TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Hapus',
                              style: TextStyle(color: Colors.redAccent))),
                    ],
                  ),
                );
                if (confirm == true) _clearHistory();
              },
            ),
        ],
      ),
      body: _history.isEmpty
          ? _buildEmpty()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _history.length,
              itemBuilder: (_, i) => _buildItem(_history[i], i),
            ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_rounded,
              color: const Color(0xFF00E5FF).withOpacity(0.3), size: 60),
          const SizedBox(height: 16),
          const Text(
            'Belum Ada History Login',
            style: TextStyle(
              fontFamily: 'ShareTechMono',
              color: Color(0xFF64B5F6),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> item, int index) {
    final username = item['username'] ?? '-';
    final password = item['password'] ?? '-';
    final loginAt = item['loginAt'] ?? '';
    final isSuccess = item['success'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isSuccess
              ? const Color(0xFF00E5FF).withOpacity(0.3)
              : Colors.redAccent.withOpacity(0.3),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: (isSuccess
                      ? const Color(0xFF00E5FF)
                      : Colors.redAccent)
                  .withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: (isSuccess
                        ? const Color(0xFF00E5FF)
                        : Colors.redAccent)
                    .withOpacity(0.4),
              ),
            ),
            child: Icon(
              isSuccess
                  ? Icons.check_circle_outline_rounded
                  : Icons.cancel_outlined,
              color:
                  isSuccess ? const Color(0xFF00E5FF) : Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_outline_rounded,
                        color: Color(0xFF64B5F6), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      username,
                      style: const TextStyle(
                        fontFamily: 'ShareTechMono',
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded,
                        color: Color(0xFF64B5F6), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '●' * password.length.clamp(0, 12),
                      style: const TextStyle(
                        fontFamily: 'ShareTechMono',
                        color: Color(0xFF64B5F6),
                        fontSize: 12,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time_rounded,
                        color: Color(0xFF64B5F6), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      loginAt,
                      style: TextStyle(
                        fontFamily: 'ShareTechMono',
                        color: const Color(0xFF64B5F6).withOpacity(0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: (isSuccess
                      ? const Color(0xFF00E5FF)
                      : Colors.redAccent)
                  .withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isSuccess
                        ? const Color(0xFF00E5FF)
                        : Colors.redAccent)
                    .withOpacity(0.3),
              ),
            ),
            child: Text(
              isSuccess ? 'SUKSES' : 'GAGAL',
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 8,
                color: isSuccess
                    ? const Color(0xFF00E5FF)
                    : Colors.redAccent,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
