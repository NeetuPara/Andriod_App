import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Deep Ocean Base
        Container(
          color: const Color(0xFF0A1825), // Deep Blue-Grey
        ),
        
        // Orb 1: Calm Teal (Top Left)
        Positioned(
          top: -100,
          left: -100,
          child: _buildOrb(const Color(0xFF468F82).withOpacity(0.4)),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .move(begin: const Offset(0, 0), end: const Offset(50, 50), duration: 5.seconds),

        // Orb 2: Sage Green (Bottom Right)
        Positioned(
          bottom: -100,
          right: -100,
          child: _buildOrb(const Color(0xFFBAC7B2).withOpacity(0.3)),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .move(begin: const Offset(0, 0), end: const Offset(-50, -50), duration: 7.seconds),

        // Orb 3: Deep Blue accent (Center-ish)
        Positioned(
          top: MediaQuery.of(context).size.height * 0.3,
          right: -50,
          child: _buildOrb(const Color(0xFF153664).withOpacity(0.3), size: 400),
        ).animate(onPlay: (c) => c.repeat(reverse: true))
         .scale(begin: const Offset(1, 1), end: const Offset(1.2, 1.2), duration: 10.seconds),

        // Blur Filter to merge them into an "Aurora"
        Positioned.fill(
          child: BackdropFilter(
            filter: MainUtil.isDesktop ? 
              // Strong blur for desktop
              ui.ImageFilter.blur(sigmaX: 100, sigmaY: 100) : 
              // Lighter blur for mobile performance
              ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }

  Widget _buildOrb(Color color, {double size = 500}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class MainUtil {
  static bool get isDesktop {
    try {
      return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    } catch (e) {
      return false; // Web or other
    }
  }
}
