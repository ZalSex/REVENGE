import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../utils/app_localizations.dart';
import '../../utils/role_style.dart';
import '../../services/api_service.dart';
import '../ddos_screen.dart';
import '../downloader_screen.dart';
import '../iqc_screen.dart';
import '../spam_pairing_screen.dart';
import '../wa_call_screen.dart';
import '../remini_screen.dart';
import '../spam_ngl_screen.dart';

class ToolsTab extends StatefulWidget {
  const ToolsTab({super.key});

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab> with TickerProviderStateMixin {
  String _username = '';
  String _role = 'member';
  String? _avatarBase64;

  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  static const List<Map<String, dynamic>> _tools = [
    { 'icon': AppSvgIcons.zap,     'title': 'DDoS Tool',     'color': Color(0xFFEF4444), 'route': 'ddos' },
    { 'icon': AppSvgIcons.download,'title': 'Downloader',    'color': Color(0xFF06B6D4), 'route': 'downloader' },
    { 'icon': AppSvgIcons.quote,   'title': 'iPhone Quote',  'color': Color(0xFF8B5CF6), 'route': 'iqc' },
    { 'icon': AppSvgIcons.wifi,    'title': 'Spam Pairing',  'color': Color(0xFF3B82F6), 'route': 'spam_pairing' },
    { 'icon': AppSvgIcons.phone,   'title': 'WhatsApp Call', 'color': Color(0xFFF59E0B), 'route': 'wa_call' },
    { 'icon': AppSvgIcons.image,   'title': 'Remini AI',     'color': Color(0xFF8B5CF6), 'route': 'remini' },
    { 'icon': AppSvgIcons.sms,     'title': 'Spam NGL',      'color': Color(0xFFEC4899), 'route': 'spam_ngl' },
    { 'icon': AppSvgIcons.skull,   'title': 'Crash Sender',  'color': Color(0xFF6B7280), 'route': null },
    { 'icon': AppSvgIcons.eyeOff,  'title': 'Ghost Mode',    'color': Color(0xFF6B7280), 'route': null },
    { 'icon': AppSvgIcons.trash,   'title': 'Data Wiper',    'color': Color(0xFF6B7280), 'route': null },
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();

    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_glowCtrl);
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? '';
        _role = prefs.getString('role') ?? 'member';
        _avatarBase64 = prefs.getString('avatar');
      });
      final res = await ApiService.getProfile();
      if (res['success'] == true && mounted) {
        setState(() {
          _username = res['user']['username'] ?? _username;
          _role = res['user']['role'] ?? _role;
          _avatarBase64 = res['user']['avatar'] ?? _avatarBase64;
        });
      }
    } catch (_) {}
  }

  void _navigate(BuildContext context, String? route, String title) {
    if (route == null) { _showComingSoon(context, title); return; }
    Widget screen;
    switch (route) {
      case 'ddos':         screen = const DdosScreen(); break;
      case 'downloader':   screen = const DownloaderScreen(); break;
      case 'iqc':          screen = const IqcScreen(); break;
      case 'spam_pairing': screen = const SpamPairingScreen(); break;
      case 'wa_call':      screen = const WaCallScreen(); break;
      case 'remini':       screen = const ReminiScreen(); break;
      case 'spam_ngl':     screen = const SpamNglScreen(); break;
      default:             _showComingSoon(context, title); return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _showComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.5))),
        title: Row(children: [
          Container(width: 3, height: 18,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
          SizedBox(width: 10),
          Text(title.toUpperCase(), style: const TextStyle(fontFamily: 'Orbitron',
              color: Colors.white, fontSize: 13, letterSpacing: 1.5)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3))),
            child: Column(children: [
              SvgPicture.string(AppSvgIcons.zap, width: 36, height: 36,
                colorFilter: ColorFilter.mode(Colors.orange.withOpacity(0.8), BlendMode.srcIn)),
              SizedBox(height: 12),
              Text(tr('coming_soon'), style: TextStyle(fontFamily: 'Orbitron',
                  fontSize: 14, color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(tr('coming_soon_body'),
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, height: 1.6)),
            ])),
        ]),
        actions: [
          Container(decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(8)),
            child: TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Ok', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 11, letterSpacing: 1)))),
        ],
      ),
    );
  }

  Widget _buildProfileBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primaryBlue.withOpacity(0.25), AppTheme.cardBg],
          begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.15), blurRadius: 12)],
      ),
      child: Row(children: [
        // === Foto user — border biru seperti login, rotating ===
        RoleStyle.instagramPhoto(
          assetPath: _avatarBase64 == null ? 'assets/icons/revenge.jpg' : null,
          customImage: _avatarBase64 != null ? Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover) : null,
          colors: RoleStyle.loginBorderColors,
          rotateAnim: _rotateAnim,
          glowAnim: _glowAnim,
          size: 48,
          borderWidth: 2.5,
          innerPad: 2,
          fallback: Container(color: AppTheme.primaryBlue.withOpacity(0.3),
            child: Center(child: SvgPicture.string(AppSvgIcons.user, width: 22, height: 22,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
        ),
        SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_username.isEmpty ? '...' : _username,
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
          SizedBox(height: 5),
          // === Badge role sesuai warna ===
          RoleStyle.roleBadge(_role),
        ])),
        Container(width: 8, height: 8,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green,
            boxShadow: [BoxShadow(color: Colors.green, blurRadius: 6)])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: CustomScrollView(slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildProfileBadge(),
              SizedBox(height: 16),
              Row(children: [
                Container(width: 3, height: 20,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                SizedBox(width: 10),
                Text(tr('tools_title'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 18,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
              ]),
              SizedBox(height: 20),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 1.05, crossAxisSpacing: 14, mainAxisSpacing: 14),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildToolCard(ctx, _tools[i]),
              childCount: _tools.length),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ]),
    );
  }

  Widget _buildToolCard(BuildContext context, Map<String, dynamic> tool) {
    final color   = tool['color'] as Color;
    final route   = tool['route'] as String?;
    final isActive = route != null;

    return GestureDetector(
      onTap: () => _navigate(context, route, tool['title'] as String),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? color.withOpacity(0.5) : color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: isActive ? color.withOpacity(0.15) : Colors.transparent, blurRadius: 10)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.2) : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? color.withOpacity(0.5) : color.withOpacity(0.2))),
              child: Center(child: SvgPicture.string(tool['icon'] as String, width: 20, height: 20,
                colorFilter: ColorFilter.mode(isActive ? color : color.withOpacity(0.4), BlendMode.srcIn)))),
            if (!isActive)
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.4))),
                child: const Text('Soon', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8,
                    color: Colors.orange, letterSpacing: 1))),
          ]),
          const Spacer(),
          Text(tool['title'] as String,
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.4), letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}
