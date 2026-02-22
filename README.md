# Edgemind VLM Architecture

**Edgemind** is a fully offline, privacy-focused AI assistant built with Flutter. It runs large language models (specifically Qwen2.5-VL-3B) **100% locally and offline** on both Android and Windows platforms. 

## 🚀 Key Capabilities
* **Full Offline Operation**: No cloud APIs, no internet required. All data and documents stay strictly on-device.
* **True Multimodal Vision**: Upload images directly from your device. The native vision projector analyzes them accurately without sending pixels to a server.
* **Document Intelligence**: Upload and extract text from massive PDFs.
* **Persistent History**: The Chat UI saves your conversation contexts perfectly across app restarts.
* **Voice Enabled**: Talk to your assistant with speech-to-text integration.

---

## 💻 1. Windows Desktop Local Setup

The Windows Desktop version runs an isolated `llama-server.exe` background process that securely pipes data from the Flutter UI over local HTTP (`127.0.0.1:8081`).

### Prerequisites (For 1st Time Setup)
1. **Developer Mode**: Must be enabled in Windows Settings (Settings → Privacy & Security → For Developers → Developer Mode → ON).
2. **Flutter Desktop Support**: Run `flutter config --enable-windows-desktop` in your terminal.
3. **NuGet**: Required by `flutter_tts`. Ensure `nuget.exe` is installed and added to your systemic `PATH`.

### Step-by-Step Build Instructions

1. **Clone the code:**
   ```bash
   git clone https://github.com/NeetuPara/Andriod_App.git
   cd Andriod_App/Edgemind-main
   ```
   *(Note: The required `llama-server.exe` and Vulkan DLLs are already included in this repository under the `llama-win` directory. No need to download them manually!)*

2. **Clean and fetch dependencies:**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Download the GGUF Models:**
   * Because the actual 1.5GB+ AI models are too big for GitHub, you must download them manually.
   * Create this exact folder path on your PC: `C:\Users\<username>\Documents\flutter_app_chat_data`
   * Download the following two models from the [Unsloth HuggingFace Repository](https://huggingface.co/unsloth/Qwen2.5-VL-3B-Instruct-GGUF/tree/main) and place them in that folder:
     * **Model:** `Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf`
     * **Projector:** `mmproj-Qwen2.5-VL-3B-Instruct-f16.gguf`

4. **Run the App in Debug Mode:**
   ```bash
   flutter run -d windows
   ```
   *The app will automatically launch the `llama-server.exe` in the background utilizing Vulkan GPU acceleration (`-ngl 999`).*

---

## 📱 2. Android Mobile Setup (Native JNI)

The Android app bypasses `llama-server.exe` entirely. Instead, it uses custom Native Android C++ bridges (`lib-vlm.cpp`) compiled via CMake to run the `llama.cpp` inference engine directly on the phone's hardware.

### Prerequisites (For 1st Time Setup)
1. **Android Studio**: Installed with the latest NDK (Native Development Kit) and CMake via the SDK Manager.
2. **Physical Phone**: Emulators are generally too weak to run a 3B parameter model. An Android phone with a minimum of 8GB of RAM is highly recommended.

### Step-by-Step Build Instructions

1. **Download the GGUF Models for Mobile:**
   * For the mobile build, the model files **must be bundled into the APK**.
   * Download the same models mentioned in the Desktop steps above.
   * Rename and place them directly into your Flutter assets folder:
     * `Edgemind-main/assets/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf`
     * `Edgemind-main/assets/mmproj-Qwen2.5-VL-3B-Instruct-f16.gguf`

2. **Ensure Assets are tracked in `pubspec.yaml`**:
   Ensure these lines exist and are uncommented inside `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf
       - assets/mmproj-Qwen2.5-VL-3B-Instruct-f16.gguf
   ```

3. **Build the Release APK:**
   * **CRITICAL:** Because of Dart's memory limits during Debug (JIT compilation), **large models will crash the app when running in Debug mode on Android.** 
   * You **MUST** build the app in release mode (AOT compilation) for it to successfully stream the 1.5GB assets onto the device storage.
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release --target-platform android-arm64
   ```

4. **Install the APK:**
   * Locate the built APK at `build/app/outputs/flutter-apk/app-release.apk`.
   * Install it on your phone: `adb install -r build/app/outputs/flutter-apk/app-release.apk`
   * On the very first launch, the app will freeze for approximately 10-20 seconds as it safely copies the massive model assets from the Flutter bundle into the Android App Data storage partition.

---

## ⚙️ Advanced Parameter Tuning

This repository is strictly tuned to balance RAM usage and inference speed.

### PDF & Read Context
The Flutter UI (via `file_processor.dart`) safely truncates massive PDFs down to `25,000` characters (approx 5,000 to 6,000 tokens) to prevent overflowing the AI's memory.

If you edit `file_processor.dart` to allow larger PDF chunks (e.g., 50,000 characters), you must manually upgrade the hardware RAM context parameters:
* **Desktop Context Limit:** `lib/src/services/slm_service.dart` (Line 120 `'-c', '8192'`)
* **Mobile Context Limit:** `android/app/src/main/cpp/lib-vlm.cpp` (Line 75 `ctx_params.n_ctx = 4096;`)

*Note: The mobile engine defaults to 4096. If you push a 6,000 token PDF into it, `llama.cpp` will natively perform a "Context Window Slide"—it will intentionally forget the earliest tokens at the beginning of the PDF to make room to stream its answer without crashing the phone.*
