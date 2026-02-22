import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';
import 'package:file_picker/file_picker.dart';
import '../services/voice_service.dart';
import 'voice_recording_modal.dart';
import '../app.dart';

class ChatInput extends StatefulWidget {
  final Function(String, List<Attachment>, bool, bool) onSendMessage;
  final Function(String path, String type)? onFileAttached;
  final bool isLoading;

  const ChatInput({
    super.key,
    required this.onSendMessage,
    this.onFileAttached,
    this.isLoading = false,
  });

  @override
  State<ChatInput> createState() => _ChatInputState();
}

class _ChatInputState extends State<ChatInput> {
  final TextEditingController _controller = TextEditingController();
  final List<Attachment> _attachments = [];
  bool _isSearchMode = false;

  void _handleSend([String? voiceText]) {
    final text = voiceText ?? _controller.text;
    if ((text.trim().isNotEmpty || _attachments.isNotEmpty) && !widget.isLoading) {
      widget.onSendMessage(text, List.from(_attachments), _isSearchMode, voiceText != null);
      _controller.clear();
      setState(() {
        _attachments.clear();
      });
    }
  }

  void _showVoiceModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => VoiceRecordingModal(
        textStream: VoiceService().textStream,
        onStop: () {
          VoiceService().stopListening();
          Navigator.pop(context);
          // Auto-send the last recognized text
          if (_controller.text.isNotEmpty) {
             _handleSend(_controller.text);
          }
        },
        onCancel: () {
          VoiceService().stopListening();
          Navigator.pop(context);
          _controller.clear();
        },
      ),
    );
    
    // Start listening immediately
    VoiceService().startListening(onResult: (text) {
      if (mounted) {
        setState(() {
          _controller.text = text;
        });
      }
    });
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
        allowMultiple: true,
      );

      if (result != null) {
        setState(() {
          for (var file in result.files) {
             if (file.path != null) {
               final isImage = ['jpg', 'jpeg', 'png'].contains(file.extension?.toLowerCase());
               final type = isImage ? 'image' : 'document';
               _attachments.add(Attachment(
                 id: DateTime.now().millisecondsSinceEpoch.toString() + file.name,
                 name: file.name,
                 type: type,
                 url: file.path, 
               ));
               // Fire pre-processing callback immediately on attach
               widget.onFileAttached?.call(file.path!, type);
             }
          }
        });
      }
    } catch (e) {
      print("File picker error: $e");
    }
  }

  void _removeAttachment(String id) {
    setState(() {
      _attachments.removeWhere((a) => a.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF468F82); // Calm Teal
    final bool canSend = (_controller.text.trim().isNotEmpty || _attachments.isNotEmpty) && !widget.isLoading;

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), // More bottom padding for mobile
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.6),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.08))),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_attachments.isNotEmpty) _buildAttachmentList(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildAddButton(),
                  const SizedBox(width: 12),
                  _buildTextField(),
                  const SizedBox(width: 12),
                  _buildSendButton(canSend),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentList() {
    return Container(
      height: 90,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _attachments.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = _attachments[index];
          return Container(
            width: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: Stack(
              children: [
                // Show actual image thumbnail or icon for documents
                if (attachment.type == 'image' && attachment.url != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.file(
                      File(attachment.url!),
                      width: 80,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(Icons.image_rounded, color: Colors.greenAccent, size: 32),
                      ),
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_rounded, 
                          color: Colors.blueAccent,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            attachment.name,
                            style: const TextStyle(color: Colors.white70, fontSize: 10),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                    onTap: () => _removeAttachment(attachment.id),
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: IconButton(
        onPressed: _pickFiles,
        icon: const Icon(Icons.add_circle_outline_rounded, color: Colors.white60, size: 28),
      ),
    );
  }

  Widget _buildTextField() {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TextField(
          controller: _controller,
          maxLines: 5,
          minLines: 1,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
          onChanged: (text) {
            setState(() {}); 
          },
          onSubmitted: (_) => _handleSend(),
          decoration: InputDecoration(
            hintText: "Ask AI...",
            hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 16),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildSendButton(bool canSend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: GestureDetector(
        onTap: canSend ? _handleSend : _showVoiceModal,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: canSend 
              ? const LinearGradient(colors: [Color(0xFF468F82), Color(0xFF2E7063)]) // Teal Gradient
              : null,
            color: canSend ? null : Colors.white.withOpacity(0.1),
          ),
          child: Icon(
            canSend ? Icons.arrow_upward_rounded : Icons.mic_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
