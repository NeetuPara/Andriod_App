# System Requirements

This document outlines the software and hardware requirements needed to build and run the Offline AI Chat application.

## 💻 Hardware Requirements

### Minimum (Text Only)
*   **OS**: Windows 10/11 (64-bit) OR Android 10+
*   **RAM**: 8 GB
*   **Storage**: 4 GB free space (for app + 2GB model)
*   **Processor**: Modern Quad-Core CPU (Intel i5 8th Gen / Snapdragon 855 or better)

### Recommended (Vision & Voice)
*   **RAM**: 16 GB (Essential for larger multimodal models like Qwen-VL)
*   **Processor**: 
    *   **Windows**: CPU with AVX2 support (Ryzen 5000+ / Intel 11th Gen+)
    *   **Android**: High-end Chipset (Snapdragon 8 Gen 2 / Dimensity 9000+)

## 🛠️ Build Requirements (For Developers)

To compile the code from source, you need the following tools installed.

### General
*   **Flutter SDK**: Version 3.27.0 or higher
*   **Dart SDK**: Version 3.6.0 or higher
*   **Git**: Latest stable version

### Windows Development
*   **Visual Studio 2022**:
    *   Workload: "Desktop development with C++"
    *   Component: "MSVC v143 - VS 2022 C++ x64/x86 build tools"
    *   Component: "Windows 10/11 SDK"
*   **CMake**: Version 3.20 or higher (usually included in VS)
*   **PowerShell**: Version 5.1 or 7+

### Android Development
*   **Android Studio**: Ladybug or newer
*   **Android SDK**:
    *   SDK Platforms: Android 14.0 ("UpsideDownCake") / API 34
    *   SDK Tools: Android SDK Build-Tools 34.0.0
*   **NDK (Native Development Kit)**: Version 26.x or 27.x (Required for `llama_cpp_dart` compilation)
*   **CMake**: Version 3.22.1 (via SDK Manager)

## 📦 Project Dependencies
*See `pubspec.yaml` for exact versions.*

*   **Core**: `flutter`, `provider`, `shared_preferences`
*   **AI Engine**: 
    *   `llama_cpp_dart`: `^0.1.2` (Strictly pinned for Android compatibility)
    *   `http`: `^1.2.0` (For Windows Server communication)
*   **Features**:
    *   `flutter_animate`: UI Animations
    *   `speech_to_text`: Voice Input
    *   `flutter_tts`: Voice Output
    *   `syncfusion_flutter_pdf`: PDF processing
    *   `file_picker`: Attachment handling

## ⚠️ Critical Notes
1.  **Windows Symlinks**: You **MUST** enable "Developer Mode" in Windows Settings to allow building plugins that use symlinks.
2.  **Android Libs**: If you encounter `libmtmd.so not found`, ensure you remain on `llama_cpp_dart: ^0.1.2`. Newer versions change the library structure.
