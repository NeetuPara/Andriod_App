# Architecture Documentation

## High-Level Overview

This application is a **local-first, offline AI chat interface** built with Flutter. It runs large language models (LLMs) directly on the user's device, ensuring privacy and offline capability.

### 🏗️ The Hybrid Offline Architecture

To maximize performance and compatibility across platforms, the app uses a **Hybrid Implementation Strategy** (using the best offline engine for each OS).

> **Important**: Both paths below run **100% locally** on the device. No internet is used. "Hybrid" here refers to the *technology used*, not the connectivity.

```mermaid
graph TD
    User[User] --> UI[Flutter UI (App.dart)]
    UI --> Service[SlmService (Logic)]
    
    subgraph "Windows (Desktop)"
        Service -- "HTTP (REST)" --> Server[llama-server.exe]
        Server -- "Loads" --> GGUF[Model.gguf]
    end
    
    subgraph "Android (Mobile)"
        Service -- "Dart FFI" --> Lib[llama_cpp_dart]
        Lib -- "Loads" --> MobileGGUF[Model.gguf]
        Lib -- "JNI" --> Native[libllama.so / libmtmd.so]
    end
```

### 🧩 Key Components

#### 1. Presentation Layer (`lib/src/screens` & `components`)
*   **`ChatApp` (`app.dart`)**: The main controller. Manages navigation, message state list, and coordinates between services.
*   **`PinScreen`**: Handles local authentication.
*   **`ChatInput`**: tailored text field with attachment and voice recording triggers.

#### 2. Service Layer (`lib/src/services`)
*   **`SlmService` ("The Brain")**:
    *   **Initialization**: Detects OS. On Windows, spawns `llama-server.exe`. On Android, initializes `Llama` class.
    *   **Inference**: Unifies the API. The UI calls `generateResponse()`, and `SlmService` routes it to either the HTTP client (Windows) or the FFI bridge (Android).
    *   **Prompt Engineering**: Converts chat history into ChatML format (`<|im_start|>...`) required by Qwen models.
*   **`DatabaseService`**: Persist chats using JSON/SharedPreferences.
*   **`FileProcessor`**: Handles PDF text extraction and image base64 encoding.

#### 3. Data Layer
*   **Local Storage**: Application Documents Directory (`flutter_app_chat_data`).
*   **Models**: GGUF format quantized models (e.g., `Qwen2.5-1.5B-Instruct.Q4_0.gguf`).

## 🔄 Data Flow

1.  **User Input**: User types or speaks.
2.  **Processing**: `ChatApp` creates a `Message` object.
    *   If **Image**: Converted to Base64.
    *   If **PDF**: Text extracted via `FileProcessor`.
3.  **Inference Request**: `SlmService.generateResponse(history)` is called.
4.  **Routing**:
    *   **Windows**: Converted to JSON -> POST `localhost:8081/v1/chat/completions`.
    *   **Mobile**: Prompt String constructed -> `_mobileLlama.prompt()`.
5.  **Streaming**: Tokens are yielded back to the UI in real-time.

## 🔒 Security
*   **Offline**: No internet permission required for inference (only for initial asset download if configured).
*   **Local Persistence**: Chat history is stored locally.
*   **PIN Protection**: Simple overlay to prevent unauthorized UI access.
