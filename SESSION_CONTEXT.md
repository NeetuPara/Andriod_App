# Session Context & Status

**Last Updated:** February 22, 2026

## 📌 Project Status
**Goal:** Run offline LLM (Qwen 2.5-VL-3B Multimodal) on Android and Windows using Flutter.
**Current State:** ✅ Windows Logic Ready | ✅ Custom Native Android C++ Bridge Complete | ✅ Multimodal Support Enabled

---

## 🔄 The Journey: Text-only to Native Vision

### Stage 1: The Debug vs. Release Crash
Initially, we used `llama_flutter_android` to load a text-only model.
- **The Bug:** The app worked perfectly in Debug mode via USB, but crashed instantly in Release mode (APK) when loading the 1GB model file into Dart memory.  
- **Debug vs Release:** Dart Debug mode uses JIT (Just-In-Time) compilation with a large heap. Release mode uses AOT (Ahead-Of-Time) compilation which is heavily optimized with strict memory limits. 
- **The Fix:** We couldn't load 1GB into Dart. We wrote a Native Kotlin `MethodChannel` (`com.example.flutter_app/asset_copy`) to stream the asset using a tiny 8KB buffer directly to the device storage.

### Stage 2: The Failure of Flutter Vision Packages
We needed to upgrade from text-only models to Vision models (like Qwen2.5-VL) which require a secondary image projector file (`mmproj`).
- **The Problem:** The `llama_flutter_android` package does not support `mmproj`. We tried switching to `fllama` because documentation implied it did. 
- **The Reality:** The `fllama` API for multimodal support was hallucinated/non-existent. There are **zero** packages on `pub.dev` that cleanly support offline Vision/Multimodal inference for Android.

### Stage 3: The Custom Native C++ Integration (Current)
To solve the lack of Flutter packages, we abandoned them entirely for Android inference.
- **The Solution:** We ported a custom-built Native Android C++ engine (`lib-vlm.cpp`) directly into the Flutter app's `android/app/src/main/cpp` folder.
- **How it Works:** 
  1. We ship both the text model and `mmproj` vision adapter inside the APK.
  2. Flutter copies them to storage using the buffered MethodChannel.
  3. Flutter calls `initVLM` and `runVLM` over a new channel (`com.example.flutter_app/vlm`).
  4. Kotlin JNI bridges to C++ where `llama.cpp` and `mtmd` evaluate the image (`mtmd_bitmap`) natively.
  5. C++ streams the generated text tokens back to Kotlin, which pipes them back to Dart (`onTokenGenerated`).
- **Why it's Better:** It gives us 100% control over the C++ memory layout, completely avoiding Dart's RAM limitations and enabling full offline Vision support gracefully.

---

## 🏗️ Architecture Flow

1. **User attaches image + prompt** -> Flutter Dart UI (`slm_service.dart`)
2. **Channel Invoke** -> Kotlin (`MainActivity.kt` -> `runVLM`)
3. **JNI Bridge** -> Native C++ (`lib-vlm.cpp` -> `mtmd_helper_eval_chunks`)
4. **Token Generation** -> C++ `llama_decode` loop
5. **Streaming Response** -> `onTokenGenerated` back through Kotlin to Flutter UI.

## 🚀 Building Release APK
We rely on a custom CMake compilation step tied to gradle:
```bash
flutter clean
flutter pub get
flutter build apk --release --target-platform android-arm64
```

---

## 💻 Windows Desktop VLM Setup (Rapid Prototyping)
flutter create --platforms=windows . 
To accelerate testing without slow Android builds, we fully implemented local Vision inference on Windows via `llama-server.exe`.

### How It Works:
1. `slm_service.dart` copies the text model and `mmproj` (Vision projector) to the local Documents folder.
2. It launches an external background `Process` running `llama-server.exe` with `-ngl 999` to tightly bind to the **Vulkan GPU** API.
3. The Dart app securely encodes images to Base64 and formats an OpenAI-compatible JSON payload to HTTP POST to the local server.

