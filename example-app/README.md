# Capacitor LLM Example App

This example app demonstrates how to use the @capgo/capacitor-llm plugin in a real application.

> Upstream notice: Google is deprecating the MediaPipe LLM Inference API on **Android and iOS** in favor of [LiteRT-LM](https://github.com/google-ai-edge/LiteRT-LM). This example still uses MediaPipe on mobile today; LiteRT-LM support will be adopted once stable SDKs are available. The web backend remains on MediaPipe because it is not deprecated.

## Prerequisites

- Node.js and npm/bun installed
- Xcode (for iOS development)
- Android Studio (for Android development)
- Capacitor CLI

## Setup

1. Install dependencies:
```bash
bun install
```

2. Sync Capacitor:
```bash
npx cap sync
```

## Getting and Adding Models for Testing

### iOS Setup

#### Option 1: Use Apple Intelligence (Recommended - iOS 18.2+)

The easiest way to test on iOS is to use Apple Intelligence, which requires no model downloads:

1. Ensure your device runs iOS 18.2 or later
2. Enable Apple Intelligence in Settings > Apple Intelligence & Siri
3. In your app code, use:
```typescript
await CapgoLLM.setModel({ path: 'Apple Intelligence' });
```

No additional setup required!

#### Option 2: Use Custom MediaPipe Models (Experimental)

**⚠️ Warning**: Custom models on iOS have compatibility issues and may not work reliably. Use Apple Intelligence instead when possible.

If you want to try custom models anyway:

1. **Download a Gemma-2 2B model**:
   - Visit [Hugging Face MediaPipe Models](https://huggingface.co/collections/google/mediapipe-668392ead2d6768e82fb3b87)
   - Look for models named `Gemma2-2B-IT_*_ekv*.task`
   - Example: Download `Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280.task`
   - Note: These files are typically 1-2GB in size

2. **Add the model to Xcode**:
   - Open the iOS project in Xcode:
     ```bash
     npx cap open ios
     ```
   - Right-click on the `App` folder in the project navigator
   - Select "Add Files to 'App'..."
   - Select your downloaded `.task` file
   - **Important**: Check "Copy items if needed"
   - **Important**: In "Add to targets", make sure "App" is checked

3. **Verify the model is in the bundle**:
   - Select your app target
   - Go to "Build Phases" tab
   - Expand "Copy Bundle Resources"
   - Make sure your `.task` file is listed there

4. **Use the model in your code**:
```typescript
import { CapgoLLM } from '@capgo/capacitor-llm';

await CapgoLLM.setModel({
  path: 'Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280',  // Without .task extension
  modelType: 'task',
  maxTokens: 1280
});
```

### Android Setup

Android requires you to bundle or download models, as there's no built-in equivalent to Apple Intelligence yet.

#### Step 1: Download the Model

**Recommended: Gemma-3 270M** (Smallest and fastest)

1. Go to [Kaggle Gemma Models](https://www.kaggle.com/models/google/gemma)
2. Select the model you want (recommended: Gemma 3 270M)
3. Click on the **"LiteRT (formerly TFLite)"** tab
4. Download BOTH files:
   - `gemma-3-270m-it-int8.task` (~240MB)
   - `gemma-3-270m-it-int8.litertlm` (~4MB)

**Note**: You'll need a Kaggle account to download models. Sign up at [kaggle.com](https://www.kaggle.com) if you don't have one.

Alternative models (larger, more capable):
- Gemma-3 1B (~892MB-1.5GB)
- Gemma-2 2B (~1-2GB)

#### Step 2: Add Models to Your Android App

**Option A: Bundle in the APK** (for testing)

1. Create the assets directory if it doesn't exist:
```bash
mkdir -p android/app/src/main/assets
```

2. Copy BOTH model files to the assets directory:
```bash
cp gemma-3-270m-it-int8.task android/app/src/main/assets/
cp gemma-3-270m-it-int8.litertlm android/app/src/main/assets/
```

3. Verify the files are in place:
```bash
ls -lh android/app/src/main/assets/
```

4. Use the model in your code:
```typescript
import { CapgoLLM } from '@capgo/capacitor-llm';

// The /android_asset/ prefix references the assets folder
await CapgoLLM.setModel({
  path: '/android_asset/gemma-3-270m-it-int8.task',
  maxTokens: 2048
});
```

**Option B: Download at Runtime** (for production apps)

For production, you'll want to download models at runtime to keep your APK size small:

```typescript
import { CapgoLLM, Filesystem, Directory } from '@capgo/capacitor-llm';

async function downloadAndSetModel() {
  // Download the model files
  const modelUrl = 'https://your-server.com/models/gemma-3-270m-it-int8.task';
  const companionUrl = 'https://your-server.com/models/gemma-3-270m-it-int8.litertlm';

  // Use the plugin's download function with progress tracking
  const result = await CapgoLLM.downloadModel({
    url: modelUrl,
    filename: 'gemma-3-270m-it-int8.task',
    companionUrl: companionUrl
  });

  // The plugin returns the path where files were saved
  await CapgoLLM.setModel({
    path: result.path,
    maxTokens: 2048
  });
}
```

#### Step 3: Update minSdkVersion

Ensure your `android/variables.gradle` has the correct minimum SDK version:

```gradle
ext {
    minSdkVersion = 24
    compileSdkVersion = 34
    targetSdkVersion = 34
    // ... other settings
}
```

## Running the Example App

### iOS

```bash
npx cap run ios
```

Or open in Xcode:
```bash
npx cap open ios
```

### Android

```bash
npx cap run android
```

Or open in Android Studio:
```bash
npx cap open android
```

## Testing the Plugin

Once you have the models set up, you can test the plugin:

```typescript
import { CapgoLLM } from '@capgo/capacitor-llm';

// 1. Set up the model (choose one based on your platform)
// For iOS with Apple Intelligence:
await CapgoLLM.setModel({ path: 'Apple Intelligence' });

// For Android with bundled model:
await CapgoLLM.setModel({ path: '/android_asset/gemma-3-270m-it-int8.task' });

// 2. Check if the model is ready
const { readiness } = await CapgoLLM.getReadiness();
console.log('Model readiness:', readiness);

// 3. Create a chat session
const { id } = await CapgoLLM.createChat({
  instructions: 'You are a helpful assistant.'
});

// 4. Listen for responses
CapgoLLM.addListener('textFromAi', (data) => {
  console.log('Received chunk:', data.text);
});

CapgoLLM.addListener('aiFinished', () => {
  console.log('AI finished responding');
});

// 5. Send a message
await CapgoLLM.sendMessage({
  chatId: id,
  message: 'Hello! Tell me a short joke.'
});
```

## Troubleshooting

### iOS Issues

1. **"Model file not found in bundle"**:
   - Verify the model is added to "Copy Bundle Resources" in Build Phases
   - Check that you're using the filename without the extension in `setModel()`
   - Clean build folder (Cmd+Shift+K) and rebuild

2. **"prefill_input_names.size() % 2)==(0)" error**:
   - This is a known compatibility issue with `.task` format models on iOS
   - Switch to Apple Intelligence instead: `setModel({ path: 'Apple Intelligence' })`

3. **Apple Intelligence not available**:
   - Ensure your device runs iOS 18.2 or later
   - Enable Apple Intelligence in Settings
   - Some devices may not support Apple Intelligence

### Android Issues

1. **"Model file not found"**:
   - Verify both `.task` and `.litertlm` files are in `android/app/src/main/assets/`
   - Rebuild the app to include new assets
   - Check file names match exactly (case-sensitive)

2. **App crashes on model load**:
   - Check that `minSdkVersion` is set to 24 or higher
   - Ensure you have enough device memory (models can be large)
   - Try a smaller model like Gemma-3 270M

3. **"Insufficient memory"**:
   - Use a smaller model (Gemma-3 270M instead of 1B or 2B)
   - Reduce `maxTokens` parameter
   - Close other apps to free up memory

## Model Size Reference

When choosing a model, consider these approximate sizes:

| Model | Size | RAM Usage | Speed | Best For |
|-------|------|-----------|-------|----------|
| Gemma-3 270M | ~240-400MB | Low | Fast | Testing, simple tasks |
| Gemma-3 1B | ~892MB-1.5GB | Medium | Medium | Balanced performance |
| Gemma-2 2B | ~1-2GB | High | Slower | Best quality responses |

For testing purposes, start with Gemma-3 270M on Android or Apple Intelligence on iOS.

## Additional Resources

- [Plugin Documentation](https://capgo.app/docs/plugins/llm/)
- [Kaggle Gemma Models](https://www.kaggle.com/models/google/gemma)
- [Hugging Face MediaPipe Models](https://huggingface.co/collections/google/mediapipe-668392ead2d6768e82fb3b87)
- [MediaPipe GenAI Documentation](https://developers.google.com/mediapipe/solutions/genai/llm_inference)
