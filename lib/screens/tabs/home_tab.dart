import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../utils/theme.dart';
import '../../utils/role_style.dart';
import '../../utils/app_localizations.dart';
import '../../services/api_service.dart';
import '../management_app_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  String _username = '';
  String _role = 'member';
  String? _avatarBase64;
  bool _loading = true;
  late VideoPlayerController _bannerController;
  bool _bannerInitialized = false;

  int _onlineUsers = 0;
  int _onlineSenders = 0;
  Timer? _statsTimer;

  // Untuk border foto rotating
  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  static const _overlayChannel = MethodChannel('com.pegasusx.revenge/overlay');
  bool _overlayEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initBanner();
    _loadStats();
    _loadOverlayState();
    _statsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadStats());

    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_glowCtrl);
  }

  Future<void> _loadOverlayState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('overlay_enabled') ?? false;
    final hasPermission = await _checkOverlayPermission();
    setState(() => _overlayEnabled = saved && hasPermission);
  }

  Future<bool> _checkOverlayPermission() async {
    try {
      final result = await _overlayChannel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } catch (_) { return false; }
  }

  Future<void> _toggleOverlay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      final hasPermission = await _checkOverlayPermission();
      if (!hasPermission) {
        await _overlayChannel.invokeMethod('requestPermission');
        await Future.delayed(const Duration(seconds: 1));
        final granted = await _checkOverlayPermission();
        if (!granted) {
          _showSnack(tr('overlay_permission'));
          return;
        }
      }
      final ok = await _overlayChannel.invokeMethod<bool>('startOverlay') ?? false;
      if (ok) {
        setState(() => _overlayEnabled = true);
        await prefs.setBool('overlay_enabled', true);
        _showSnack(tr('overlay_active'));
      }
    } else {
      await _overlayChannel.invokeMethod('stopOverlay');
      setState(() => _overlayEnabled = false);
      await prefs.setBool('overlay_enabled', false);
      _showSnack(tr('overlay_disabled'));
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12)),
      backgroundColor: AppTheme.cardBg,
      duration: const Duration(seconds: 3),
    ));
  }

  Future<void> _initBanner() async {
    try {
      _bannerController = VideoPlayerController.asset('assets/video/banner.mp4')
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _bannerInitialized = true);
            _bannerController.setLooping(true);
            _bannerController.setVolume(0);
            _bannerController.play();
          }
        });
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final res = await ApiService.getStats();
      if (res['success'] == true && mounted) {
        setState(() {
          _onlineUsers = res['onlineUsers'] ?? 0;
          _onlineSenders = res['onlineSenders'] ?? 0;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    if (_bannerInitialized) _bannerController.dispose();
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
      if (res['success'] == true) {
        final user = res['user'];
        setState(() {
          _username = user['username'] ?? _username;
          _role = user['role'] ?? _role;
          _avatarBase64 = user['avatar'];
        });
        await prefs.setString('username', _username);
        await prefs.setString('role', _role);
        await prefs.setString('user_id', user['id'] ?? '');
        if (_avatarBase64 != null) await prefs.setString('avatar', _avatarBase64!);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              _buildBanner(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(tr('information_account')),
                    SizedBox(height: 12),
                    _buildAccountCard(),
                    SizedBox(height: 16),
                    _buildStatsRow(),
                    if (_role == 'owner') ...[
                      SizedBox(height: 16),
                      _buildManagementAppCard(),
                    ],
                    SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF29B6F6), width: 2.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _bannerInitialized
                ? VideoPlayer(_bannerController)
                : Container(
                    color: AppTheme.cardBg,
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2))),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Container(width: 3, height: 22,
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
      SizedBox(width: 10),
      Text(title, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16,
          fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
    ]);
  }

  Widget _buildAccountCard() {
    final avatarWidget = _avatarBase64 != null
        ? Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover)
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.1), blurRadius: 15)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryBlue.withOpacity(0.3), Colors.transparent]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                RoleStyle.instagramPhoto(
                  assetPath: avatarWidget == null ? 'assets/icons/revenge.jpg' : null,
                  customImage: avatarWidget,
                  colors: RoleStyle.loginBorderColors,
                  rotateAnim: _rotateAnim,
                  glowAnim: _glowAnim,
                  size: 54, borderWidth: 3, innerPad: 2,
                  fallback: Container(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    child: Center(child: SvgPicture.string(AppSvgIcons.user, width: 20, height: 20,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_loading ? '...' : _username,
                        style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 5),
                      RoleStyle.roleBadge(_role),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(tr('overlay'), style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, letterSpacing: 1,
                        color: _overlayEnabled ? Colors.greenAccent : AppTheme.textMuted)),
                    SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _toggleOverlay(!_overlayEnabled),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 46, height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: _overlayEnabled ? Colors.greenAccent.withOpacity(0.85) : Colors.white.withOpacity(0.12),
                          border: Border.all(color: _overlayEnabled ? Colors.greenAccent : Colors.white24, width: 1.5),
                          boxShadow: _overlayEnabled ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 8)] : [],
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          alignment: _overlayEnabled ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _overlayEnabled ? Colors.white : Colors.white38,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 1))],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildInfoRow(tr('username'), _username, AppSvgIcons.user),
          _buildInfoRow(tr('password'), '••••••••', AppSvgIcons.lock),
          _buildInfoRow(tr('role'), _role.toUpperCase(), AppSvgIcons.shield),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, String iconSvg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.15)))),
      child: Row(
        children: [
          SvgPicture.string(iconSvg, width: 16, height: 16,
              colorFilter: const ColorFilter.mode(AppTheme.textMuted, BlendMode.srcIn)),
          SizedBox(width: 12),
          Text('$label:', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, letterSpacing: 1)),
          SizedBox(width: 8),
          Expanded(child: Text(_loading ? '...' : value,
              style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white),
              textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(children: [
      Expanded(child: _buildStatCard(label: tr('online_users'), value: _onlineUsers.toString(), color: Colors.green, icon: AppSvgIcons.user)),
      SizedBox(width: 12),
      Expanded(child: _buildStatCard(label: tr('connections'), value: _onlineSenders.toString(), color: AppTheme.accentBlue, icon: AppSvgIcons.mobile)),
    ]);
  }

  Widget _buildStatCard({required String label, required String value, required Color color, required String icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        gradient: LinearGradient(colors: [color.withOpacity(0.12), AppTheme.cardBg], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SvgPicture.string(icon, width: 18, height: 18, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        SizedBox(height: 10),
        Text(value, style: TextStyle(fontFamily: 'Orbitron', fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        SizedBox(height: 4),
        Text(label, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted, letterSpacing: 1)),
      ]),
    );
  }

  Widget _buildManagementAppCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagementAppScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
          gradient: LinearGradient(colors: [Colors.orange.withOpacity(0.12), AppTheme.cardBg], begin: Alignment.centerLeft, end: Alignment.centerRight),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.12), blurRadius: 12)],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.4))),
            child: Center(child: SvgPicture.string(AppSvgIcons.keypad, width: 22, height: 22,
                colorFilter: const ColorFilter.mode(Colors.orange, BlendMode.srcIn)))),
          SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('management_app'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 1)),
            SizedBox(height: 3),
            Text('${tr("manage_sender")} & ${tr("manage_users")}',
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.orange, size: 22),
        ]),
      ),
    );
  }
}
