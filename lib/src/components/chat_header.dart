import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class ChatHeader extends StatelessWidget {
  final bool isLoading;
  const ChatHeader({super.key, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            border: Border(
              bottom: BorderSide(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildTitleSection(),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildTitleSection() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock, size: 12, color: isLoading ? Colors.amber : const Color(0xFF10b981)),
            const SizedBox(width: 4),
            Text(
              "Edgemind",
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),

        if (isLoading)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              "INITIALIZING...",
              style: GoogleFonts.inter(
                fontSize: 9, 
                fontWeight: FontWeight.bold, 
                color: Colors.amber,
                letterSpacing: 1.5
              ),
            ),
          ),
      ],
    );
  }


}
