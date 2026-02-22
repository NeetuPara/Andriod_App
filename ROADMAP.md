# Technical Optimization Roadmap (High-Performance Engineering)

This document focuses exclusively on **Latency Reduction** and **Throughput Optimization** for the local LLM stack.

## 1. 🚀 Latency Optimization (Reduce "Time to First Token")

### **A. Persistent KV Cache (The "Zero-Eval" Strategy)**
*   **Current Bottleneck**: Every new message re-evaluates the entire chat history. If history is 2000 tokens, the user waits ~3-5 seconds just to *start* generating.
*   **Optimization**:
    *   **Disk-Based KV Cache**: Dump the processed context (key-value states) to disk (`.bin` file).
    *   **In-Memory Slot Recycling**: Keep the `llama_context` alive between `SlmService.generateResponse` calls. Don't destroy/recreate the engine.
    *   **Impact**: **Instant responses** (0.1s latency) for follow-up questions, regardless of chat length.

### **B. Speculative Decoding (The "Drafting" Strategy)**
*   **Concept**: Think of this as a **Senior Writer (The Main AI)** and a **Junior Intern (A Tiny, Fast AI)** working together.
    1.  The **Intern** quickly guesses the next 5 words (because they are fast but sometimes wrong).
    2.  The **Senior Writer** reads those 5 words in one glance.
    3.  If they are correct, the Senior approves them all at once (Saving 5 steps).
    4.  If one is wrong, the Senior corrects it and continues.
*   **Why it's faster**: The big model (Senior) is slow to *write* but fast to *read*. It's faster to verify 5 words than to write them one by one.
*   **Impact**: Can increase typing speed by **2x-3x** without losing any intelligence.

### **C. Prompt Processing Batching**
*   **Optimization**: Ensure `llama_server` uses huge batch sizes (e.g., 512 or 1024) during the prompt phase.
*   **Impact**: drastically reduces the initial "thinking" time by utilizing SIMD instructions (AVX2/NEON) more effectively.

## 2. 🏎️ Throughput Optimization (Tokens Per Second)

### **A. Android GPU/NPU Acceleration**
*   **Current State**: Android build uses CPU only (via `llama_cpp_dart` default).
*   **Optimization**:
    *   **Vulkan Backend**: Compile `llama.cpp` with `-DGGML_VULKAN=ON`.
    *   **OpenCL (CLBlast)**: For Adreno GPUs.
    *   **NNAPI**: To potentially tap into the phone's NPU.
*   **Impact**: Shift load from CPU to GPU. Massive speedup (from ~5 t/s to ~15-20 t/s) and less battery drain.

### **B. Flash Attention**
*   **Optimization**: Ensure the `llama.cpp` backend is compiled with Flash Attention enabled.
*   **Impact**: Reduces memory bandwidth usage during self-attention, speeding up long-context generation.

### **C. Quantization Mixing (K-Quants)**
*   **Strategy**: Use `IQ4_XS` (Importance Matrix Quantization) instead of standard `Q4_0`.
*   **Impact**: Same quality but smaller size and faster memory reads.

## 3. 🧠 Smart Context Management

### **A. Rolling Context Window (Context Shifting)**
*   **Current**: If context fills up (8192 tokens), we essentially crash or have to clear completely.
*   **Optimization**: Implement a "circular buffer" where the oldest messages are evicted from the KV cache without triggering a full re-computation of the newer messages.

### **B. Summarization Thread**
*   **Optimization**: When the user is idle, spawn a background process to summarize the first 50% of the conversation into a concise system prompt.
*   **Impact**: Keeps the active context small and fast forever.

---
*These updates move the project from a "Prototype" to a "Production-Grade" inference engine.*
