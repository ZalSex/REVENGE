import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _floatCtrl;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _floatCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat(reverse: true);
    _floatAnim = Tween<double>(begin: -8.0, end: 8.0).animate(
        CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));

    // Show free app notif
    WidgetsBinding.instance.addPostFrameCallback((_) => _showFreeNotif());
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  void _showFreeNotif() {
    if (!mounted) return;
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
                  blurRadius: 30,
                  spreadRadius: 2),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon notif style
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: Colors.green.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(Icons.check_circle_outline_rounded,
                    color: Colors.green, size: 26),
              ),
              const SizedBox(height: 14),
              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                ).createShader(bounds),
                child: const Text(
                  'APLIKASI INI FREE',
                  style: TextStyle(
                    fontFamily: 'Orbitron',
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '● Notifikasi Sistem ●',
                style: TextStyle(
                  fontFamily: 'ShareTechMono',
                  fontSize: 9,
                  color: const Color(0xFF00E5FF).withOpacity(0.6),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF2979FF).withOpacity(0.4)),
                ),
                child: const Text(
                  'Jika Ada Yang Menjual Aplikasi Ini,\nSilahkan Hubungi Owner Segera!\n\nJangan Tertipu Penipuan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'ShareTechMono',
                    fontSize: 12,
                    color: Color(0xFF64B5F6),
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 18),
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
                  child: const Text(
                    'MENGERTI',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
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



  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Background subtle grid / particle effect
            Positioned.fill(
              child: CustomPaint(
                painter: _GridPainter(),
              ),
            ),

            // Main content
            Column(
              children: [
                const SizedBox(height: 30),

                // ─── Title di atas foto ───
                _buildTitle(),

                const SizedBox(height: 10),

                // ─── Anime Character ───
                Expanded(
                  child: AnimatedBuilder(
                    animation: _floatAnim,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _floatAnim.value),
                      child: child,
                    ),
                    child: AnimatedBuilder(
                      animation: _glowAnim,
                      builder: (_, child) => Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00E5FF)
                                  .withOpacity(0.15 * _glowAnim.value),
                              blurRadius: 60,
                              spreadRadius: 20,
                            ),
                          ],
                        ),
                        child: child,
                      ),
                      child: Image.asset(
                        'assets/icons/anime.jpg',
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_not_supported,
                          color: Colors.white24,
                          size: 80,
                        ),
                      ),
                    ),
                  ),
                ),

                // ─── Buttons ───
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                  child: Column(
                    children: [
                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginScreen()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ).copyWith(
                            backgroundColor:
                                MaterialStateProperty.all(Colors.transparent),
                          ),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00E5FF), Color(0xFF1565C0)],
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Container(
                              width: double.infinity,
                              alignment: Alignment.center,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(Icons.login_rounded,
                                      color: Colors.white, size: 18),
                                  SizedBox(width: 10),
                                  Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      fontFamily: 'Orbitron',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 4,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Registrasi Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const RegisterScreen()),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: const BorderSide(
                                color: Color(0xFF00E5FF), width: 1.5),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.person_add_rounded,
                                  color: Color(0xFF00E5FF), size: 18),
                              SizedBox(width: 10),
                              Text(
                                'REGISTRASI',
                                style: TextStyle(
                                  fontFamily: 'Orbitron',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  letterSpacing: 3,
                                  color: Color(0xFF00E5FF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        // PEGASUS-X
        Text(
          'PEGASUS-X',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Deltha',
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        // Divider line
        Container(
          height: 1,
          width: 220,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                Color(0xFF00E5FF),
                Colors.transparent
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        // REVENGE
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF00E5FF), Color(0xFF64B5F6), Color(0xFF2979FF)],
          ).createShader(bounds),
          child: const Text(
            'R  E  V  E  N  G  E',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Orbitron',
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 8,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

// Subtle grid background painter
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00E5FF).withOpacity(0.03)
      ..strokeWidth = 1;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
