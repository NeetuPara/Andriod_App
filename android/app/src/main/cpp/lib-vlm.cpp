#include <jni.h>
#include <string>
#include <vector>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <android/log.h>
#include <fstream>
#include <algorithm>
#include "llama.h"
#include "llama.cpp/tools/mtmd/mtmd.h"
#include "llama.cpp/tools/mtmd/mtmd-helper.h"
#include <mutex>

#define TAG "FlutterVLM"

static llama_model *g_model = nullptr;
static llama_context *g_ctx = nullptr;
static mtmd_context *g_mtmd_ctx = nullptr;

// Cache state for background processing
static std::string g_cached_image_path = "";
static llama_pos g_cached_n_past = 0;
static bool g_is_image_processed = false;

static std::mutex g_mutex;

// Log callback for mtmd/llama
void log_callback(ggml_log_level level, const char * text, void * user_data) {
    int android_level = ANDROID_LOG_INFO;
    if (level == GGML_LOG_LEVEL_ERROR) android_level = ANDROID_LOG_ERROR;
    else if (level == GGML_LOG_LEVEL_WARN) android_level = ANDROID_LOG_WARN;
    __android_log_print(android_level, TAG, "[Internal] %s", text);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1app_MainActivity_initVLM(
        JNIEnv *env,
        jobject,
        jstring model_path_jni,
        jstring mmproj_path_jni) {
        
    __android_log_print(ANDROID_LOG_INFO, TAG, "Initializing local VLM engine...");

    const char *model_path_c = env->GetStringUTFChars(model_path_jni, 0);
    std::string model_path(model_path_c);
    env->ReleaseStringUTFChars(model_path_jni, model_path_c);

    const char *mmproj_path_c = env->GetStringUTFChars(mmproj_path_jni, 0);
    std::string mmproj_path(mmproj_path_c);
    env->ReleaseStringUTFChars(mmproj_path_jni, mmproj_path_c);

    // Register log callback
    mtmd_helper_log_set(log_callback, nullptr);

    llama_backend_init();
    llama_model_params model_params = llama_model_default_params();
    g_model = llama_model_load_from_file(model_path.c_str(), model_params);
    if (g_model == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to load main model at %s", model_path.c_str());
        return;
    }

    // Initialize Vision Context
    if (!mmproj_path.empty()) {
        mtmd_context_params mtmd_params = mtmd_context_params_default();
        g_mtmd_ctx = mtmd_init_from_file(mmproj_path.c_str(), g_model, mtmd_params);
        if (g_mtmd_ctx == nullptr) {
            __android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to load mmproj model at %s", mmproj_path.c_str());
        } else {
            __android_log_print(ANDROID_LOG_INFO, TAG, "mmproj model loaded successfully!");
        }
    }

    llama_context_params ctx_params = llama_context_default_params();
    ctx_params.n_ctx = 4096; // Optimized for flagship mobile phones (8-12GB RAM)
    ctx_params.n_batch = 512;
    g_ctx = llama_init_from_model(g_model, ctx_params);
    if (g_ctx == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to create context");
        llama_model_free(g_model);
        g_model = nullptr;
        return;
    }
    __android_log_print(ANDROID_LOG_INFO, TAG, "VLM initialized successfully!");
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1app_MainActivity_prepareImageVLM(
        JNIEnv *env,
        jobject,
        jstring image_path_jni) {

    const char *image_path_c = env->GetStringUTFChars(image_path_jni, 0);
    std::string image_path_str(image_path_c);
    env->ReleaseStringUTFChars(image_path_jni, image_path_c);

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_ctx == nullptr || g_model == nullptr || g_mtmd_ctx == nullptr) {
        __android_log_print(ANDROID_LOG_ERROR, TAG, "Models not initialized, skipping prepareImage");
        return;
    }

    if (g_is_image_processed && g_cached_image_path == image_path_str) {
         return;
    }

    g_cached_image_path = image_path_str;
    g_is_image_processed = false;
    g_cached_n_past = 0;

    llama_memory_seq_rm(llama_get_memory(g_ctx), -1, -1, -1);
    
    mtmd_bitmap *bitmap = mtmd_helper_bitmap_init_from_file(g_mtmd_ctx, image_path_str.c_str());
    if (!bitmap) {
         __android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to load image for preparation: %s", image_path_str.c_str());
         return;
    }

    // Prepare prompt prefix
    std::string prefix_prompt = "<|im_start|>user\n<__media__>";
    
    mtmd_input_chunks *chunks = mtmd_input_chunks_init();
    mtmd_input_text input_text = {prefix_prompt.c_str(), true, true};
    const mtmd_bitmap *bitmaps[] = {bitmap};

    if (mtmd_tokenize(g_mtmd_ctx, chunks, &input_text, bitmaps, 1) != 0) {
         __android_log_print(ANDROID_LOG_ERROR, TAG, "Failed to tokenize prefix");
         mtmd_input_chunks_free(chunks);
         mtmd_bitmap_free(bitmap);
         return;
    }

    llama_pos new_n_past = 0;
    if (mtmd_helper_eval_chunks(g_mtmd_ctx, g_ctx, chunks, 0, 0, 4096, true, &new_n_past) != 0) {
         mtmd_input_chunks_free(chunks);
         mtmd_bitmap_free(bitmap);
         return;
    }

    g_cached_n_past = new_n_past;
    g_is_image_processed = true;
    __android_log_print(ANDROID_LOG_INFO, TAG, "Image prepared successfully. n_past: %d", g_cached_n_past);

    mtmd_input_chunks_free(chunks);
    mtmd_bitmap_free(bitmap);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_flutter_1app_MainActivity_runVLM(
        JNIEnv *env,
        jobject thiz,
        jstring prompt_jni,
        jstring image_path_jni) {

    __android_log_print(ANDROID_LOG_INFO, TAG, "runVLM starting...");

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_ctx == nullptr || g_model == nullptr) {
        return env->NewStringUTF("Model not initialized");
    }

    const char *prompt_c = env->GetStringUTFChars(prompt_jni, 0);
    std::string prompt_str(prompt_c);
    env->ReleaseStringUTFChars(prompt_jni, prompt_c);

    const char *image_path_c = env->GetStringUTFChars(image_path_jni, 0);
    std::string image_path_str(image_path_c);
    env->ReleaseStringUTFChars(image_path_jni, image_path_c);

    bool use_cache = false;
    if (!image_path_str.empty() && g_is_image_processed && g_cached_image_path == image_path_str) {
        use_cache = true;
    }

    std::string full_prompt;
    mtmd_bitmap *bitmap = nullptr;
    llama_pos n_past = 0;

    if (use_cache) {
        n_past = g_cached_n_past;
        full_prompt = "\n" + prompt_str + "<|im_end|>\n<|im_start|>assistant\n";
    } else {
        if (!image_path_str.empty() && g_mtmd_ctx != nullptr) {
            bitmap = mtmd_helper_bitmap_init_from_file(g_mtmd_ctx, image_path_str.c_str());
            if (!bitmap) {
                 return env->NewStringUTF(("Failed to load image: " + image_path_str).c_str());
            }
        }
        if (bitmap) {
            full_prompt = "<|im_start|>user\n<__media__>\n" + prompt_str + "<|im_end|>\n<|im_start|>assistant\n";
        } else {
            full_prompt = "<|im_start|>user\n" + prompt_str + "<|im_end|>\n<|im_start|>assistant\n";
        }
        llama_memory_seq_rm(llama_get_memory(g_ctx), -1, -1, -1);
    }

    if (use_cache) {
        llama_memory_seq_rm(llama_get_memory(g_ctx), 0, n_past, -1);
    }

    mtmd_input_chunks *chunks = mtmd_input_chunks_init();
    mtmd_input_text input_text = {full_prompt.c_str(), true, true};
    const mtmd_bitmap *bitmaps[] = {bitmap};

    int ret = 0;
    if (g_mtmd_ctx != nullptr && bitmap != nullptr) {
         ret = mtmd_tokenize(g_mtmd_ctx, chunks, &input_text, bitmaps, 1);
    } else if (g_mtmd_ctx != nullptr) {
         ret = mtmd_tokenize(g_mtmd_ctx, chunks, &input_text, nullptr, 0);
    } else {
         ret = -1; // Force fallback to default llama_tokenize
    }
    
    if (ret != 0 || g_mtmd_ctx == nullptr) {
         // Fallback to text-only llama_tokenize
         const llama_vocab * vocab = llama_model_get_vocab(g_model);
         std::vector<llama_token> tokens(full_prompt.length() + 4);
         int n_tokens = llama_tokenize(vocab, full_prompt.c_str(), full_prompt.length(), tokens.data(), tokens.size(), true, true);
         if (n_tokens < 0) {
              tokens.resize(-n_tokens);
              n_tokens = llama_tokenize(vocab, full_prompt.c_str(), full_prompt.length(), tokens.data(), tokens.size(), true, true);
         }
         tokens.resize(n_tokens);

         llama_batch batch = llama_batch_init(tokens.size(), 0, 1);
         for (size_t i = 0; i < tokens.size(); i++) {
             batch.token[i] = tokens[i];
             batch.pos[i] = n_past++;
             batch.n_seq_id[i] = 1;
             batch.seq_id[i][0] = 0;
             batch.logits[i] = false;
         }
         batch.logits[tokens.size() - 1] = true;
         llama_decode(g_ctx, batch);
         llama_batch_free(batch);
    } else {
        llama_pos new_n_past = 0;
        ret = mtmd_helper_eval_chunks(g_mtmd_ctx, g_ctx, chunks, n_past, 0, 4096, true, &new_n_past);
        if (ret != 0) {
             mtmd_input_chunks_free(chunks);
             if (bitmap) mtmd_bitmap_free(bitmap);
             return env->NewStringUTF("Failed to evaluate chunks");
        }
        n_past = new_n_past;
    }

    mtmd_input_chunks_free(chunks);
    if (bitmap) mtmd_bitmap_free(bitmap);

    jclass mainActivityClass = env->GetObjectClass(thiz);
    jmethodID onTokenGeneratedMethod = env->GetMethodID(mainActivityClass, "onTokenGenerated", "(Ljava/lang/String;)V");

    std::string result = "";
    int n_len = 1024;
    int n_cur = 0;
    const llama_vocab * vocab = llama_model_get_vocab(g_model);

    // Temperature-based sampling chain (top-k → top-p → temperature → dist)
    auto * smpl = llama_sampler_chain_init(llama_sampler_chain_default_params());
    llama_sampler_chain_add(smpl, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(smpl, llama_sampler_init_top_p(0.95f, 1));
    llama_sampler_chain_add(smpl, llama_sampler_init_temp(0.7f));
    llama_sampler_chain_add(smpl, llama_sampler_init_dist(0));

    llama_batch batch = llama_batch_init(1, 0, 1);

    while (n_cur < n_len) {
        // Sample next token using temperature sampling chain
        llama_token next_token = llama_sampler_sample(smpl, g_ctx, -1);

        if (next_token == llama_vocab_eos(vocab)) {
            break;
        }

        char piece[256] = {0};
        int n_chars = llama_token_to_piece(vocab, next_token, piece, sizeof(piece) - 1, 0, false);
        piece[n_chars] = '\0';
        std::string token_str(piece);

        if (token_str.find("<|im_end|>") != std::string::npos ||
            token_str.find("<|endoftext|>") != std::string::npos) {
            break;
        }

        result += token_str;

        // Repetition block
        if (token_str == "." || token_str == "!" || token_str == "?" || token_str.find('\n') != std::string::npos) {
             size_t last_punct = result.find_last_of(".!?\n", result.length() - 2);
             if (last_punct != std::string::npos) {
                 std::string current_sentence = result.substr(last_punct + 1);
                 current_sentence.erase(0, current_sentence.find_first_not_of(" \t\r\n"));
                 std::string previous_text = result.substr(0, last_punct + 1);
                 if (previous_text.length() > current_sentence.length() &&
                     previous_text.find(current_sentence) != std::string::npos) {
                      result.resize(last_punct + 1);
                      break;
                 }
             }
        }

        if (onTokenGeneratedMethod != nullptr) {
            jstring tokenJni = env->NewStringUTF(token_str.c_str());
            env->CallVoidMethod(thiz, onTokenGeneratedMethod, tokenJni);
            env->DeleteLocalRef(tokenJni);
        }

        batch.token[0] = next_token;
        batch.pos[0] = n_past;
        batch.n_seq_id[0] = 1;
        batch.seq_id[0][0] = 0;
        batch.logits[0] = true;
        batch.n_tokens = 1;

        if (llama_decode(g_ctx, batch) != 0) {
             break;
        }
        n_past++;
        n_cur++;
    }
    llama_batch_free(batch);
    llama_sampler_free(smpl);

    // Stream finished marker
    if (onTokenGeneratedMethod != nullptr) {
        jstring tokenJni = env->NewStringUTF("[DONE]");
        env->CallVoidMethod(thiz, onTokenGeneratedMethod, tokenJni);
        env->DeleteLocalRef(tokenJni);
    }

    return env->NewStringUTF(result.c_str());
}
