import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;

import '../app.dart';
import 'logger.dart';
import 'database_service.dart';

class SlmService {
  static final SlmService _instance = SlmService._internal();

  factory SlmService() {
    return _instance;
  }

  static const MethodChannel _vlmChannel = MethodChannel('com.example.flutter_app/vlm');
  StreamController<String>? _mobileStreamController;

  SlmService._internal() {
    _vlmChannel.setMethodCallHandler((call) async {
      if (call.method == 'onToken') {
        final token = call.arguments as String;
        if (token == '[DONE]') {
          _mobileStreamController?.close();
        } else {
          _mobileStreamController?.add(token);
        }
      }
    });
  }

  Process? _serverProcess;
  bool _isServerReady = false;
  
  // Model Assets
  final String _modelAssetName = 'assets/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf';
  final String _mmprojAssetName = 'assets/mmproj-Qwen2.5-VL-3B-Instruct-f16.gguf';
  int _port = 8081; 

  Future<void> initialize() async {
    if (_isServerReady) return;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final directory = Directory('${docDir.path}/flutter_app_chat_data');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      final modelFile = File('${directory.path}/qwen_model_v1.gguf');
      final mmprojFile = File('${directory.path}/qwen_mmproj_v1.gguf');

      Future<void> ensureAssetCopied(File file, String assetName) async {
         if (!await file.exists() || (await file.stat()).size == 0) {
            LogService.info("Model file not found. Copying $assetName from assets to ${file.path}...");
            try {
              if (Platform.isAndroid) {
                const channel = MethodChannel('com.example.flutter_app/asset_copy');
                await channel.invokeMethod('copyAsset', {
                  'assetName': 'flutter_assets/$assetName',
                  'destPath': file.path,
                });
              } else {
                final data = await rootBundle.load(assetName);
                await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
              }
            } catch (e, stack) {
              LogService.error("Failed to copy asset.", error: e, stackTrace: stack);
              if (await file.exists()) await file.delete();
              throw Exception("Asset Copy Failed: $e");
            }
         }
      }

      await ensureAssetCopied(modelFile, _modelAssetName);
      await ensureAssetCopied(mmprojFile, _mmprojAssetName);

      if (Platform.isAndroid || Platform.isIOS) {
        LogService.info("========== MOBILE LLM INIT START ==========");
        try {
          await _vlmChannel.invokeMethod('initVLM', {
             'modelPath': modelFile.path,
             'mmprojPath': mmprojFile.path,
          });
          _isServerReady = true;
          LogService.info("========== MOBILE LLM INIT COMPLETE ==========");
        } catch (e, stack) {
          LogService.error("CRITICAL: Failed to initialize Mobile LLM natively.", error: e, stackTrace: stack);
          rethrow;
        }
        return;
      }

      // WINDOWS / DESKTOP LOGIC (Existing)
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final serverPath = '$exeDir\\llama-server.exe';
      
      LogService.info('Starting local AI server: $serverPath');
      
      if (!File(serverPath).existsSync()) {
        throw Exception("llama-server.exe not found at $serverPath. Please ensure it is copied to the build directory.");
      }

      String? mmprojPath;
      final dirFiles = directory.listSync();
      for (var file in dirFiles) {
        if (file.path.contains("mmproj") && file.path.endsWith(".gguf")) {
          mmprojPath = file.path;
          break;
        }
      }

      final args = [
        '-m', modelFile.path,
        '--port', '$_port',
        '-c', '8192', 
        '-ngl', '999', 
        '--parallel', '1',
      ];

      if (mmprojPath != null) {
        args.addAll(['--mmproj', mmprojPath]);
      }

      _serverProcess = await Process.start(serverPath, args, mode: ProcessStartMode.detachedWithStdio); 
      
      _serverProcess!.stdout.transform(utf8.decoder).listen((data) {
        LogService.debug('[LlamaServer] $data');
      });
      _serverProcess!.stderr.transform(utf8.decoder).listen((data) {
        LogService.error('[LlamaServer ERR] $data');
      });

      await _waitForServer();
      
      _isServerReady = true;
      LogService.info('Local AI server is ready at http://127.0.0.1:$_port');
      
    } catch (e) {
      LogService.error("Error initialization SLM server: $e");
      _killServer();
      rethrow;
    }
  }

  Future<void> _waitForServer() async {
    int retries = 0;
    while (retries < 20) {
      try {
        final response = await http.get(Uri.parse('http://127.0.0.1:$_port/health'));
        if (response.statusCode == 200) {
          return;
        }
      } catch (e) {}
      await Future.delayed(Duration(seconds: 1));
      retries++;
    }
    throw Exception("Failed to connect to local AI server after 20 seconds");
  }

  /// Pre-process image immediately on upload (KV cache warm-up on mobile)
  Future<void> prepareImage(String imagePath) async {
    if (!_isServerReady) return;
    
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        // Resize image to 512x512 and save to temp file for native processing
        final resizedPath = await _resizeImageToTemp(imagePath);
        await _vlmChannel.invokeMethod('prepareImageVLM', {
          'imagePath': resizedPath,
        });
        LogService.info("Image pre-processed for KV cache: $resizedPath");
      } catch (e) {
        LogService.error("prepareImage failed: $e");
      }
    }
    // Desktop: no-op, uses HTTP server
  }

  /// Resize image to 512×512 bounding box and save to a temp file
  Future<String> _resizeImageToTemp(String originalPath) async {
    final file = File(originalPath);
    final rawBytes = await file.readAsBytes();
    
    img.Image? decoded = img.decodeImage(rawBytes);
    if (decoded == null) return originalPath; // fallback to original
    
    final resized = img.copyResize(decoded, width: 512, height: 512, maintainAspect: true);
    
    final lowerPath = originalPath.toLowerCase();
    List<int> encodedBytes;
    String ext;
    if (lowerPath.endsWith('.png')) {
      encodedBytes = img.encodePng(resized);
      ext = '.png';
    } else {
      encodedBytes = img.encodeJpg(resized, quality: 85);
      ext = '.jpg';
    }
    
    final tempDir = await getApplicationDocumentsDirectory();
    final tempFile = File('${tempDir.path}/vlm_resized$ext');
    await tempFile.writeAsBytes(encodedBytes, flush: true);
    return tempFile.path;
  }

  Stream<String> generateResponse(String prompt, List<Message> history) async* {
    if (!_isServerReady) {
      await initialize();
    }
    
    final settings = await DatabaseService().getSettings();
    final String userSystemPrompt = settings['systemPrompt'] ?? "You are a helpful AI assistant.";
    final double userTemperature = (settings['temperature'] as num?)?.toDouble() ?? 0.7;

    // --- MOBILE PATH ---
    if (Platform.isAndroid || Platform.isIOS) {
      if (!_isServerReady) {
        yield "Error: Mobile AI engine failed to initialize.";
        return;
      }
      
      _mobileStreamController = StreamController<String>();

      // Find the last user message with image attachments (skip empty assistant placeholders)
      String? imagePath;
      String finalPrompt = prompt;
      
      for (int i = history.length - 1; i >= 0; i--) {
        final msg = history[i];
        if (msg.role == 'user' && msg.attachments != null) {
          for (var a in msg.attachments!) {
            if (a.type == 'image' && a.url != null) {
              imagePath = a.url;
              finalPrompt = msg.content.isEmpty ? "Describe the image" : msg.content;
              break;
            }
          }
          if (imagePath != null) break;
        }
      }

      // If image was found, use the resized temp file path
      String resolvedImagePath = '';
      if (imagePath != null) {
        resolvedImagePath = await _resizeImageToTemp(imagePath);
      }

      try {
        _vlmChannel.invokeMethod('runVLM', {
          'prompt': finalPrompt,
          'imagePath': resolvedImagePath,
        }).catchError((e) {
            _mobileStreamController?.addError(e);
            _mobileStreamController?.close();
        });

        await for (final token in _mobileStreamController!.stream) {
          yield token;
        }
      } catch (e) {
        yield "\n[Mobile Inference Error: $e]";
      }
      return;
    }

    // --- DESKTOP PATH (Existing) ---
    if (_serverProcess == null) {
      yield "Error: Local AI engine process is not running.";
      return;
    }

    List<Map<String, dynamic>> messages = [];
    messages.add({
      "role": "system",
      "content": "$userSystemPrompt The user may provide text from documents or images. "
                 "When text is provided in <<<Attachment Content>>>, read it carefully and answer questions based on it."
    });
    
    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;
    
    // Pre-scan: find the index of the LAST message that actually has image attachments.
    // We cannot use `isLastMessage` because app.dart adds an empty assistant placeholder 
    // message to `_messages` BEFORE calling generateResponse(), so the true "last" element 
    // is always an empty assistant message, not the user's image message.
    int lastImageMsgIndex = -1;
    for (int i = recentHistory.length - 1; i >= 0; i--) {
      if (recentHistory[i].attachments?.any((a) => a.type == 'image') ?? false) {
        lastImageMsgIndex = i;
        break;
      }
    }
    
    for (int i = 0; i < recentHistory.length; i++) {
         final msg = recentHistory[i];
         final hasImages = msg.attachments?.any((a) => a.type == 'image') ?? false;
         
         // Skip empty placeholder messages (e.g., the empty assistant message added by app.dart)
         if (msg.content.isEmpty && !hasImages) continue;

         // Only encode massive Base64 images for the MOST RECENT image message
         // Otherwise the HTTP payload size and context window will overflow and cause a 400 error
         if (hasImages && i == lastImageMsgIndex) {
           List<Map<String, dynamic>> contentParts = [];
           
           // 1. Vision models require images first
           for (var attachment in msg.attachments ?? []) {
             if (attachment.type == 'image' && attachment.url != null) {
                final file = File(attachment.url!);
                if (await file.exists()) {
                  final rawBytes = await file.readAsBytes();
                  
                  // Image Resizing Logic
                  // We resize to a max bounding box of 512x512 to significantly reduce 
                  // Base64 payload bloat and improve inference speed on the background server
                  img.Image? decodedImage = img.decodeImage(rawBytes);
                  List<int> processedBytes = rawBytes; // fallback to raw
                  
                  if (decodedImage != null) {
                    final resizedImage = img.copyResize(
                      decodedImage, 
                      width: 512, 
                      height: 512, 
                      maintainAspect: true,
                    );
                    
                    final lowerPath = file.path.toLowerCase();
                    if (lowerPath.endsWith('.png')) {
                      processedBytes = img.encodePng(resizedImage);
                    } else if (lowerPath.endsWith('.webp')) {
                       processedBytes = img.encodeJpg(resizedImage, quality: 85);
                    } else {
                      processedBytes = img.encodeJpg(resizedImage, quality: 85);
                    }
                  }

                  final base64Image = base64Encode(processedBytes);
                  
                  String mimeType = 'image/jpeg';
                  final lowerPath = file.path.toLowerCase();
                  if (lowerPath.endsWith('.png')) mimeType = 'image/png';
                  else if (lowerPath.endsWith('.gif')) mimeType = 'image/gif';
                  
                  contentParts.add({
                    "type": "image_url",
                    "image_url": {
                      "url": "data:$mimeType;base64,$base64Image"
                    }
                  });
                }
             }
           }
           
           // 2. Append the text components (including injected PDF text)
           contentParts.add({
             "type": "text", 
             "text": msg.content.isEmpty ? "Describe the image" : msg.content
           });
           
           messages.add({
             "role": msg.role,
             "content": contentParts
           });
           
         } else {
           messages.add({
             "role": msg.role,
             // If they uploaded an image in the past with no text, provide a placeholder so it doesn't 400
             "content": msg.content.isEmpty && hasImages ? "[Image attached previously]" : msg.content,
           });
         }
    }

    try {
      final request = http.Request('POST', Uri.parse('http://127.0.0.1:$_port/v1/chat/completions'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer no-key'; 
      
      request.body = jsonEncode({
        "messages": messages,
        "model": "qwen", 
        "stream": true,
        "max_tokens": 1024,
        "temperature": userTemperature,
      });

      final response = await http.Client().send(request);

      if (response.statusCode != 200) {
        yield "Error: Server responded with status ${response.statusCode}";
        return;
      }

      await for (final chunk in response.stream.transform(utf8.decoder)) {
         final lines = chunk.split('\n');
         for (final line in lines) {
           if (line.startsWith('data: ')) {
             final dataStr = line.substring(6).trim();
             if (dataStr.isEmpty || dataStr == '[DONE]') continue;
             
             try {
               final json = jsonDecode(dataStr);
               if (json['choices'] != null && json['choices'].isNotEmpty) {
                 final delta = json['choices'][0]['delta'];
                 if (delta != null && delta['content'] != null) {
                   yield delta['content'];
                 }
               }
             } catch (e) {}
           }
         }
      }

    } catch (e) {
      yield "\n[Inference Error: $e]";
    }
  }

  void _killServer() {
     _serverProcess?.kill();
     _serverProcess = null;
     _isServerReady = false;
  }

  void dispose() {
    _mobileStreamController?.close();
    _killServer();
  }
}
