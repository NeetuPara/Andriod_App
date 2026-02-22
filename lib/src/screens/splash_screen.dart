import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startInitialization();
  }

  void _startInitialization() async {
    // Simulate loading/initialization
    for (int i = 0; i <= 100; i++) {
      await Future.delayed(const Duration(milliseconds: 20));
      if (mounted) {
        setState(() {
          _progress = i / 100;
        });
      }
    }
    
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatApp()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0d93f2);
    const backgroundDark = Color(0xFF101b22);

    return Scaffold(
      backgroundColor: backgroundDark,
      body: Stack(
        children: [
          // Radial Gradient Background
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.0,
                  colors: [
                    primaryColor.withValues(alpha: 0.1),
                    backgroundDark,
                    backgroundDark,
                  ],
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const Spacer(),
                
                // Central Visual Container
                Center(
                  child: SizedBox(
                    width: 280, // Slightly larger for the GIF
                    height: 280,
                    child: Image.asset(
                      'assets/Live chatbot.gif',
                      fit: BoxFit.contain,
                    ),
                  ).animate().fadeIn(duration: 800.ms).scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1)),
                ),
                
                const SizedBox(height: 48),
                
                // Title
                Text(
                  "EdgeMind",
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ).animate().fadeIn(delay: 200.ms).moveY(begin: 10, end: 0),
                
                Text(
                  "GET LIFE IN CONTROL",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 4,
                    color: primaryColor.withValues(alpha: 0.8),
                  ),
                ).animate().fadeIn(delay: 400.ms),
                
                const Spacer(),
                
                // Loading Section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Initializing Core",
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.4),
                            ),
                          ),
                          Text(
                            "${(_progress * 100).toInt()}%",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 3,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          valueColor: const AlwaysStoppedAnimation(primaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock, size: 14, color: Colors.white38),
                    const SizedBox(width: 8),
                    Text(
                      "SECURE PIN ACCESS ENABLED",
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Colors.white38,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // iOS Home Indicator Spacer
                Container(
                  width: 120,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
