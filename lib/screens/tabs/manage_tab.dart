import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../utils/app_localizations.dart';
import '../../utils/role_style.dart';
import '../../services/api_service.dart';

class ManageTab extends StatefulWidget {
  const ManageTab({super.key});

  @override
  State<ManageTab> createState() => _ManageTabState();
}

class _ManageTabState extends State<ManageTab> with TickerProviderStateMixin {
  List<Map<String, dynamic>> _senders = [];
  bool _loading = true;
  bool _adding = false;
  String? _pairingCode;
  String? _pairingSenderId;
  Timer? _statusTimer;
  String _username = '';
  String _role = 'member';
  String? _avatarBase64;

  final TextEditingController _phoneController = TextEditingController();

  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _loadSenders();
    _loadProfile();

    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_glowCtrl);
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

  @override
  void dispose() {
    _statusTimer?.cancel();
    _phoneController.dispose();
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSenders() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.getSenders();
      if (res['success'] == true) {
        setState(() => _senders = List<Map<String, dynamic>>.from(res['senders'] ?? []));
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _showAddSenderDialog() {
    _phoneController.clear();
    showDialog(
      context: context,
      barrierDismissible: !_adding,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.5)),
          ),
          title: Row(
            children: [
              Container(width: 3, height: 18,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
              SizedBox(width: 10),
              Text(tr('add_sender_title'), style: TextStyle(
                  fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, letterSpacing: 1.5)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('phone_hint'),
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
              SizedBox(height: 12),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white),
                decoration: InputDecoration(
                  hintText: '628xxxxxxxxxx',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontFamily: 'ShareTechMono', fontSize: 13),
                  prefixIcon: const Icon(Icons.phone, color: AppTheme.primaryBlue, size: 18),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.4)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue),
                  ),
                  filled: true,
                  fillColor: AppTheme.primaryBlue.withOpacity(0.05),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: _adding ? null : () => Navigator.pop(ctx),
              child: Text(tr('cancel'),
                  style: const TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 11)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: _adding ? null : AppTheme.primaryGradient,
                color: _adding ? AppTheme.primaryBlue.withOpacity(0.3) : null,
                borderRadius: BorderRadius.circular(8),
              ),
              child: TextButton(
                onPressed: _adding
                    ? null
                    : () async {
                        final phone = _phoneController.text.trim();
                        if (phone.isEmpty) {
                          _showSnack('Masukkan Nomor Terlebih Dahulu', isError: true);
                          return;
                        }
                        setDialogState(() {});
                        await _addSender(phone, setDialogState);
                      },
                child: _adding
                    ? SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('get_code'),
                        style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 11)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSender(String phone, StateSetter setDialogState) async {
    setState(() => _adding = true);
    setDialogState(() {});

    try {
      final res = await ApiService.addSenderWithPhone(phone);
      if (res['success'] == true) {
        setState(() {
          _pairingCode = res['code'];
          _pairingSenderId = res['sessionId'];
        });
        if (mounted) Navigator.pop(context);
        _startPolling();
      } else {
        _showSnack(res['message'] ?? 'Gagal Menambah Sender', isError: true);
      }
    } catch (e) {
      _showSnack('Koneksi Gagal Ke Server', isError: true);
    }

    setState(() => _adding = false);
    setDialogState(() {});
  }

  void _startPolling() {
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_pairingSenderId == null) return;
      try {
        final res = await ApiService.getSenderStatus(_pairingSenderId!);
        if (res['status'] == 'connected' || res['status'] == 'online') {
          _statusTimer?.cancel();
          setState(() {
            _pairingCode = null;
            _pairingSenderId = null;
          });
          _showSnack('Sender Berhasil Terhubung!');
          _loadSenders();
        }
      } catch (_) {}
    });
  }

  Future<void> _deleteSender(String senderId, String phone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
        title: Text(tr('delete_sender_title'),
            style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 14, letterSpacing: 1)),
        content: Text('Hapus Sender +$phone?',
            style: const TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal',
                  style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 11))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Hapus',
                  style: TextStyle(fontFamily: 'Orbitron', color: Colors.red, fontSize: 11))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final res = await ApiService.deleteSender(senderId);
        if (res['success'] == true) {
          _showSnack('Sender Berhasil Dihapus');
          _loadSenders();
        } else {
          _showSnack(res['message'] ?? 'Gagal Hapus', isError: true);
        }
      } catch (_) {
        _showSnack('Koneksi Gagal', isError: true);
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'ShareTechMono')),
      backgroundColor: isError ? Colors.red.shade800 : AppTheme.primaryBlue,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileBadge(),
                  SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                              width: 3,
                              height: 20,
                              decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(2))),
                          SizedBox(width: 10),
                          Text(tr('manage_sender_title'),
                              style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2)),
                        ],
                      ),
                      GestureDetector(
                        onTap: _loadSenders,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 18),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.only(left: 13),
                    child: Text(tr('manage_sender_sub'),
                        style: TextStyle(
                            fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
                  ),
                  SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.green.withOpacity(0.12),
                              Colors.green.withOpacity(0.04),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SvgPicture.string(AppSvgIcons.phone, width: 16, height: 16,
                                  colorFilter: ColorFilter.mode(Colors.green.withOpacity(0.8), BlendMode.srcIn)),
                              SizedBox(height: 8),
                              Text(
                                '${_senders.where((s) => s['status'] == 'online' || s['status'] == 'connected').length}',
                                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 20,
                                    fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const Text('Online', style: TextStyle(fontFamily: 'ShareTechMono',
                                  fontSize: 9, color: Colors.green, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              AppTheme.primaryBlue.withOpacity(0.15),
                              AppTheme.primaryBlue.withOpacity(0.04),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SvgPicture.string(AppSvgIcons.manage, width: 16, height: 16,
                                  colorFilter: const ColorFilter.mode(AppTheme.accentBlue, BlendMode.srcIn)),
                              SizedBox(height: 8),
                              Text(
                                '${_senders.length}',
                                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 20,
                                    fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const Text('Total', style: TextStyle(fontFamily: 'ShareTechMono',
                                  fontSize: 9, color: AppTheme.accentBlue, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [
                              Colors.orange.withOpacity(0.12),
                              Colors.orange.withOpacity(0.04),
                            ]),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withOpacity(0.3)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SvgPicture.string(AppSvgIcons.zap, width: 16, height: 16,
                                  colorFilter: ColorFilter.mode(Colors.orange.withOpacity(0.8), BlendMode.srcIn)),
                              SizedBox(height: 8),
                              Text(
                                '${_senders.where((s) => s['status'] != 'online' && s['status'] != 'connected').length}',
                                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 20,
                                    fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              const Text('Offline', style: TextStyle(fontFamily: 'ShareTechMono',
                                  fontSize: 9, color: Colors.orange, letterSpacing: 1)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: _adding ? null : AppTheme.primaryGradient,
                        color: _adding ? AppTheme.primaryBlue.withOpacity(0.3) : null,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: _adding
                            ? []
                            : [
                                BoxShadow(
                                    color: AppTheme.primaryBlue.withOpacity(0.4),
                                    blurRadius: 15,
                                    offset: const Offset(0, 4))
                              ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _adding ? null : _showAddSenderDialog,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: _adding
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : SvgPicture.string(AppSvgIcons.plus,
                                width: 18,
                                height: 18,
                                colorFilter:
                                    const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                        label: Text(
                            _adding ? tr('connecting') : tr('add_sender'),
                            style: const TextStyle(
                                fontFamily: 'Orbitron',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 2)),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),

                  if (_pairingCode != null) _buildPairingCodeSection(),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: [
                        SvgPicture.string(AppSvgIcons.phone,
                            width: 16,
                            height: 16,
                            colorFilter: const ColorFilter.mode(
                                AppTheme.textSecondary, BlendMode.srcIn)),
                        SizedBox(width: 10),
                        Text('${_senders.length} Sender Terhubung',
                            style: const TextStyle(
                                fontFamily: 'ShareTechMono',
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                letterSpacing: 1)),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                ],
              ),
            ),
          ),

          _loading
              ? const SliverToBoxAdapter(
                  child: Center(
                      child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                )))
              : _senders.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmptyState())
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildSenderCard(_senders[i]),
                          ),
                          childCount: _senders.length,
                        ),
                      ),
                    ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  Widget _buildPairingCodeSection() {
    final code = _pairingCode ?? '';
    final displayCode = code.length == 8
        ? '${code.substring(0, 4)}-${code.substring(4)}'
        : code;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.2), blurRadius: 20)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.lock_open, color: AppTheme.accentBlue, size: 20),
              SizedBox(width: 10),
              Text(tr('pairing_code'),
                  style: TextStyle(
                      fontFamily: 'Orbitron', fontSize: 13, color: Colors.white, letterSpacing: 2)),
              const Spacer(),
              SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.accentBlue)),
            ],
          ),
          SizedBox(height: 6),
          const Text(
              'Buka WhatsApp > Perangkat Tertaut > Tautkan Dengan Nomor Telepon',
              style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
          SizedBox(height: 24),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
            ),
            child: Column(
              children: [
                Text(tr('pairing_enter'),
                    style: TextStyle(
                        fontFamily: 'ShareTechMono',
                        fontSize: 10,
                        color: AppTheme.textMuted,
                        letterSpacing: 1)),
                SizedBox(height: 12),
                Text(
                  displayCode,
                  style: const TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 6,
                  ),
                ),
                SizedBox(height: 8),
                Text(tr('pairing_valid'),
                    style: TextStyle(
                        fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
              ],
            ),
          ),
          SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              _statusTimer?.cancel();
              setState(() {
                _pairingCode = null;
                _pairingSenderId = null;
              });
            },
            icon: const Icon(Icons.close, size: 14, color: Colors.red),
            label: Text(tr('pairing_cancel'),
                style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 10, color: Colors.red, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }

  Widget _buildSenderCard(Map<String, dynamic> sender) {
    final isConnected = sender['status'] == 'connected' || sender['status'] == 'online';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isConnected
                ? Colors.green.withOpacity(0.4)
                : AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: isConnected
                  ? Colors.green.withOpacity(0.15)
                  : AppTheme.primaryBlue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isConnected
                      ? Colors.green.withOpacity(0.4)
                      : AppTheme.primaryBlue.withOpacity(0.4)),
            ),
            child: Center(
                child: SvgPicture.string(AppSvgIcons.phone,
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(
                        isConnected ? Colors.green : AppTheme.primaryBlue, BlendMode.srcIn))),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('+${sender['phone'] ?? 'Unknown'}',
                    style: const TextStyle(
                        fontFamily: 'Orbitron', fontSize: 13, color: Colors.white, letterSpacing: 1)),
                SizedBox(height: 3),
                Row(
                  children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isConnected ? Colors.green : Colors.orange,
                        )),
                    SizedBox(width: 6),
                    Text(isConnected ? tr('sender_terhubung') : tr('sender_terputus'),
                        style: TextStyle(
                            fontFamily: 'ShareTechMono',
                            fontSize: 10,
                            color: isConnected ? Colors.green : Colors.orange,
                            letterSpacing: 1)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _deleteSender(sender['id'] as String, sender['phone'] ?? ''),
            icon: SvgPicture.string(AppSvgIcons.trash,
                width: 18,
                height: 18,
                colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn)),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          SvgPicture.string(AppSvgIcons.phone,
              width: 56,
              height: 56,
              colorFilter: ColorFilter.mode(AppTheme.textMuted.withOpacity(0.4), BlendMode.srcIn)),
          SizedBox(height: 16),
          Text(tr('no_sender'),
              style: TextStyle(
                  fontFamily: 'Orbitron', fontSize: 13, color: AppTheme.textMuted, letterSpacing: 2)),
          SizedBox(height: 6),
          Text(tr('add_sender_hint'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, height: 1.6)),
        ],
      ),
    );
  }
}