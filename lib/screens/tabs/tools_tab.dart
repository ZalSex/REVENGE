import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../utils/notif_helper.dart';
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
    // Maker tools — lanjut di grid yang sama
    { 'isMaker': true, 'title': 'Lobby FF',     'color': Color(0xFFFF6B00), 'route': 'lobby_ff',    'matIcon': true },
    { 'isMaker': true, 'title': 'Lobby ML',     'color': Color(0xFF3B82F6), 'route': 'lobby_ml',    'matIcon': true },
    { 'isMaker': true, 'title': 'Fake Story',   'color': Color(0xFFEC4899), 'route': 'fake_story',  'matIcon': true },
    { 'isMaker': true, 'title': 'Fake Threads', 'color': Color(0xFF6B7280), 'route': 'fake_threads','matIcon': true },
    { 'isMaker': true, 'title': 'QC Card',      'color': Color(0xFF10B981), 'route': 'qc',          'matIcon': true },
    { 'isMaker': true, 'title': 'Smeme',        'color': Color(0xFF8B5CF6), 'route': 'smeme',       'matIcon': true },
  ];

  static const Map<String, IconData> _makerIcons = {
    'lobby_ff':    Icons.sports_esports_rounded,
    'lobby_ml':    Icons.videogame_asset_rounded,
    'fake_story':  Icons.auto_stories_rounded,
    'fake_threads':Icons.forum_rounded,
    'qc':          Icons.style_rounded,
    'smeme':       Icons.image_rounded,
  };

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
    Widget? screen;
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
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
  }

  void _openMakerTool(BuildContext context, String route, String title) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _MakerToolScreen(route: route, title: title),
    ));
  }

  void _showComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.5))),
        title: Row(children: [
          Container(width: 3, height: 18,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
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
              const SizedBox(height: 12),
              Text(tr('coming_soon'), style: const TextStyle(fontFamily: 'Orbitron',
                  fontSize: 14, color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(tr('coming_soon_body'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, height: 1.6)),
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
        RoleStyle.instagramPhoto(
          assetPath: _avatarBase64 == null ? 'assets/icons/revenge.jpg' : null,
          customImage: _avatarBase64 != null ? Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover) : null,
          colors: RoleStyle.loginBorderColors,
          rotateAnim: _rotateAnim,
          glowAnim: _glowAnim,
          size: 48, borderWidth: 2.5, innerPad: 2,
          fallback: Container(color: AppTheme.primaryBlue.withOpacity(0.3),
            child: Center(child: SvgPicture.string(AppSvgIcons.user, width: 22, height: 22,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_username.isEmpty ? '...' : _username,
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 5),
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
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 3, height: 20,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text(tr('tools_title'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 18,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
              ]),
              const SizedBox(height: 20),
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
    final color = tool['color'] as Color;
    final isMaker = tool['isMaker'] == true;

    if (isMaker) {
      final icon = _makerIcons[tool['route']] ?? Icons.image_rounded;
      return GestureDetector(
        onTap: () => _openMakerTool(context, tool['route'] as String, tool['title'] as String),
        child: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10)],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withOpacity(0.5))),
                child: Center(child: Icon(icon, color: color, size: 20))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(5), border: Border.all(color: color.withOpacity(0.4))),
                child: Text('MAKER', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 7, color: color, letterSpacing: 0.5))),
            ]),
            const Spacer(),
            Text(tool['title'] as String,
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold,
                  color: Colors.white, letterSpacing: 0.5)),
          ]),
        ),
      );
    }

    final route = tool['route'] as String?;
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

// ─────────────────────────────────────────────────────────────────────────────
// MAKER TOOL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _MakerToolScreen extends StatefulWidget {
  final String route;
  final String title;
  const _MakerToolScreen({required this.route, required this.title});

  @override
  State<_MakerToolScreen> createState() => _MakerToolScreenState();
}

class _MakerToolScreenState extends State<_MakerToolScreen> {
  final Map<String, TextEditingController> _ctrls = {};
  // Fields yang butuh gambar: key → XFile?
  final Map<String, XFile?> _imageFiles = {};
  // Setelah upload ke catbox: key → url
  final Map<String, String> _uploadedUrls = {};

  String? _resultImageUrl;
  bool _loading = false;
  String? _error;
  String? _uploadingKey; // key field yang sedang upload

