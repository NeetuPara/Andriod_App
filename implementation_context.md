# Edgemind VLM Implementation Context

This document outlines the architectural differences, common features, and specific parameters used across the Android (Mobile) and Desktop versions of the Edgemind application.

## 1. Common Shared Features (Android & Desktop)
- **PDF Text Extraction**: Both platforms extract text seamlessly when a document is uploaded. To prevent context window overflows, the extracted text is capped at 25,000 characters before being injected into the LLM prompt.
- **Image Previews**: The UI handles image attachments by displaying actual cropped thumbnails (both in the chat input and chat bubbles) rather than generic icons. Before processing, all images are resized to a maximum 512x512 bounding box to save RAM and inference time.
- **Conversation History**: Chat context is fully maintained across sessions.
- **Voice Input**: Streaming voice-to-text integration is available across both platforms.

---

## 2. Android App (Mobile Native) Implementation

The Android app runs the Vision-Language Model directly on the device using a native C++ module (JNI wrapper over `llama.cpp` and `mtmd`). 

### Key Mobile Features:
- **Zero-Latency Prompting (KV Cache Warmup)**: The moment a user selects an image, `prepareImageVLM` fires in the background. It tokenizes and computes the heavy image layers into the KV cache while the user is still typing their prompt, making the final response feel instantaneous.
- **Background PDF Extraction**: PDF text is extracted instantly upon selection and cached so the UI does not freeze when the user finally taps "Send".
- **Repetition Break Logic**: A custom C++ algorithm monitors the generated output sentences and forces the stream to stop if it detects the AI getting caught in a repetitive loop.

### Native C++ Parameters (`lib-vlm.cpp`):
- **Context Size (`n_ctx`)**: `4096`
  *(Explicitly optimized for modern flagship phones containing 8-12GB of RAM, leaving safe headroom for the OS).*
- **Max Output Tokens (`n_len`)**: `1024`
- **Batch Size (`n_batch`)**: `512`
- **Hardware Acceleration**: Relies on device CPU/GPU bridging built into the `llama_init_from_model` process.
- **Sampler Chain (Creativity Controls)**:
  Instead of generic greedy decoding, the Android engine uses a fixed temperature-based sampling chain to provide more natural sounding text:
  - **Top-K**: `40`
  - **Top-P**: `0.95`
  - **Temperature**: `0.7`

---

## 3. Desktop Application Implementation

The Desktop application bypasses the native C++ wrapper. Instead, it launches a detached instance of `llama-server.exe` as an independent local HTTP server and communicates via REST APIs.

### Key Desktop Features:
- **HTTP Server Architecture**: Automatically boots local server on strictly defined port `8081`. The Dart frontend uses standard OpenAI-compatible HTTP POST requests (`/v1/chat/completions`) and listens for Server-Sent Events (SSE) to stream the text.
- **Smart Image Payload Management**: Because it relies on HTTP, the desktop converts the resized 512x512 images into Base64 strings. To prevent crashing the local server with massive payloads (HTTP 400 errors), the app intelligently identifies and encodes *only* the most recently uploaded image in the conversation history, replacing older images with placeholder text.

### Local Server Parameters (`slm_service.dart`):
- **Context Size (`-c`)**: `8192`
  *(Desktop PCs generally have significantly more RAM, allowing for double the context window compared to mobile).*
- **Max Output Tokens**: `1024` (Passed in the JSON payload).
- **GPU Offloading (`-ngl`)**: `999` (Offloads as many layers to the GPU as possible).
- **Parallel processing**: `1`
- **Temperature**: Dynamically pulled from user settings (`DatabaseService().getSettings()`), defaulting to `0.7`.

---

## 4. Desktop PDF Processing vs Model Performance

The current implementation of the Desktop PDF extraction (`file_processor.dart` and `slm_service.dart`) **impacts model speed, but NOT accuracy.** 

**1. Context Window Impact (`n_ctx = 8192`)**
- As configured, the desktop context resolves to 8,192 tokens. 
- A standard 1-page PDF has roughly 500-800 tokens. 
- Massive PDFs are safely truncated at **25,000 characters** (~5,000 to 6,000 tokens). 
- **Result:** Because 6,000 tokens easily fits within the 8,192 token limit, the model will successfully process the *entire* extracted document without context overruns. Accuracy is perfectly preserved.

**2. Performance/Speed Impact**
- **Prefill Latency:** When a PDF is sent, all 6,000 document tokens must be ingested by the model simultaneously (known as "prefilling the KV cache"). Even on the desktop with `-ngl 999` GPU offloading, ingesting 6,000 tokens takes processing time. The desktop server will pause for several seconds before generating the first word. 
- **Memory (RAM/VRAM) Usage:** The combination of `n_ctx = 8192` and `-ngl 999` pushes the entire context window into the graphics card. Running the Desktop server will consume approximately **4.5GB to 5GB of VRAM**. 
- **Generation Speed:** Once the server finishes reading the PDF into the cache, the actual generation (word streaming) will remain very fast.

**Are these parameters safe?**
Yes. The chosen desktop parameters (`n_ctx=8192`, `temp=0.7`, and the 25k character truncation limit) perfectly balance maximum reading comprehension while preventing RAM crashes or HTTP 400 errors. 

*(Note: If the dart code is later modified to increase the truncation limit to 50,000 characters to support larger PDFs, `slm_service.dart` must also be manually edited to increase `-c` to `16384`, otherwise the desktop server will instantly crash halfway through reading the document!)*

---

## 5. Mobile (Android) PDF Processing vs Model Performance

Mobile hardware has significantly less RAM; therefore, the context window is intentionally halved compared to the desktop app.

**1. Context Window Impact (`n_ctx = 4096`)**
- As configured, the Android C++ engine resolves to exactly 4,096 tokens.
- The shared Dart `file_processor.dart` still safely truncates extremely large PDFs at 25,000 characters (~5,000 to 6,000 tokens).
- **Result (Context Overflow):** Because the 6,000 token chunk from a large PDF exceeds the mobile engine's `4096` hard limit, the engine will hit the end of its buffer. `llama.cpp` handles this natively by sliding the context window forward (forgetting the oldest tokens at the beginning of the document) to make room to stream its answer.

**2. Performance/Speed Impact**
- On a mobile device, the maximum readable document size without suffering from "AI Amnesia" is approximately **2 to 3 pages**. If a larger document is uploaded, the AI will still successfully answer, but it will have completely forgotten the first page of the document.

---

## 6. Where to Manually Adjust Parameters

If you wish to scale the application for more powerful hardware (or weaker hardware), you must manually edit the following files:

### For Android (Mobile)
- **File:** `android/app/src/main/cpp/lib-vlm.cpp`
- **Location:** Line 75 (`ctx_params.n_ctx = 4096;`)
- *Warning:* Increasing this past 4096 on mid-tier Android phones will cause the OS to aggressively kill the app due to RAM limits.

### For Windows (Desktop)
- **File:** `lib/src/services/slm_service.dart`
- **Location:** Line 120 (`'-c', '8192',`) under the `args` array.
- *Warning:* Increasing this past 8192 will demand significantly more than 5GB of VRAM and dramatically slow down the initial PDF "prefill" phase unless run on high-end GPUs (e.g., RTX 4080/5080).

### For Shared PDF Safety Limit
- **File:** `lib/src/services/file_processor.dart`
- **Location:** Line 42 (`if (text.length > 25000)`)
- *Warning:* If you increase this allowed character length, you **MUST** ensure both your Android `n_ctx` and Desktop `-c` arguments are equally increased to prevent crashes (Desktop) or severe context sliding (Mobile).
