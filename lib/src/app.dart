import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'components/chat_header.dart';
import 'components/chat_input.dart';
import 'components/chat_message.dart';
import 'services/slm_service.dart';
import 'services/search_service.dart';
import 'services/file_processor.dart';
import 'services/database_service.dart';
import 'services/voice_service.dart';
import 'components/pin_screen.dart';
import 'services/logger.dart';
import 'components/aurora_background.dart';
import 'components/settings_modal.dart';
import 'dart:ui'; // For ImageFilter

class Message {
  final String id;
  final String role; // 'user' | 'assistant'
  final String content;
  final List<Attachment>? attachments;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.role,
    required this.content,
    this.attachments,
    required this.timestamp,
  });
}

class Attachment {
  final String id;
  final String name;
  final String type; // 'image' | 'document'
  final String? url;

  Attachment({
    required this.id,
    required this.name,
    required this.type,
    this.url,
  });
}

class ChatApp extends StatefulWidget {
  const ChatApp({super.key});

  @override
  State<ChatApp> createState() => _ChatAppState();
}

class _ChatAppState extends State<ChatApp> {
  bool _isAuthenticated = false;
  bool _isTyping = false;
  bool _isModelLoading = true;
  int _currentNavIndex = 0; // Deprecated but keeping for safe measure or remove
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Settings State
  double _fontSize = 14.0;
  bool _isDarkMode = true; // Controls Aurora visibility

  List<Message> _messages = [];
  List<ChatSession> _sessions = [];
  String? _currentSessionId;

  @override
  void initState() {
    super.initState();
    // NOTE: _initModel() is NOT called here.
    // It is deferred to _onAuthenticated() so that the native LLM library
    // does not initialize while the PIN screen is showing.
    // In release builds, native crashes during model init would kill the
    // entire app, making it look like the PIN screen crashed.
    _loadSessions();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await DatabaseService().getSettings();
    if (mounted) {
      setState(() {
        _fontSize = (settings['fontSize'] as num?)?.toDouble() ?? 14.0;
        _isDarkMode = settings['isDarkMode'] ?? true;
      });
    }
  }

