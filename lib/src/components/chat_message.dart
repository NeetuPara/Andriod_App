import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../app.dart';

class ChatMessageWidget extends StatelessWidget {
  final Message message;
  final double fontSize;

  const ChatMessageWidget({super.key, required this.message, this.fontSize = 14.0});

  @override
  Widget build(BuildContext context) {
    final isAssistant = message.role == 'assistant';
    final displayContent = _cleanContent(message.content);

    // If cleaned content is empty (e.g. only attachment), we might still want to show something or just the attachment
    // But usually there is a prompt.
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0), // Increased spacing
      child: Column(
        crossAxisAlignment: isAssistant ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          if (message.attachments != null && message.attachments!.isNotEmpty) 
            Padding(
              padding: EdgeInsets.only(
                bottom: 8.0, 
                left: isAssistant ? 48.0 : 0,
                right: isAssistant ? 0 : 44.0,
              ),
              child: _buildAttachments(),
            ),
          Row(
            mainAxisAlignment: isAssistant ? MainAxisAlignment.start : MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isAssistant) _buildAssistantAvatar(),
              const SizedBox(width: 12),
              Flexible(
                child: _buildMessageBubble(isAssistant),
              ),
              if (!isAssistant) const SizedBox(width: 44), // Alignment spacer for user messages
            ],
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).moveY(begin: 10, end: 0, curve: Curves.easeOut),
    );
  }

  Widget _buildAssistantAvatar() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        // Gradient Avatar (Teal/Sage)
        gradient: LinearGradient(
          colors: [Color(0xFF468F82), Color(0xFFBAC7B2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x40468F82), // Soft Teal Shadow
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
    );
  }

  Widget _buildMessageBubble(bool isAssistant) {
    final cleanText = _cleanContent(message.content);
    if (cleanText.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        // Gradient for assistant, solid (glassy) for user
        gradient: isAssistant 
            ? LinearGradient(
                colors: [
                  const Color(0xFF153664).withOpacity(0.9), // Deep Ocean for Assistant
                  const Color(0xFF0A1825).withOpacity(0.95)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF468F82), Color(0xFF2E7063)], // Calm Teal for User
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(24),
          topRight: const Radius.circular(24),
          bottomLeft: isAssistant ? const Radius.circular(4) : const Radius.circular(24),
          bottomRight: isAssistant ? const Radius.circular(24) : const Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
        border: isAssistant ? Border.all(color: Colors.white.withOpacity(0.08)) : null,
      ),
      child: SelectionArea(
        child: Text(
          cleanText,
          style: GoogleFonts.inter(
            fontSize: fontSize,
            color: Colors.white.withOpacity(0.95),
            height: 1.5, // Improved readability
            fontWeight: isAssistant ? FontWeight.w400 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildAttachments() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: message.attachments!.map((a) => _buildAttachmentItem(a)).toList(),
    );
  }

  Widget _buildAttachmentItem(Attachment a) {
    // Show actual image thumbnail for image attachments
    if (a.type == 'image' && a.url != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(a.url!),
          width: 200,
          height: 150,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildFallbackAttachment(a),
        ),
      );
    }

    // Document/PDF: icon + filename
    return _buildFallbackAttachment(a);
  }

  Widget _buildFallbackAttachment(Attachment a) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1c1c1e).withOpacity(0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              a.type == 'image' ? Icons.image_rounded : Icons.description_rounded,
              color: Colors.white70,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              a.name,
              style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withOpacity(0.8)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

  }

  String _cleanContent(String content) {
    // Regex to remove <<<Attachment Content: ...>>> blocks including newlines
    final RegExp regex = RegExp(r'<<<Attachment Content: .*?>>>', dotAll: true);
    return content.replaceAll(regex, '').trim();
  }
}
