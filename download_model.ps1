$ErrorActionPreference = "Stop"

$docsDir = [Environment]::GetFolderPath("MyDocuments")
$targetDir = Join-Path $docsDir "flutter_app_chat_data"
$modelPath = Join-Path $targetDir "qwen_model_v1.gguf"
$mmprojPath = Join-Path $targetDir "mmproj-model-f16.gguf"

if (-not (Test-Path $targetDir)) {
    New-Item -ItemType Directory -Path $targetDir | Out-Null
}

Write-Host "Target Directory: $targetDir"

function Download-With-Fallback {
    param ($urls, $dest)
    
    foreach ($url in $urls) {
        try {
            Write-Host "Checking URL: $url"
            # HEAD request check
            $req = Invoke-WebRequest -Uri $url -Method Head -ErrorAction Stop
            if ($req.StatusCode -eq 200) {
                Write-Host "Found! Downloading to $dest..."
                Invoke-WebRequest -Uri $url -OutFile $dest
                Write-Host "Download complete."
                return $true
            }
        } catch {
            Write-Host "URL failed: $_"
        }
    }
    return $false
}

# 1. Download Model (LLM)
if (-not (Test-Path $modelPath)) {
    $modelUrls = @(
        "https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/qwen3-vl-2b-instruct-q4_k_m.gguf",
        "https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/Qwen3-VL-2B-Instruct-Q4_K_M.gguf",
        "https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/qwen2.5-vl-3b-instruct-q4_k_m.gguf",
        "https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf"
    )
    
    Write-Host "Attempting to download Qwen3-VL Model..."
    $success = Download-With-Fallback -urls $modelUrls -dest $modelPath
    if (-not $success) {
        Write-Warning "Failed to download model. Please download 'Qwen3-VL-2B-Instruct-Q4_K_M.gguf' manually and save to: $modelPath"
    }
} else {
    Write-Host "Model already exists at $modelPath"
}

# 2. Download Projector (Vision Encoder)
if (-not (Test-Path $mmprojPath)) {
    $projUrls = @(
        "https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/mmproj-model-f16.gguf",
        "https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF/resolve/main/mmproj-Qwen3-VL-2B-Instruct-f16.gguf",
        "https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/mmproj-model-f16.gguf",
        "https://huggingface.co/Qwen/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/mmproj-Qwen2.5-VL-3B-Instruct-f16.gguf"
    )

    Write-Host "Attempting to download Vision Projector..."
    $success = Download-With-Fallback -urls $projUrls -dest $mmprojPath
    if (-not $success) {
        Write-Warning "Failed to download projector. Please download 'mmproj-model-f16.gguf' manually and save to: $mmprojPath"
    } else {
        # slm_service.dart logic: it scans the directory for *mmproj*.gguf. 
        # So we name it nicely or it is fine.
    }
} else {
    Write-Host "Projector already exists at $mmprojPath"
}