  Future<void> _initModel() async {
    try {
      await SlmService().initialize();
    } catch (e) {
      LogService.error("Model init failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isModelLoading = false;
        });
      }
    }
  }

  Future<void> _loadSessions() async {
    await DatabaseService().init();
    final sessions = await DatabaseService().getSessions();
    setState(() {
      _sessions = sessions;
    });
    
    // Load most recent session if exists, else start new
    if (_currentSessionId == null && sessions.isNotEmpty) {
      _loadSession(sessions.first.id);
    } else if (sessions.isEmpty) {
      _startNewChat();
    }
  }

  Future<void> _loadSession(String sessionId) async {
    final messages = await DatabaseService().loadMessages(sessionId);
    setState(() {
      _currentSessionId = sessionId;
      _messages = messages;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  Future<void> _startNewChat() async {
    LogService.debug("Starting New Chat. Clearing messages.");
    setState(() {
      _currentSessionId = null; 
      _messages = [
        Message(
          id: 'welcome',
          role: 'assistant',
          content: 'Hello! How can I help you today?',
          timestamp: DateTime.now(),
        )
      ];
    });
    LogService.debug("Messages cleared. Count: ${_messages.length}");
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }
  
  Future<void> _deleteSession(String sessionId) async {
    await DatabaseService().deleteSession(sessionId);
    await _loadSessions(); // Reload list
    if (_currentSessionId == sessionId) {
      _startNewChat();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  // Cache for pre-extracted PDF text (key: file path, value: extracted text)
  final Map<String, String> _preExtractedTexts = {};

  /// Called immediately when a file is picked (before user presses Send)
  void _handleFileAttached(String path, String type) {
    if (type == 'image') {
      // Start image pre-processing in native C++ (KV cache warm-up)
      SlmService().prepareImage(path);
    } else if (type == 'document') {
      // Start PDF text extraction in background
      FileProcessor().processFile(path, 'document').then((extractedText) {
        if (extractedText != null && extractedText.isNotEmpty) {
          _preExtractedTexts[path] = extractedText;
        }
      });
    }
  }

  void _handleSendMessage(
      String text, List<Attachment> attachments, bool isSearchMode, bool isVoiceInput) async {
    String effectiveContent = text;
    if (attachments.isNotEmpty) {
      for (var attachment in attachments) {
        if (attachment.url != null && attachment.type == 'document') {
           // Use pre-extracted text if available (from background processing), otherwise extract now
           final extractedText = _preExtractedTexts.remove(attachment.url!) 
               ?? await FileProcessor().processFile(attachment.url!, attachment.type);
           effectiveContent += "\n\n<<<Attachment Content: $extractedText>>>";
        }
      }
    }

    final userMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      role: 'user',
      content: effectiveContent, 
      attachments: attachments.isNotEmpty ? attachments : null,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _isTyping = true;
    });
    
    LogService.debug("Sending Message. Current History Count: ${_messages.length}");
    _scrollToBottom();
    
    // Ensure session exists
    if (_currentSessionId == null) {
      _currentSessionId = await DatabaseService().createSession(
        text.length > 30 ? "${text.substring(0, 30)}..." : text
      );
      _loadSessions(); // Refresh sidebar to show new session
    }
    
    await DatabaseService().saveMessage(_currentSessionId!, userMessage);

    try {
      String responseContent = '';
      if (isSearchMode) {
        responseContent = await SearchService().searchWeb(text);
        if (!mounted) return;
        
        final aiResponse = Message(
          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
          role: 'assistant',
          content: responseContent,
          timestamp: DateTime.now(),
        );

        setState(() {
          _messages.add(aiResponse);
          _isTyping = false;
        });
        _scrollToBottom();
        await DatabaseService().saveMessage(_currentSessionId!, aiResponse);
        
        if (isVoiceInput) {
           await VoiceService().speak(responseContent);
        }

      } else {
        final aiMessageId = (DateTime.now().millisecondsSinceEpoch + 1).toString();
        
        setState(() {
          _messages.add(Message(
            id: aiMessageId,
            role: 'assistant',
            content: '', 
            timestamp: DateTime.now(),
          ));
          _isTyping = false; 
        });

        StringBuffer fullResponseBuffer = StringBuffer();

        await for (final chunk in SlmService().generateResponse(text, _messages)) {
           if (!mounted) return;
           fullResponseBuffer.write(chunk);
           
           setState(() {
             final index = _messages.indexWhere((m) => m.id == aiMessageId);
             if (index != -1) {
               final currentContent = _messages[index].content;
               _messages[index] = Message(
                 id: aiMessageId,
                 role: 'assistant',
                 content: currentContent + chunk,
                 timestamp: _messages[index].timestamp,
               );
             }
           });
           _scrollToBottom();
        }
        
        final finalAiMessage = _messages.firstWhere((m) => m.id == aiMessageId);
        await DatabaseService().saveMessage(_currentSessionId!, finalAiMessage);
        
        if (isVoiceInput) {
           await VoiceService().speak(fullResponseBuffer.toString());
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(Message(
            id: DateTime.now().millisecondsSinceEpoch.toString(),
            role: 'assistant',
            content: "Error: $e",
            timestamp: DateTime.now()));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.black,
      drawer: _isAuthenticated ? _buildDrawer() : null, // Only show drawer if auth
      body: Stack(
        children: [
          // Aurora Background (Replaces Neural Pattern)
          if (_isDarkMode)
            const AuroraBackground(),
          
          /*
          CustomPaint(
            painter: NeuralPatternPainter(),
            size: Size.infinite,
          ),
          */
          
          if (!_isAuthenticated)
             PinScreen(
               onAuthenticated: () {
                 setState(() {
                   _isAuthenticated = true;
                 });
                 // Start model initialization AFTER PIN is accepted
                 _initModel();
               },
             )
          else
            SafeArea(
              child: Column(
                children: [
                  // App Bar with Menu Button (Glassmorphism)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          color: Colors.white.withOpacity(0.05),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                              ),
                              Expanded(child: ChatHeader(isLoading: _isModelLoading)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _buildChatView(),
                  ),
                  // Removed Bottom Nav
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0a0f12),
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white12)),
            ),
            child: Center(
              child: Text("Chat History", style: GoogleFonts.inter(color: Colors.white, fontSize: 20)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add, color: Colors.blueAccent),
            title: Text("New Chat", style: GoogleFonts.inter(color: Colors.blueAccent)),
            onTap: () {
              Navigator.pop(context);
              _startNewChat();
            },
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: ListView.builder(
              itemCount: _sessions.length,
              itemBuilder: (context, index) {
                final session = _sessions[index];
                final isSelected = session.id == _currentSessionId;
                return ListTile(
                  title: Text(
                    session.title, 
                    style: GoogleFonts.inter(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  selected: isSelected,
                  selectedTileColor: Colors.white10,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.white24),
                    onPressed: () => _deleteSession(session.id),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _loadSession(session.id);
                  },
                );
              },
            ),
          ),
          
          // Drawer Bottom: Settings
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white12)),
            ),
            child: ListTile(
              leading: const Icon(Icons.settings_rounded, color: Colors.white),
              title: Text("Settings", style: GoogleFonts.inter(color: Colors.white)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context, 
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => SettingsModal(onThemeChanged: _loadSettings),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatView() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return ChatMessageWidget(
                message: message,
                fontSize: _fontSize, // Pass font size setting
              );
            },
          ),
        ),
        // Active Voice Indicator
        if (_isTyping)
          Container(
            height: 40,
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF468F82).withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...List.generate(9, (index) => Container(
                  width: 3,
                  height: 10 + (index % 3 * 5).toDouble(),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF468F82),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true)).scaleY(
                  begin: 0.5,
                  end: 1.5,
                  duration: 400.ms,
                  delay: (index * 100).ms,
                )),
                const SizedBox(width: 12),
                const Text(
                  "PROCESSING...",
                  style: TextStyle(
                    color: Color(0xFF468F82),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

        ChatInput(
          onSendMessage: _handleSendMessage,
          onFileAttached: _handleFileAttached,
          isLoading: _isTyping || _isModelLoading,
        ),
      ],
    );
  }

  // Removed _buildBottomNav and _buildNavItem as they are no longer used


}

class NeuralPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF468F82).withOpacity(0.05)
      ..strokeWidth = 1.0;

    const spacing = 40.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
    
    // Draw some random connections
    final linePaint = Paint()
      ..color = const Color(0xFF468F82).withValues(alpha: 0.02)
      ..strokeWidth = 0.5;
      
    canvas.drawLine(const Offset(40, 40), const Offset(120, 80), linePaint);
    canvas.drawLine(const Offset(120, 80), const Offset(200, 40), linePaint);
    canvas.drawLine(const Offset(40, 160), const Offset(80, 240), linePaint);
    canvas.drawLine(const Offset(240, 320), const Offset(320, 400), linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0, left: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(150),
                const SizedBox(width: 4),
                _buildDot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int delay) {
    return Container(
      width: 4,
      height: 4,
      decoration: const BoxDecoration(
        color: Colors.white24,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat())
        .moveY(
          begin: 0,
          end: -4,
          duration: 400.ms,
          curve: Curves.easeInOut,
          delay: Duration(milliseconds: delay),
        )
        .then()
        .moveY(
          begin: -4,
          end: 0,
          duration: 400.ms,
          curve: Curves.easeInOut,
        );
  }
}
