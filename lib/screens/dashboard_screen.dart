import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import '../screens/login_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/profile_settings_screen.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/heartbeat_service.dart';
import 'tabs/home_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/bug_tab.dart';
import 'tabs/manage_tab.dart';
import 'hacked_screen.dart';
import 'create_vip_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  int _lastMsgCount = 0;
  String _role = 'member';
  String _myId = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _tabs = const [
    HomeTab(),
    ToolsTab(),
    BugTab(),
    ManageTab(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: AppSvgIcons.home, label: 'Home'),
    _NavItem(icon: AppSvgIcons.tools, label: 'Tools'),
    _NavItem(icon: AppSvgIcons.bug, label: 'Bug'),
    _NavItem(icon: AppSvgIcons.manage, label: 'Manage'),
  ];

  @override
  void initState() {
    super.initState();
    HeartbeatService.instance.start(onExpiredCallback: _handleExpired);
    _loadUserInfo();
    _checkUnread();
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _checkUnread();
    });
    Future.delayed(const Duration(seconds: 2), () {
      NotificationService.requestPermission();
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? 'member';
      _myId = prefs.getString('user_id') ?? '';
    });
    NotificationService.startChatPolling(_myId);
    if (_role != 'owner') {
      final lastShown = prefs.getInt('donate_notif_last') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastShown > 3 * 60 * 60 * 1000) {
        await prefs.setInt('donate_notif_last', now);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _showDonateModal();
        });
      }
    }
  }


  Future<void> _checkUnread() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;
      final res = await http.get(
        Uri.parse('\${ApiService.baseUrl}/api/chat/messages?room=global&limit=200'),
        headers: {'Authorization': 'Bearer \$token'},
      );
      final json = jsonDecode(res.body);
      if (json['success'] == true && mounted) {
        final total = (json['messages'] as List).length;
        if (_lastMsgCount == 0) {
          // Pertama kali load — set baseline, tidak ada unread
          _lastMsgCount = total;
        } else if (total > _lastMsgCount) {
          setState(() => _unreadCount += total - _lastMsgCount);
          _lastMsgCount = total;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    HeartbeatService.instance.stop();
    NotificationService.stopAll();
    super.dispose();
  }

  Future<void> _handleExpired() async {
    if (!mounted) return;
    // Tampilkan dialog expired lalu redirect ke login
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.withOpacity(0.6))),
        title: Row(children: [
          Icon(Icons.timer_off, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Text('EXPIRED', style: TextStyle(fontFamily: 'Orbitron', color: Colors.orange, fontSize: 13, letterSpacing: 2)),
        ]),
        content: const Text(
          'Masa aktif Premium kamu sudah habis. Silakan hubungi owner untuk memperpanjang.',
          style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('OK', style: TextStyle(fontFamily: 'Orbitron', color: Colors.orange, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.5)),
        ),
        title: Text(tr('logout'),
            style: const TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 16, letterSpacing: 2)),
        content: Text(tr('logout_confirm'),
            style: const TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel'),
                style: const TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('logout'),
                style: const TextStyle(fontFamily: 'Orbitron', color: AppTheme.accentBlue, fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  void _openChat() {
    setState(() => _unreadCount = 0);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
  }

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
  }

  void _openHacked() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HackedScreen()));
  }

  void _openContactOwner() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ContactOwnerSheet(),
    );
  }

  void _openCart() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D1F35),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2))),
              ),
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2)))),
                child: Row(children: [
                  Container(width: 3, height: 20,
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  SvgPicture.string(AppSvgIcons.shoppingCart, width: 18, height: 18,
                      colorFilter: const ColorFilter.mode(AppTheme.accentBlue, BlendMode.srcIn)),
                  const SizedBox(width: 8),
                  const Text('HARGA & PAKET',
                    style: TextStyle(fontFamily: 'Orbitron', fontSize: 15,
                      fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1), shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.withOpacity(0.3))),
                      child: const Icon(Icons.close_rounded, color: Colors.red, size: 15),
                    ),
                  ),
                ]),
              ),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Header app
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          AppTheme.primaryBlue.withOpacity(0.3),
                          const Color(0xFF00E5FF).withOpacity(0.1),
                        ]),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5)),
                      ),
                      child: const Center(
                        child: Text('Application Pegasus-X Revenge',
                          style: TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                            fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── PREMIUM ──
                    _priceSection(
                      title: 'Role Premium',
                      titleColor: const Color(0xFF82B1FF),
                      icon: '💎',
                      items: const [
                        'Rp 10.000  —  1 Hari',
                        'Rp 25.000  —  5 Hari',
                        'Rp 35.000  —  1 Minggu',
                        'Rp 80.000  —  1 Bulan',
                      ],
                    ),
                    const SizedBox(height: 10),
                    _benefitSection(
                      title: 'Keuntungan Role Premium',
                      color: const Color(0xFF82B1FF),
                      benefits: const [
                        'Sender Di Tanggung Owner',
                        'Ga Perlu Ribet Ribet Add Sender',
                        'Bisa Spam Bug Tanpa Takut Kenon',
                        'Bug Sepuasnya Tanpa Jeda',
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── VIP ──
                    _priceSection(
                      title: 'Role VIP',
                      titleColor: const Color(0xFFFFD54F),
                      icon: '👑',
                      items: const [
                        'Rp 45.000  —  Permanen',
                        'Rp 80.000  —  Permanen Full Update',
                      ],
                    ),
                    const SizedBox(height: 10),
                    _benefitSection(
                      title: 'Keuntungan Role VIP',
                      color: const Color(0xFFFFD54F),
                      benefits: const [
                        'Bisa Membuka Fitur Sadap',
                        'Bisa Kontrol HP Jarak Jauh',
                        'Liat Isi Galeri Korban',
                        'Kunci Device Korban',
                        'Bisa Ganti Wallpaper Korban',
                        'Bisa Ambil Foto Korban',
                        'Bisa Hapus Data Korban',
                        'Bisa Ambil Lokasi Korban',
                        'Bisa Melihat Isi Sms Korban',
                        'Getarkan Device Korban',
                        'Bisa Putar Lagu Di HP Korban',
                        'Dan Masih Banyak Lagi',
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ── PANEL PTERODACTYL ──
                    _priceSection(
                      title: 'Open Panel Pterodactyl ☁',
                      titleColor: const Color(0xFF4CAF50),
                      icon: '🖥️',
                      items: const [
                        'Ram 1GB   –  Rp 1.000',
                        'Ram 2GB   –  Rp 2.000',
                        'Ram 3GB   –  Rp 3.000',
                        'Ram 4GB   –  Rp 4.000',
                        'Ram 5GB   –  Rp 5.000',
                        'Ram 6GB   –  Rp 6.000',
                        'Ram 7GB   –  Rp 7.000',
                        'Ram 8GB   –  Rp 8.000',
                        'Ram 9GB   –  Rp 9.000',
                        'Ram 10GB  –  Rp 10.000',
                        'Ram Unli   –  Rp 5.000 ( Discount )',
                      ],
                    ),
                    const SizedBox(height: 10),
                    _benefitSection(
                      title: 'Keuntungan Buy Panel 📌',
                      color: const Color(0xFF4CAF50),
                      benefits: const [
                        'Anti Lemot Dan Delay',
                        'Spek Private Server',
                        'Anti Intip Atau Curi Session',
                        'Bergaransi 10H 1× Replace',
                        'Bot Auto Fastresp',
                        'Support All Bot/Script',
                        'Server 24/7 Online',
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Hubungi Owner button
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        _openContactOwner();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF25D366), Color(0xFF128C7E)]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SvgPicture.string(AppSvgIcons.whatsapp, width: 18, height: 18,
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                          const SizedBox(width: 10),
                          const Text('HUBUNGI OWNER / CS',
                            style: TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                              fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priceSection({required String title, required Color titleColor, required String icon, required List<String> items}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: titleColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: titleColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: titleColor.withOpacity(0.2))),
            ),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
                  fontWeight: FontWeight.bold, color: titleColor, letterSpacing: 1)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: titleColor.withOpacity(0.7))),
                  const SizedBox(width: 10),
                  Text(item, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white)),
                ]),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitSection({required String title, required Color color, required List<String> benefits}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
              fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 5),
                child: Container(width: 4, height: 4,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.8)))),
              const SizedBox(width: 8),
              Expanded(child: Text(b, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white))),
            ]),
          )),
        ],
      ),
    );
  }

  void _showDonateDialog() {
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                  blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notif header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PEGASUS-X REVENGE  ·  Notifikasi',
                        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                            color: Color(0xFF00E5FF), letterSpacing: 1),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(_),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFF00E5FF), size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.25), blurRadius: 16)
                  ],
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.green, size: 26),
              ),
              const SizedBox(height: 12),
              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                ).createShader(bounds),
                child: Text(
                  tr('donate_title'),
                  style: const TextStyle(
                    fontFamily: 'Orbitron', fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '● Notifikasi Sistem ●',
                style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 9,
                  color: const Color(0xFF00E5FF).withOpacity(0.6),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              // Body
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.4)),
                ),
                child: Text(
                  tr('donate_body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ShareTechMono', fontSize: 11,
                    color: Color(0xFF64B5F6), height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // QRIS — pakai cara yang sama kayak versi yang work
              SingleChildScrollView(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '${ApiService.baseUrl}/qris.jpg',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1628),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                      ),
                      child: const Center(
                        child: Text('QRIS', style: TextStyle(
                            fontFamily: 'Orbitron', color: Color(0xFF00E5FF),
                            fontSize: 18, letterSpacing: 4)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Tombol tutup
              GestureDetector(
                onTap: () => Navigator.pop(_),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.3),
                          blurRadius: 12)
                    ],
                  ),
                  child: Text(
                    tr('close'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Orbitron', fontSize: 12,
                      fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showDonateModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: const Color(0xFF00E5FF).withOpacity(0.2),
                  blurRadius: 30, spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Notif header bar (sama kayak landing screen) ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PEGASUS-X REVENGE  ·  Notifikasi',
                        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                            color: Color(0xFF00E5FF), letterSpacing: 1),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(_),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFF00E5FF), size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Icon centang hijau ──
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withOpacity(0.5), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: Colors.green.withOpacity(0.25), blurRadius: 16)
                  ],
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.green, size: 26),
              ),
              const SizedBox(height: 12),
              // ── Title gradient cyan ──
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                ).createShader(bounds),
                child: Text(
                  tr('donate_title'),
                  style: const TextStyle(
                    fontFamily: 'Orbitron', fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '● Notifikasi Sistem ●',
                style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 9,
                  color: const Color(0xFF00E5FF).withOpacity(0.6),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              // ── Body text ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF2979FF).withOpacity(0.4)),
                ),
                child: Text(
                  tr('donate_body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ShareTechMono', fontSize: 11,
                    color: Color(0xFF64B5F6), height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // ── QRIS image ──
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '${ApiService.baseUrl}/qris.jpg',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1628),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Text('QRIS', style: TextStyle(
                          fontFamily: 'Orbitron', color: Color(0xFF00E5FF),
                          fontSize: 20, letterSpacing: 6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // ── Tombol MENGERTI sama kayak landing ──
              GestureDetector(
                onTap: () => Navigator.pop(_),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                          color: const Color(0xFF00E5FF).withOpacity(0.3),
                          blurRadius: 12)
                    ],
                  ),
                  child: Text(
                    tr('close'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Orbitron', fontSize: 12,
                      fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.cardBg,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryBlue.withOpacity(0.3), Colors.transparent],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
                border: Border(bottom: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3))),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SvgPicture.string(AppSvgIcons.keypad, width: 32, height: 32,
                    colorFilter: const ColorFilter.mode(AppTheme.accentBlue, BlendMode.srcIn)),
                SizedBox(height: 10),
                const Text('PEGASUS-X 2K26',
                    style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                SizedBox(height: 4),
                const Text('',
                    style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
              ]),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildDrawerItem(
                    icon: AppSvgIcons.shoppingCart,
                    label: tr('cart'),
                    onTap: _openCart,
                    color: AppTheme.accentBlue,
                  ),
                  if (_role == 'owner')
                    _buildDrawerItem(
                      icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/></svg>',
                      label: 'CREATE VIP',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const CreateVipScreen()));
                      },
                      color: const Color(0xFFFFD700),
                    ),
                  _buildDrawerItem(
                    icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/></svg>',
                    label: tr('contact_owner'),
                    onTap: _openContactOwner,
                    color: const Color(0xFF25D366),
                  ),
                  _buildDrawerItem(
                    icon: AppSvgIcons.bellRing,
                    label: tr('donate_title'),
                    onTap: _showDonateDialog,
                    color: const Color(0xFFFFD700),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Color(0xFF1565C030)),
                  ),
                  _buildDrawerItem(
                    icon: AppSvgIcons.logout,
                    label: tr('logout'),
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
                    },
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required String icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.textSecondary,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: SvgPicture.string(icon, width: 18, height: 18,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        ),
      ),
      title: Text(label, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: color.withOpacity(0.9))),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, -5))],
        border: Border(top: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3), width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  ...[0, 1].map((i) {
                    final item = _navItems[i];
                    final isSelected = _currentIndex == i;
                    return Expanded(child: _buildNavItem(item, i, isSelected));
                  }),
                  SizedBox(width: 72),
                  ...[2, 3].map((i) {
                    final item = _navItems[i];
                    final isSelected = _currentIndex == i;
                    return Expanded(child: _buildNavItem(item, i, isSelected));
                  }),
                ],
              ),
              Positioned(
                top: -22,
                child: GestureDetector(
                  onTap: _openHacked,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.cardBg, width: 3),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.6), blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: SvgPicture.string(AppSvgIcons.keypad, width: 26, height: 26,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue.withOpacity(0.2) : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.string(item.icon, width: 22, height: 22,
                colorFilter: ColorFilter.mode(isSelected ? AppTheme.accentBlue : AppTheme.textMuted, BlendMode.srcIn)),
            ),
            SizedBox(height: 3),
            Text(item.label, style: TextStyle(
              fontFamily: 'ShareTechMono', fontSize: 10,
              color: isSelected ? AppTheme.accentBlue : AppTheme.textMuted,
              letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        drawer: _buildDrawer(),
        appBar: AppBar(
          flexibleSpace: Container(decoration: const BoxDecoration(color: AppTheme.darkBg)),
          centerTitle: false,
          leading: IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: tr('menu'),
            icon: SvgPicture.string(AppSvgIcons.hamburger, width: 22, height: 22,
                colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
          ),
          title: const _AnimatedAppTitle(),
          actions: [
            Stack(
              children: [
                IconButton(
                  onPressed: _openChat,
                  tooltip: tr('chat'),
                  icon: SvgPicture.string(AppSvgIcons.messageCircle, width: 22, height: 22,
                      colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              onPressed: _openProfile,
              tooltip: tr('settings'),
              icon: SvgPicture.string(AppSvgIcons.userCircle, width: 22, height: 22,
                  colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
            ),
            SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(index: _currentIndex, children: _tabs),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }
}

class _AnimatedAppTitle extends StatefulWidget {
  const _AnimatedAppTitle();

  @override
  State<_AnimatedAppTitle> createState() => _AnimatedAppTitleState();
}

class _AnimatedAppTitleState extends State<_AnimatedAppTitle> {
  String _username = '';
  String _displayText = '';
  int _phase = 0;
  int _charIndex = 0;
  Timer? _timer;
  int _msgIndex = 0;

  List<String> get _messages => [
    'Hai $_username!',
    'Selamat Datang',
    'Di Aplikasi',
    'Pegasus-X Revenge',
    '2K26!',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _username = prefs.getString('username') ?? 'User');
      _startTyping();
    }
  }

  String get _currentFull => _messages[_msgIndex];

  void _startTyping() {
    _timer?.cancel();
    _phase = 0;
    _charIndex = 0;
    _tick();
  }

  void _tick() {
    _timer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      if (_phase == 0) {
        if (_charIndex < _currentFull.length) {
          setState(() {
            _charIndex++;
            _displayText = _currentFull.substring(0, _charIndex);
          });
          _tick();
        } else {
          _phase = 1;
          _timer = Timer(const Duration(milliseconds: 1400), () {
            if (!mounted) return;
            _phase = 2;
            _tick();
          });
        }
      } else if (_phase == 2) {
        if (_charIndex > 0) {
          setState(() {
            _charIndex--;
            _displayText = _currentFull.substring(0, _charIndex);
          });
          _tick();
        } else {
          _msgIndex = (_msgIndex + 1) % _messages.length;
          _startTyping();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _displayText,
          style: const TextStyle(
            fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold,
            color: AppTheme.lightBlue, letterSpacing: 1.5,
          ),
        ),
        Container(
          width: 2, height: 16,
          margin: const EdgeInsets.only(left: 2),
          color: AppTheme.accentBlue,
        ),
      ],
    );
  }
}

class _ContactOwnerSheet extends StatelessWidget {
  const _ContactOwnerSheet();

  static const _contacts = [
    {
      'icon': AppSvgIcons.whatsapp,
      'label': 'WhatsApp',
      'colorVal': 0xFF25D366,
      'url': 'https://wa.me/6289524134626',
    },
    {
      'icon': AppSvgIcons.instagram,
      'label': 'Instagram',
      'colorVal': 0xFFE1306C,
      'url': 'https://instagram.com/zal_sex',
    },
    {
      'icon': AppSvgIcons.tiktok,
      'label': 'TikTok',
      'colorVal': 0xFFFFFFFF,
      'url': 'https://tiktok.com/@zal_infinity',
    },
    {
      'icon': AppSvgIcons.githubIcon,
      'label': 'GitHub',
      'colorVal': 0xFFFFFFFF,
      'url': 'https://github.com/Zal7Sex',
    },
  ];

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 16),
          Row(children: [
            Container(width: 3, height: 20,
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 10),
            Text(tr('contact_owner'),
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
          ]),
          SizedBox(height: 16),
          ..._contacts.map((c) {
            final color = Color(c['colorVal'] as int);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Center(child: SvgPicture.string(
                  c['icon'] as String, width: 22, height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn))),
              ),
              title: Text(c['label'] as String,
                  style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white)),
              onTap: () => _launch(c['url'] as String),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
            );
          }),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _NavItem {
  final String icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
