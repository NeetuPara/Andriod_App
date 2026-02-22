import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../app.dart';

class ChatSession {
  final String id;
  final String title;
  final DateTime createdAt;

  ChatSession({required this.id, required this.title, required this.createdAt});

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
    id: json['id'],
    title: json['title'],
    createdAt: DateTime.parse(json['createdAt']),
  );
}

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  static const String _sessionsKey = 'chat_sessions_v1';
  static const String _sessionPrefix = 'session_';
  static const String _settingsKey = 'app_settings_v1';

  Future<void> init() async {}

  Future<List<ChatSession>> getSessions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> sessionsJson = prefs.getStringList(_sessionsKey) ?? [];
    return sessionsJson
        .map((str) => ChatSession.fromJson(jsonDecode(str)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt)); // Newest first
  }

  Future<String> createSession(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    
    final newSession = ChatSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      createdAt: DateTime.now(),
    );

    sessions.insert(0, newSession);
    
    await prefs.setStringList(
      _sessionsKey, 
      sessions.map((s) => jsonEncode(s.toJson())).toList()
    );

    return newSession.id;
  }

  Future<void> saveMessage(String sessionId, Message message) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_sessionPrefix$sessionId';
    final List<String> currentHistory = prefs.getStringList(key) ?? [];
    
    final Map<String, dynamic> json = {
      'id': message.id,
      'role': message.role,
      'content': message.content,
      'timestamp': message.timestamp.toIso8601String(),
      'attachments': message.attachments?.map((a) => {
        'id': a.id,
        'name': a.name,
        'type': a.type,
        'url': a.url,
      }).toList(),
    };
    
    currentHistory.add(jsonEncode(json));
    await prefs.setStringList(key, currentHistory);
    
    // Update session title if it's the first user message (optional, but good UX)
    if (message.role == 'user' && currentHistory.length == 1) {
       await _updateSessionTitle(sessionId, message.content);
    }
  }
  
  Future<void> _updateSessionTitle(String sessionId, String firstMessage) async {
    final prefs = await SharedPreferences.getInstance();
    final sessions = await getSessions();
    final index = sessions.indexWhere((s) => s.id == sessionId);
    
    if (index != -1) {
      String newTitle = firstMessage.length > 30 
          ? "${firstMessage.substring(0, 30)}..." 
          : firstMessage;
      
      final updatedSession = ChatSession(
        id: sessions[index].id, 
        title: newTitle, 
        createdAt: sessions[index].createdAt
      );
      
      sessions[index] = updatedSession;
      await prefs.setStringList(
        _sessionsKey, 
        sessions.map((s) => jsonEncode(s.toJson())).toList()
      );
    }
  }

  Future<List<Message>> loadMessages(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_sessionPrefix$sessionId';
    final List<String> historyJson = prefs.getStringList(key) ?? [];
    
    return historyJson.map((jsonStr) {
      final json = jsonDecode(jsonStr);
      return Message(
        id: json['id'],
        role: json['role'],
        content: json['content'],
        timestamp: DateTime.parse(json['timestamp']),
        attachments: (json['attachments'] as List?)?.map((a) => Attachment(
          id: a['id'],
          name: a['name'],
          type: a['type'],
          url: a['url'],
        )).toList(),
      );
    }).toList();
  }
  
  Future<void> deleteSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    
    // Remove from sessions list
    final sessions = await getSessions();
    sessions.removeWhere((s) => s.id == sessionId);
    await prefs.setStringList(
      _sessionsKey, 
      sessions.map((s) => jsonEncode(s.toJson())).toList()
    );

    // Remove actual messages
    await prefs.remove('$_sessionPrefix$sessionId');
  }

  // Deprecated: creates a default session if needed for legacy compatibility
  Future<void> ensureDefaultSession() async {
     // Implementation if needed
  }

  // --- Settings ---
  
  Future<Map<String, dynamic>> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final String? settingsJson = prefs.getString(_settingsKey);
    if (settingsJson != null) {
      return jsonDecode(settingsJson);
    }
    // Defaults
    return {
      'systemPrompt': 'You are a helpful AI assistant. Provide direct and concise answers.',
      'temperature': 0.7,
      'isDarkMode': true, // Default to dark (Aurora)
      'fontSize': 14.0,
      'autoRead': false,
    };
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, jsonEncode(settings));
  }
  
  Future<void> clearAllData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Nuke everything
  }
}