  // Field definitions per tool
  // isImage: true → upload gambar, bukan input URL
  Map<String, List<Map<String, String>>> get _fields => {
    'lobby_ff': [
      {'key': 'nickname', 'label': 'Nickname', 'hint': 'NamaKamu'},
    ],
    'lobby_ml': [
      {'key': 'nickname', 'label': 'Nickname', 'hint': 'NamaKamu'},
      {'key': 'avatar', 'label': 'Avatar', 'hint': 'Upload gambar avatar', 'isImage': 'true'},
    ],
    'fake_story': [
      {'key': 'username', 'label': 'Username', 'hint': '@namauser'},
      {'key': 'caption', 'label': 'Caption', 'hint': 'Isi caption...'},
      {'key': 'avatar', 'label': 'Avatar', 'hint': 'Upload gambar avatar', 'isImage': 'true'},
    ],
    'fake_threads': [
      {'key': 'username', 'label': 'Username', 'hint': '@namauser'},
      {'key': 'avatar', 'label': 'Avatar', 'hint': 'Upload gambar avatar', 'isImage': 'true'},
      {'key': 'text', 'label': 'Text', 'hint': 'Isi threads...'},
      {'key': 'likes', 'label': 'Likes', 'hint': '1000'},
    ],
    'qc': [
      {'key': 'name', 'label': 'Nama', 'hint': 'NamaKamu'},
      {'key': 'avatar', 'label': 'Avatar', 'hint': 'Upload gambar avatar', 'isImage': 'true'},
      {'key': 'text', 'label': 'Teks', 'hint': 'Isi quote...'},
      {'key': 'color', 'label': 'Warna', 'hint': 'hitam / putih'},
    ],
    'smeme': [
      {'key': 'text_atas', 'label': 'Teks Atas', 'hint': 'Teks atas...'},
      {'key': 'text_bawah', 'label': 'Teks Bawah', 'hint': 'Teks bawah...'},
      {'key': 'background', 'label': 'Background', 'hint': 'Upload gambar background', 'isImage': 'true'},
    ],
  };

