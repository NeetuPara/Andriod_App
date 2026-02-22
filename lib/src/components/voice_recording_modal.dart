import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';

class VoiceRecordingModal extends StatefulWidget {
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final Stream<String> textStream;

  const VoiceRecordingModal({
    super.key,
    required this.onStop,
    required this.onCancel,
    required this.textStream,
  });

  @override
  State<VoiceRecordingModal> createState() => _VoiceRecordingModalState();
}

class _VoiceRecordingModalState extends State<VoiceRecordingModal> {
  String _currentText = "";

  @override
  void initState() {
    super.initState();
    widget.textStream.listen((text) {
      if (mounted) {
        setState(() {
          _currentText = text;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isSimulation = Platform.isWindows || Platform.isLinux || Platform.isMacOS;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          
          if (isSimulation)
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                   const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 16),
                   const SizedBox(width: 8),
                   Text(
                     "WINDOWS SIMULATION MODE (Mobile Only Feature)", 
                     style: GoogleFonts.inter(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)
                   ),
                ],
              ),
            ),

          // Pulsing Animation Container
          SizedBox(
            height: 120,
            width: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer Rings (Pulsing)
                for (int i = 0; i < 3; i++)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blueAccent.withValues(alpha: 0.3 - (i * 0.1)),
                        width: 2,
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.2, 1.2),
                    duration: Duration(milliseconds: 1500 + (i * 300)),
                    curve: Curves.easeInOut,
                  ),
                  
                // Inner Circle (Core)
                Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mic, color: Colors.black, size: 32),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2.seconds, color: Colors.blueAccent),
              ],
            ),
          ),
          
          const SizedBox(height: 32),
          
          // Transcription Text
          Text(
            _currentText.isEmpty ? "Listening..." : _currentText,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 48),
          
          // Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close, color: Colors.white54, size: 32),
                tooltip: "Cancel",
              ),
              GestureDetector(
                onTap: widget.onStop,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.stop, color: Colors.black, size: 32),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