### Critical Fixes Mapped During Setup:
1. **JSON Payload Ordering:** The Flutter Dart code was sending the `text` question before the `image_url` data in the JSON payload. Vision models (Qwen2.5-VL) rigidly require image tokens to be processed *before* text tokens, otherwise it hallucinates completely.
2. **Missing DLLs:** The pre-compiled Vulkan Windows `llama-server.exe` immediately crashes silently if it is missing its massive suite of companion dynamic linked libraries (`ggml.dll`, `ggml-vulkan.dll`, `libomp...dll`). These must be placed directly inside the `build\windows\x64\runner\Debug` directory. Fixed by modifying `windows/runner/CMakeLists.txt` with a `POST_BUILD` `copy_directory` command that guarantees the entire `llama-win` dependency tree survives a `flutter clean`.
3. **NuGet / CMake Bug:** The flutter_tts module requires `nuget.exe` to be installed and added to the Windows `PATH`. Furthermore, a bug in Flutter's Windows CMake cache required a full `flutter clean` when resolving the `app.dill` kernel file.
4. **Empty Assistant Placeholder Bug:** `app.dart` adds an empty assistant placeholder message to `_messages` *before* calling `generateResponse()` to create the streaming chat bubble. This means `recentHistory.last` is always the empty placeholder, NOT the user's image message. Fixed by pre-scanning backwards through history to find the last message that actually contains image attachments (`lastImageMsgIndex`).
5. **History Bloat / Context Overflow:** When a user uploads a second image, the app was re-encoding ALL previous images in the chat history into the same JSON payload, causing the context window to overflow (400 error). Fixed by only encoding the most recent image message in Base64 and replacing older images with `[Image attached previously]` text placeholders.
6. **Image Resizing (512×512):** High-resolution phone photos (4000×3000) generated 8MB+ Base64 payloads. Added the `image` dart package to resize images to a 512×512 bounding box (preserving aspect ratio) before encoding, reducing payloads to ~50KB.
7. **MIME Type Detection:** The Base64 URL prefix was hardcoded to `image/jpeg`. When uploading `.png` files, the server rejected the mismatched encoding. Fixed by dynamically detecting the file extension and applying the correct MIME type (`image/png`, `image/gif`, etc.).

### 🛠️ Windows Desktop Setup Commands (Step-by-Step)
```bash
# 0. Enable Windows Developer Mode (required for Flutter Desktop)
#    Settings → Privacy & Security → For Developers → Developer Mode → ON

# 1. Enable Windows platform support in Flutter
flutter create --platforms=windows .

# 2. Install dependencies (including image resize package)
flutter pub get
flutter pub add image

# 3. Build and run the Windows app
flutter run -d windows

# 4. Download llama-server.exe (Vulkan Windows release) from:
#    https://github.com/ggerganov/llama.cpp/releases
#    Look for: llama-<version>-bin-win-vulkan-x64.zip

# 5. Extract and copy ALL files (exe + dlls) to:
#    build\windows\x64\runner\Debug\

# 6. Place your GGUF model files in:
#    C:\Users\<username>\Documents\flutter_app_chat_data\
#    Files needed:
#      - qwen_model_v1.gguf  (the main text model)
#      - qwen_mmproj_v1.gguf (the vision projector)

# 7. Re-run the app (server auto-launches in background)
flutter run -d windows
```

### 📦 Key Dependencies (pubspec.yaml)
```yaml
image: ^4.8.0              # Image resizing before Base64 encoding
syncfusion_flutter_pdf: ^24.1.41  # PDF text extraction
http: ^1.6.0               # HTTP client for llama-server API
path_provider: ^2.1.1      # Access to Documents directory
```

---

## 📄 PDF Support & Context Window

### What Works:
- **Text-based PDFs** (blood reports, lab results, typed doctor notes, Word-exported PDFs) → Text is fully extracted and sent to the model as context.
- User can ask follow-up questions about the extracted text ("What is my CBC count?").

### What Does NOT Work:
- **Scanned image PDFs** (photographed documents, X-ray scans embedded as images inside the PDF) → The text extractor returns empty because there is no text layer, only embedded images.
- **Workaround:** Screenshot the specific image from the PDF and upload it separately as a `.jpg`/`.png` file to the image Vision pipeline.

### Context Window Settings:
| Parameter | Initial Value | Current Value | Max Supported (Qwen2.5-VL-3B) |
|-----------|--------------|---------------|-------------------------------|
| `-c` (context tokens) | `8192` | `8192` | `32768` (32K) |
| Text truncation limit | `25,000 chars` | `25,000 chars` | Can increase proportionally |

- **Why 8192?** Conservative default to keep VRAM usage low (~4GB) and prefill speed fast.
- **Can increase to 16384** on RTX 5080 (16GB VRAM) for ~30 page PDFs without noticeable slowdown.
- **32768 max** supported but uses ~10GB VRAM and significantly slower prefill.