  @override
  void initState() {
    super.initState();
    final fields = _fields[widget.route] ?? [];
    for (final f in fields) {
      if (f['isImage'] != 'true') {
        _ctrls[f['key']!] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  // Upload gambar ke catbox.moe, return URL
  Future<String?> _uploadToCatbox(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );
      request.fields['reqtype'] = 'fileupload';
      request.files.add(http.MultipartFile.fromBytes(
        'fileToUpload',
        bytes,
        filename: file.name.isEmpty ? 'image.jpg' : file.name,
      ));
      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = await response.stream.bytesToString();
      if (body.startsWith('https://')) return body.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage(String key) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() {
      _imageFiles[key] = file;
      _uploadedUrls.remove(key); // reset url lama
      _uploadingKey = key;
    });

    final url = await _uploadToCatbox(file);
    if (mounted) {
      setState(() {
        _uploadingKey = null;
        if (url != null) {
          _uploadedUrls[key] = url;
        } else {
          showError(context, 'Gagal upload ke catbox, coba lagi');
          _imageFiles.remove(key);
        }
      });
    }
  }

  String _getParamValue(String key) {
    if (_fields[widget.route]?.any((f) => f['key'] == key && f['isImage'] == 'true') == true) {
      return _uploadedUrls[key] ?? '';
    }
    return _ctrls[key]?.text ?? '';
  }

  String _buildApiUrl() {
    final base = 'https://api.nexray.web.id/maker';
    switch (widget.route) {
      case 'lobby_ff':
        return '$base/fakelobyff?nickname=${Uri.encodeComponent(_getParamValue('nickname'))}';
      case 'lobby_ml':
        return '$base/fakelobyml?avatar=${Uri.encodeComponent(_getParamValue('avatar'))}&nickname=${Uri.encodeComponent(_getParamValue('nickname'))}';
      case 'fake_story':
        return '$base/fakestory?username=${Uri.encodeComponent(_getParamValue('username'))}&caption=${Uri.encodeComponent(_getParamValue('caption'))}&avatar=${Uri.encodeComponent(_getParamValue('avatar'))}';
      case 'fake_threads':
        return '$base/fakethreads?username=${Uri.encodeComponent(_getParamValue('username'))}&avatar=${Uri.encodeComponent(_getParamValue('avatar'))}&text=${Uri.encodeComponent(_getParamValue('text'))}&likes=${Uri.encodeComponent(_getParamValue('likes').isEmpty ? '1000' : _getParamValue('likes'))}';
      case 'qc':
        return '$base/qc?text=${Uri.encodeComponent(_getParamValue('text'))}&name=${Uri.encodeComponent(_getParamValue('name'))}&avatar=${Uri.encodeComponent(_getParamValue('avatar'))}&color=${Uri.encodeComponent(_getParamValue('color').isEmpty ? 'hitam' : _getParamValue('color'))}';
      case 'smeme':
        return '$base/smeme?text_atas=${Uri.encodeComponent(_getParamValue('text_atas'))}&text_bawah=${Uri.encodeComponent(_getParamValue('text_bawah'))}&background=${Uri.encodeComponent(_getParamValue('background'))}';
      default:
        return '';
    }
  }

  Future<void> _generate() async {
    final fields = _fields[widget.route] ?? [];

    // Validasi semua field
    for (final f in fields) {
      final key = f['key']!;
      final isImg = f['isImage'] == 'true';
      if (isImg) {
        if (_uploadedUrls[key] == null || _uploadedUrls[key]!.isEmpty) {
          showError(context, '${f[');
          return;
        }
      } else {
        if ((_ctrls[key]?.text ?? '').isEmpty) {
          showError(context, '${f[');
          return;
        }
      }
    }

    if (_uploadingKey != null) {
      showWarning(context, 'Tunggu upload gambar selesai...');
      return;
    }

    setState(() { _loading = true; _error = null; _resultImageUrl = null; });

    try {
      final url = _buildApiUrl();
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final contentType = res.headers['content-type'] ?? '';
        if (contentType.contains('image')) {
          final b64 = base64Encode(res.bodyBytes);
          final ext = contentType.contains('png') ? 'png' : 'jpg';
          setState(() => _resultImageUrl = 'data:image/$ext;base64,$b64');
        } else {
          try {
            final json = jsonDecode(res.body);
            final imgUrl = json['result'] ?? json['url'] ?? json['image'] ?? json['data'];
            if (imgUrl != null) {
              setState(() => _resultImageUrl = imgUrl.toString());
            } else {
              setState(() => _error = 'Tidak ada gambar dalam response');
            }
          } catch (_) {
            setState(() => _error = 'Response tidak valid');
          }
        }
      } else {
        setState(() => _error = 'API Error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _downloadImage() async {
    if (_resultImageUrl == null) return;
    try {
      final dir = Directory('/storage/emulated/0/Pictures/Pegasus-X');
      if (!await dir.exists()) await dir.create(recursive: true);
      final fileName = '${widget.route}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      if (_resultImageUrl!.startsWith('data:')) {
        final data = _resultImageUrl!.split(',')[1];
        await file.writeAsBytes(base64Decode(data));
      } else {
        final res = await http.get(Uri.parse(_resultImageUrl!));
        await file.writeAsBytes(res.bodyBytes);
      }
      if (mounted) {
        showSuccess(context, 'Tersimpan: ${dir.path}/$fileName');
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Gagal download: $e');
      }
    }
  }

  Color get _toolColor {
    const colors = {
      'lobby_ff': Color(0xFFFF6B00), 'lobby_ml': Color(0xFF3B82F6),
      'fake_story': Color(0xFFEC4899), 'fake_threads': Color(0xFF6B7280),
      'qc': Color(0xFF10B981), 'smeme': Color(0xFF8B5CF6),
    };
    return colors[widget.route] ?? AppTheme.accentBlue;
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields[widget.route] ?? [];
    final color = _toolColor;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
        title: Text(widget.title.toUpperCase(),
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          if (_resultImageUrl != null)
            IconButton(
              onPressed: _downloadImage,
              icon: Icon(Icons.download_rounded, color: color),
              tooltip: 'Download'),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            ...fields.map((f) {
              final key = f['key']!;
              final isImg = f['isImage'] == 'true';

              if (isImg) {
                return _buildImageField(key, f['label']!, color);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f['label']!, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.4)), color: AppTheme.cardBg),
                    child: TextField(
                      controller: _ctrls[key],
                      style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: f['hint'],
                        hintStyle: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _loading ? null : _generate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Center(child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('GENERATE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 2))),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.4)), color: Colors.red.withOpacity(0.06)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.redAccent))),
                ]),
              ),
            ],
            if (_resultImageUrl != null) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _resultImageUrl!.startsWith('data:')
                      ? Image.memory(base64Decode(_resultImageUrl!.split(',')[1]))
                      : Image.network(_resultImageUrl!, loadingBuilder: (_, child, prog) =>
                          prog == null ? child : const Center(child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2)))),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _downloadImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.5)),
                    color: color.withOpacity(0.1),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.download_rounded, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text('SIMPAN KE GALERI', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: color, letterSpacing: 1)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildImageField(String key, String label, Color color) {
    final file = _imageFiles[key];
    final url = _uploadedUrls[key];
    final isUploading = _uploadingKey == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 1)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: isUploading ? null : () => _pickImage(key),
          child: Container(
            width: double.infinity,
            height: file != null ? null : 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: url != null ? Colors.green.withOpacity(0.6) : color.withOpacity(0.4),
                width: 1.5,
              ),
              color: AppTheme.cardBg,
            ),
            child: isUploading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                    SizedBox(height: 8),
                    Text('Mengupload ke catbox...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.orange)),
                  ]),
                )
              : file != null
                ? Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(File(file.path), width: double.infinity, height: 150, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(height: 150,
                          child: Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 40)))),
                    ),
                    if (url != null)
                      Positioned(top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Uploaded', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white)),
                          ]),
                        )),
                    Positioned(bottom: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => _pickImage(key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Ganti', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white)),
                          ]),
                        ))),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.upload_rounded, color: color.withOpacity(0.6), size: 30),
                    const SizedBox(height: 6),
                    Text('Tap untuk upload gambar', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text('Auto convert ke catbox', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted.withOpacity(0.5))),
                  ]),
          ),
        ),
      ]),
    );
  }
}
