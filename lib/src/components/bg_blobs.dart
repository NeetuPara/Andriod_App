import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_animate/flutter_animate.dart';

class BackgroundBlobs extends StatelessWidget {
  const BackgroundBlobs({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: -MediaQuery.of(context).size.height * 0.1,
          left: -MediaQuery.of(context).size.width * 0.1,
          child: _buildBlob(
            context,
            color: const Color(0xFF06b6d4).withValues(alpha: 0.3),
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.5,
            blur: 100,
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.2,
          right: -MediaQuery.of(context).size.width * 0.2,
          child: _buildBlob(
            context,
            color: const Color(0xFFbef264).withValues(alpha: 0.3),
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.6,
            blur: 120,
            delay: 1500,
          ),
        ),
        Positioned(
          bottom: -MediaQuery.of(context).size.height * 0.2,
          left: -MediaQuery.of(context).size.width * 0.1,
          child: _buildBlob(
            context,
            color: const Color(0xFF8b5cf6).withValues(alpha: 0.2),
            width: MediaQuery.of(context).size.width * 1.0,
            height: MediaQuery.of(context).size.height * 0.7,
            blur: 140,
            delay: 3000,
          ),
        ),
        Positioned(
          top: MediaQuery.of(context).size.height * 0.4,
          left: MediaQuery.of(context).size.width * 0.2,
          child: _buildBlob(
            context,
            color: const Color(0xFFfbbf24).withValues(alpha: 0.2),
            width: MediaQuery.of(context).size.width * 0.4,
            height: MediaQuery.of(context).size.height * 0.3,
            blur: 80,
            delay: 4000,
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
            child: Container(
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBlob(BuildContext context,
      {required Color color,
      required double width,
      required double height,
      required double blur,
      int delay = 0}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1000),
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(reverse: true),
        )
        .blur(
            begin: Offset(blur, blur),
            end: Offset(blur * 1.2, blur * 1.2),
            duration: 4.seconds,
            curve: Curves.easeInOut)
        .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.1, 1.1),
            duration: 4.seconds,
            curve: Curves.easeInOut,
            delay: Duration(milliseconds: delay));
  }
}
