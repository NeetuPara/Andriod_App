import 'dart:async';
import 'dart:io';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();

  factory VoiceService() {
    return _instance;
  }

  VoiceService._internal();

  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();
  
  bool _isListening = false;
  bool _isSpeechAvailable = false;
  bool get isListening => _isListening;
  
  // Stream controller for real-time text updates
  final StreamController<String> _textController = StreamController<String>.broadcast();
  Stream<String> get textStream => _textController.stream;

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      print("VoiceService: Native STT not supported on Desktop. Skipping init.");
      return; 
    }
    
    try {
      _isSpeechAvailable = await _speech.initialize(
        onError: (val) => print('STT Error: $val'),
        onStatus: (val) => print('STT Status: $val'),
      );
      
      await _tts.setLanguage("en-US");
      await _tts.setPitch(1.0);
      print("Voice Service Initialized");
    } catch (e) {
      print("Voice Service Init Error: $e");
    }
  }

  Future<void> startListening({required Function(String) onResult}) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
       // Mock behavior for desktop testing
       _isListening = true;
       _simulateDictation(onResult);
       return;
    }

    if (!_isSpeechAvailable) {
      print("Speech recognition not available");
      await init(); // Try re-init
      if (!_isSpeechAvailable) return;
    }

    _isListening = true;
    _speech.listen(
      onResult: (val) {
        onResult(val.recognizedWords);
        _textController.add(val.recognizedWords);
      },
      listenFor: const Duration(seconds: 30),
      cancelOnError: true,
      partialResults: true,
    );
  }
  
  void _simulateDictation(Function(String) onResult) async {
    final phrases = [
      "Simulation Mode...",
      "Voice recording...",
      "is only available...",
      "on Android and iOS devices.",
      "On Windows, we use...",
      "this simulated text to prevent crashing."
    ];
    
    String currentText = "";
    for (var phrase in phrases) {
      if (!_isListening) break;
      await Future.delayed(const Duration(milliseconds: 800));
      if (!_isListening) break;
      
      currentText = currentText.isEmpty ? phrase : "$currentText $phrase";
      onResult(currentText);
      _textController.add(currentText);
    }
  }

  Future<void> stopListening() async {
    _isListening = false;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    await _speech.stop();
  }

  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      print("TTS (Desktop Mock): $text");
      return;
    }
    
    try {
      await _tts.speak(text);
    } catch (e) {
      print("TTS Error: $e");
    }
  }

  Future<void> stopSpeaking() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) return;
    await _tts.stop();
  }
}
