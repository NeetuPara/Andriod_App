# EdgeMind Architecture & Flow

## Hybrid Offline Inference Engine

EdgeMind uses a unique **hybrid architecture** to run local LLMs efficiently on both Desktop and Mobile platforms using the same Flutter codebase.

| Platform | Inference Engine | Communication Protocol | Key Package |
|:---:|:---:|:---:|:---:|
| **Windows** | `llama-server.exe` (llama.cpp) | HTTP REST API (`localhost:8081`) | `http` |
| **Android** | `llama_flutter_android` (Native Lib) | Direct Dart FFI (In-Process) | `llama_flutter_android` |

### System Diagram

```mermaid
graph TD
    User([User]) --> UI[Flutter UI (app.dart)]
    UI --> ServiceLayer[Service Layer]
    
    subgraph Service Layer
        SlmService[SlmService (Brain)]
        DB[DatabaseService]
        FileProc[FileProcessor (PDF)]
    end
    
    ServiceLayer --> SlmService
    
    subgraph Windows Execution
        SlmService -- "HTTP POST /v1/chat/completions" --> LlamaServer[llama-server.exe]
        LlamaServer -- "Reads" --> ModelFile[(Qwen2.5-1.5B.gguf)]
    end
    
    subgraph Android Execution
        SlmService -- "Dart FFI Calls" --> JNI[JNI Bridge]
        JNI -- "Native C++" --> LlamaLib[libllama.so]
        LlamaLib -- "Reads" --> ModelFile
    end
    
    SlmService -- "Streams Tokens" --> UI
```

---

## Data Flow: "Send Message"

1.  **User Input**: User types a prompt or speaks (VoiceService) in `ChatInput` widget.
2.  **Processing**: `_handleSendMessage` in `app.dart` creates a `Message` object.
    *   If attachments exist, `FileProcessor` extracts text (e.g., from PDFs).
3.  **Persistence**: Message is saved to local storage via `DatabaseService` (SharedPreferences).
4.  **Inference (SlmService)**:
    *   **Android**: 
        *   Initializes `LlamaController` (if not ready).
        *   Converts chat history to `ChatMessage` objects.
        *   Calls `_mobileController.generateChat()` with `chatml` template.
        *   Streams tokens directly from native memory to Dart.
    *   **Windows**: 
        *   Checks if `llama-server.exe` is healthy.
        *   Converts chat history to OpenAI-compatible JSON.
        *   Sends HTTP POST request to `127.0.0.1:8081`.
        *   Streams Server-Sent Events (SSE) response.
5.  **UI Update**: The UI listens to the stream and updates the message bubble in real-time.

## Key Directories

*   **`lib/src/services/slm_service.dart`**: The core logic handling the split between Android and Windows execution.
*   **`android/app/src/main/`**: Contains `AndroidManifest.xml` (modified for memory) and build configurations.
*   **`assets/models/`**: Stores the GGUF model file (must be downloaded manually).
