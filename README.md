# @capgo/capacitor-llm

<a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin"> ➡️ Get Instant updates for your App with Capgo 🚀</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin"> Fix your annoying bug now, Hire a Capacitor expert 💪</a></h2>
</div>

Adds support for LLM locally runned for Capacitor

It uses Apple Intelligence (default) or MediaPipe custom models on iOS, and MediaPipe's tasks-genai on Android

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/llm/

## Installation

```bash
npm install @capgo/capacitor-llm
npx cap sync
```

### iOS Additional Setup for Custom Models

If you want to use custom models on iOS (not just Apple Intelligence), you need to install MediaPipe dependencies.

**Using CocoaPods:**
The MediaPipe dependencies are already configured in the podspec. Make sure to run `pod install` after adding the plugin.

**Note about Static Framework Warning:**
When running `pod install`, you may see a warning about transitive dependencies with statically linked binaries. To fix this, update your Podfile:

```ruby
# Change this:
use_frameworks!

# To this:
use_frameworks! :linkage => :static

# And add this to your post_install hook:
post_install do |installer|
  assertDeploymentTarget(installer)
  
  # Fix for static framework dependencies
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
    end
    
    # Specifically for MediaPipe pods
    if target.name.include?('MediaPipeTasksGenAI')
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_BITCODE'] = 'NO'
      end
    end
  end
end
```

**Using Swift Package Manager:**

MediaPipe GenAI does not officially support SPM yet (see [MediaPipe issue #5464](https://github.com/google-ai-edge/mediapipe/issues/5464)). However, you can use the community package [SwiftTasksGenAI](https://github.com/paescebu/SwiftTasksGenAI) by adding it manually in Xcode:

**To add MediaPipe GenAI via SPM:**
1. Open your app project in Xcode
2. Go to **File > Add Package Dependencies...**
3. Enter the URL: `https://github.com/paescebu/SwiftTasksGenAI.git`
4. Select your desired version (e.g., 0.10.24)
5. Add the `SwiftTasksGenAI` product to your app target

**Note:** SwiftTasksGenAI uses unsafe build flags, which means it cannot be added directly in Package.swift files, but works fine when added through Xcode's UI. This is the same approach used by SwiftTasksVision.

**Alternatively:** Use CocoaPods for a more traditional setup, or use Apple Intelligence (iOS 18.2+) which works with both SPM and CocoaPods.

## Adding a Model to Your App

### iOS

On iOS, you have two options:

1. **Apple Intelligence (Default)**: Uses the built-in system model (requires iOS 26.0+) - Recommended
2. **Custom Models**: Use your own models via MediaPipe (requires CocoaPods) - Note: Some model formats may have compatibility issues

#### Using Apple Intelligence (Default)

No additional setup needed. The plugin will automatically use Apple Intelligence on supported devices (iOS 26.0+).

#### Using Custom Models on iOS via MediaPipe

**⚠️ IMPORTANT**: While MediaPipe documentation states Gemma-2 2B works on all platforms, iOS implementation has compatibility issues with `.task` format models, often resulting in `(prefill_input_names.size() % 2)==(0)` errors.

## Model Compatibility Guide

### Android (Working ✅)
- **Model**: Gemma-3 models (270M, 1B, etc.)
- **Format**: `.task` + `.litertlm` files
- **Where to download**: 
  - [Kaggle Gemma models](https://www.kaggle.com/models/google/gemma) - "LiteRT (formerly TFLite)" tab
  - Example: `gemma-3-270m-it-int8.task` + `gemma-3-270m-it-int8.litertlm`

### iOS (Limited Support ⚠️)
- **Recommended**: Use Apple Intelligence (built-in, no download needed)
- **Alternative (Experimental)**: 
  - **Model**: Gemma-2 2B (documented as compatible but may still fail)
  - **Format**: `.task` files (`.bin` format preferred but not available)
  - **Where to download**:
    - [Hugging Face MediaPipe models](https://huggingface.co/collections/google/mediapipe-668392ead2d6768e82fb3b87) 
    - Look for `Gemma2-2B-IT_*_ekv*.task` files
    - Example: `Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280.task`
  - **Note**: Even with Gemma-2 2B, you may still encounter errors. Apple Intelligence is more reliable.

### Web
- **Model**: Gemma-3 models
- **Format**: `.task` files
- **Where to download**: Same as Android

## Download Instructions

1. **For Android**:
   - Go to [Kaggle Gemma models](https://www.kaggle.com/models/google/gemma)
   - Click "LiteRT (formerly TFLite)" tab
   - Download both `.task` and `.litertlm` files
   - Place in `android/app/src/main/assets/`

2. **For iOS** (if not using Apple Intelligence):
   - Visit [Hugging Face MediaPipe collection](https://huggingface.co/collections/google/mediapipe-668392ead2d6768e82fb3b87)
   - Find Gemma-2 2B models
   - Download `.task` files (and `.litertlm` if available)
   - Add to Xcode project in "Copy Bundle Resources"
   - Note: Success is not guaranteed due to format compatibility issues

3. **Set the model path**:

```typescript
import { CapgoLLM } from '@capgo/capacitor-llm';

// iOS - Use Apple Intelligence (default)
await CapgoLLM.setModel({ path: 'Apple Intelligence' });

// iOS - Use MediaPipe model (experimental)
await CapgoLLM.setModel({ 
  path: 'Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280',
  modelType: 'task',
  maxTokens: 1280
});

// Now you can create chats and send messages
const chat = await CapgoLLM.createChat();
```

### Android

For Android, you need to include a compatible LLM model in your app. The plugin uses MediaPipe's tasks-genai, which supports various model formats.

When Gemini mini will be out of close alpha we might add it as default like we do Apple inteligence default
https://developer.android.com/ai/gemini-nano/experimental

**Important:** Your app's `minSdkVersion` must be set to 24 or higher. Update your `android/variables.gradle` file:
```gradle
ext {
    minSdkVersion = 24
    // ... other settings
}
```

1. **Download a compatible model**: 
   
   **For Android: Gemma 3 Models** (Working ✅)
   - **Recommended**: Gemma 3 270M - Smallest, most efficient (~240-400MB)
   - Text-only model optimized for on-device inference
   - Download from [Kaggle](https://www.kaggle.com/models/google/gemma) → "LiteRT (formerly TFLite)" tab
   - Get both `.task` and `.litertlm` files
   
   **For iOS: Limited Options** (⚠️)
   - **Option 1** (Recommended): Use Apple Intelligence - no download needed
   - **Option 2** (Experimental): Try Gemma-2 2B from [Hugging Face](https://huggingface.co/collections/google/mediapipe-668392ead2d6768e82fb3b87)
     - Download `Gemma2-2B-IT_*.task` files  
     - May still encounter compatibility errors
   
   **Available Model Sizes** (from [Google AI](https://ai.google.dev/gemma/docs/core#sizes)):
   - `gemma-3-270m` - Most portable, text-only (~240-400MB) - Android only
   - `gemma-3-1b` - Larger text-only (~892MB-1.5GB) - Android only
   - `gemma-2-2b` - Cross-platform compatible (~1-2GB) - iOS experimental
   - Larger models available but not recommended for mobile
   
   For automated download, see the script in the example app section below.

2. **Add the model to your app**:
   
   **Option A - Bundle in APK (for smaller models)**:
   - Place the model files in your app's `android/app/src/main/assets/` directory
   - The `/android_asset/` prefix is used to reference files from the assets folder
   - Note: This approach may increase APK size significantly
   
   **Option B - Download at runtime (recommended for production)**:
   - Host the model files on a server
   - Download them to your app's files directory at runtime
   - This keeps your APK size small

3. **Set the model path**:

```typescript
import { CapgoLLM } from '@capgo/capacitor-llm';

// If model is in assets folder (recommended) - point to the .task file
await CapgoLLM.setModelPath({ path: '/android_asset/gemma-3-270m-it-int8.task' });

// If model is in app's files directory
await CapgoLLM.setModelPath({ path: '/data/data/com.yourapp/files/gemma-3-270m-it-int8.task' });

// Example: Download model at runtime (recommended for production)
async function downloadModel() {
  // Add progress listener
  await CapgoLLM.addListener('downloadProgress', (event) => {
    console.log(`Download progress: ${event.progress}%`);
  });

  // Download the model
  const result = await CapgoLLM.downloadModel({
    url: 'https://your-server.com/models/gemma-3-270m-it-int8.task',
    companionUrl: 'https://your-server.com/models/gemma-3-270m-it-int8.litertlm', // Android only
    filename: 'gemma-3-270m-it-int8.task' // Optional, defaults to filename from URL
  });

  console.log('Model downloaded to:', result.path);
  if (result.companionPath) {
    console.log('Companion file downloaded to:', result.companionPath);
  }

  // Now set the model path
  await CapgoLLM.setModelPath({ path: result.path });
}

// Now you can create chats and send messages
const chat = await CapgoLLM.createChat();
```

## Usage Example

```typescript
import { CapgoLLM } from '@capgo/capacitor-llm';

// Check if LLM is ready
const { readiness } = await CapgoLLM.getReadiness();
console.log('LLM readiness:', readiness);

// Set a custom model (optional - uses system default if not called)
// iOS: Use a GGUF model from bundle or path
// Android: Use a MediaPipe model from assets or files
await CapgoLLM.setModelPath({ 
  path: Platform.isIOS ? 'gemma-3-270m.gguf' : '/android_asset/gemma-3-270m-it-int8.task' 
});

// Create a chat session
const { id: chatId } = await CapgoLLM.createChat();

// Listen for AI responses
CapgoLLM.addListener('textFromAi', (event) => {
  console.log('AI:', event.text);
});

// Listen for completion
CapgoLLM.addListener('aiFinished', (event) => {
  console.log('AI finished responding to chat:', event.chatId);
});

// Send a message
await CapgoLLM.sendMessage({
  chatId,
  message: 'Hello! How are you today?'
});
```

## API

<docgen-index>

* [`createChat()`](#createchat)
* [`sendMessage(...)`](#sendmessage)
* [`getReadiness()`](#getreadiness)
* [`setModel(...)`](#setmodel)
* [`downloadModel(...)`](#downloadmodel)
* [`addListener('textFromAi', ...)`](#addlistenertextfromai-)
* [`addListener('aiFinished', ...)`](#addlisteneraifinished-)
* [`addListener('downloadProgress', ...)`](#addlistenerdownloadprogress-)
* [`addListener('readinessChange', ...)`](#addlistenerreadinesschange-)
* [`getPluginVersion()`](#getpluginversion)
* [Interfaces](#interfaces)

</docgen-index>

<docgen-api>
<!--Update the source file JSDoc comments and rerun docgen to update the docs below-->

LLM Plugin interface for interacting with on-device language models

### createChat()

```typescript
createChat() => Promise<{ id: string; instructions?: string; }>
```

Creates a new chat session

**Returns:** <code>Promise&lt;{ id: string; instructions?: string; }&gt;</code>

--------------------


### sendMessage(...)

```typescript
sendMessage(options: { chatId: string; message: string; }) => Promise<void>
```

Sends a message to the AI in a specific chat session

| Param         | Type                                              | Description                       |
| ------------- | ------------------------------------------------- | --------------------------------- |
| **`options`** | <code>{ chatId: string; message: string; }</code> | - The chat id and message to send |

--------------------


### getReadiness()

```typescript
getReadiness() => Promise<{ readiness: string; }>
```

Gets the readiness status of the LLM

**Returns:** <code>Promise&lt;{ readiness: string; }&gt;</code>

--------------------


### setModel(...)

```typescript
setModel(options: ModelOptions) => Promise<void>
```

Sets the model configuration
- iOS: Use "Apple Intelligence" as path for system model, or provide path to MediaPipe model
- Android: Path to a MediaPipe model file (in assets or files directory)

| Param         | Type                                                  | Description               |
| ------------- | ----------------------------------------------------- | ------------------------- |
| **`options`** | <code><a href="#modeloptions">ModelOptions</a></code> | - The model configuration |

--------------------


### downloadModel(...)

```typescript
downloadModel(options: DownloadModelOptions) => Promise<DownloadModelResult>
```

Downloads a model from a URL and saves it to the appropriate location
- iOS: Downloads to the app's documents directory
- Android: Downloads to the app's files directory

| Param         | Type                                                                  | Description                  |
| ------------- | --------------------------------------------------------------------- | ---------------------------- |
| **`options`** | <code><a href="#downloadmodeloptions">DownloadModelOptions</a></code> | - The download configuration |

**Returns:** <code>Promise&lt;<a href="#downloadmodelresult">DownloadModelResult</a>&gt;</code>

--------------------


### addListener('textFromAi', ...)

```typescript
addListener(eventName: 'textFromAi', listenerFunc: (event: TextFromAiEvent) => void) => Promise<{ remove: () => Promise<void>; }>
```

Adds a listener for text received from AI

| Param              | Type                                                                            | Description                         |
| ------------------ | ------------------------------------------------------------------------------- | ----------------------------------- |
| **`eventName`**    | <code>'textFromAi'</code>                                                       | - Event name 'textFromAi'           |
| **`listenerFunc`** | <code>(event: <a href="#textfromaievent">TextFromAiEvent</a>) =&gt; void</code> | - Callback function for text events |

**Returns:** <code>Promise&lt;{ remove: () =&gt; Promise&lt;void&gt;; }&gt;</code>

--------------------


### addListener('aiFinished', ...)

```typescript
addListener(eventName: 'aiFinished', listenerFunc: (event: AiFinishedEvent) => void) => Promise<{ remove: () => Promise<void>; }>
```

Adds a listener for AI completion events

| Param              | Type                                                                            | Description                           |
| ------------------ | ------------------------------------------------------------------------------- | ------------------------------------- |
| **`eventName`**    | <code>'aiFinished'</code>                                                       | - Event name 'aiFinished'             |
| **`listenerFunc`** | <code>(event: <a href="#aifinishedevent">AiFinishedEvent</a>) =&gt; void</code> | - Callback function for finish events |

**Returns:** <code>Promise&lt;{ remove: () =&gt; Promise&lt;void&gt;; }&gt;</code>

--------------------


### addListener('downloadProgress', ...)

```typescript
addListener(eventName: 'downloadProgress', listenerFunc: (event: DownloadProgressEvent) => void) => Promise<{ remove: () => Promise<void>; }>
```

Adds a listener for model download progress events

| Param              | Type                                                                                        | Description                             |
| ------------------ | ------------------------------------------------------------------------------------------- | --------------------------------------- |
| **`eventName`**    | <code>'downloadProgress'</code>                                                             | - Event name 'downloadProgress'         |
| **`listenerFunc`** | <code>(event: <a href="#downloadprogressevent">DownloadProgressEvent</a>) =&gt; void</code> | - Callback function for progress events |

**Returns:** <code>Promise&lt;{ remove: () =&gt; Promise&lt;void&gt;; }&gt;</code>

--------------------


### addListener('readinessChange', ...)

```typescript
addListener(eventName: 'readinessChange', listenerFunc: (event: ReadinessChangeEvent) => void) => Promise<{ remove: () => Promise<void>; }>
```

Adds a listener for readiness status changes

| Param              | Type                                                                                      | Description                              |
| ------------------ | ----------------------------------------------------------------------------------------- | ---------------------------------------- |
| **`eventName`**    | <code>'readinessChange'</code>                                                            | - Event name 'readinessChange'           |
| **`listenerFunc`** | <code>(event: <a href="#readinesschangeevent">ReadinessChangeEvent</a>) =&gt; void</code> | - Callback function for readiness events |

**Returns:** <code>Promise&lt;{ remove: () =&gt; Promise&lt;void&gt;; }&gt;</code>

--------------------


### getPluginVersion()

```typescript
getPluginVersion() => Promise<{ version: string; }>
```

Get the native Capacitor plugin version.

**Returns:** <code>Promise&lt;{ version: string; }&gt;</code>

**Since:** 1.0.0

--------------------


### Interfaces


#### ModelOptions

Model configuration options

| Prop              | Type                | Description                                                                                                |
| ----------------- | ------------------- | ---------------------------------------------------------------------------------------------------------- |
| **`path`**        | <code>string</code> | Model path or "Apple Intelligence" for iOS system model                                                    |
| **`modelType`**   | <code>string</code> | Model file type/extension (e.g., "task", "bin", "litertlm"). If not provided, will be extracted from path. |
| **`maxTokens`**   | <code>number</code> | Maximum number of tokens the model handles                                                                 |
| **`topk`**        | <code>number</code> | Number of tokens the model considers at each step                                                          |
| **`temperature`** | <code>number</code> | Amount of randomness in generation (0.0-1.0)                                                               |
| **`randomSeed`**  | <code>number</code> | Random seed for generation                                                                                 |


#### DownloadModelResult

Result of model download

| Prop                | Type                | Description                                             |
| ------------------- | ------------------- | ------------------------------------------------------- |
| **`path`**          | <code>string</code> | Path where the model was saved                          |
| **`companionPath`** | <code>string</code> | Path where the companion file was saved (if applicable) |


#### DownloadModelOptions

Options for downloading a model

| Prop               | Type                | Description                                                   |
| ------------------ | ------------------- | ------------------------------------------------------------- |
| **`url`**          | <code>string</code> | URL of the model file to download                             |
| **`companionUrl`** | <code>string</code> | Optional: URL of companion file (e.g., .litertlm for Android) |
| **`filename`**     | <code>string</code> | Optional: Custom filename (defaults to filename from URL)     |


#### TextFromAiEvent

Event data for text received from AI

| Prop          | Type                 | Description                                                                |
| ------------- | -------------------- | -------------------------------------------------------------------------- |
| **`text`**    | <code>string</code>  | The text content from AI - this is an incremental chunk, not the full text |
| **`chatId`**  | <code>string</code>  | The chat session ID                                                        |
| **`isChunk`** | <code>boolean</code> | Whether this is a complete chunk (true) or partial streaming data (false)  |


#### AiFinishedEvent

Event data for AI completion

| Prop         | Type                | Description                       |
| ------------ | ------------------- | --------------------------------- |
| **`chatId`** | <code>string</code> | The chat session ID that finished |


#### DownloadProgressEvent

Event data for download progress

| Prop                  | Type                | Description                              |
| --------------------- | ------------------- | ---------------------------------------- |
| **`progress`**        | <code>number</code> | Percentage of download completed (0-100) |
| **`totalBytes`**      | <code>number</code> | Total bytes to download                  |
| **`downloadedBytes`** | <code>number</code> | Bytes downloaded so far                  |


#### ReadinessChangeEvent

Event data for readiness status changes

| Prop            | Type                | Description          |
| --------------- | ------------------- | -------------------- |
| **`readiness`** | <code>string</code> | The readiness status |

</docgen-api>

## Example App Model Setup

The example app demonstrates how to use custom models with the Capacitor LLM plugin.

### Downloading Models

Since AI models require license acceptance, you need to download them manually:

### Model Setup by Platform

#### Android Setup (Gemma 3 270M) ✅

1. **Create Kaggle account and accept license:**
   - Create a [Kaggle account](https://www.kaggle.com)
   - Visit [Gemma 3 models](https://www.kaggle.com/models/google/gemma-3) and accept terms

2. **Download the model:**
   - Click "LiteRT (formerly TFLite)" tab
   - Download `gemma-3-270m-it-int8` (get BOTH files):
     - `gemma-3-270m-it-int8.task`
     - `gemma-3-270m-it-int8.litertlm`

3. **Place in Android app:**
   - Copy BOTH files to: `example-app/android/app/src/main/assets/`
   - In code, reference with `/android_asset/` prefix

#### iOS Setup ⚠️

**Option 1 (Recommended)**: Use Apple Intelligence
- No model download needed
- Works out of the box on iOS 26.0+

**Option 2 (Experimental)**: Try Gemma-2 2B
1. Visit [Hugging Face MediaPipe models](https://huggingface.co/collections/google/mediapipe-668392ead2d6768e82fb3b87)
2. Download Gemma-2 2B files (e.g., `Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280.task`)
3. Add to Xcode project in "Copy Bundle Resources"
4. Note: May still encounter errors - Apple Intelligence is more reliable
### Update your code to use the model:
```typescript
// Android - Gemma 3 270M
await CapgoLLM.setModel({ 
  path: '/android_asset/gemma-3-270m-it-int8.task',
  maxTokens: 2048,
  topk: 40,
  temperature: 0.8
});

// iOS Option 1 - Apple Intelligence (Recommended)
await CapgoLLM.setModel({ 
  path: 'Apple Intelligence' 
});

// iOS Option 2 - Gemma-2 2B (Experimental)
await CapgoLLM.setModel({ 
  path: 'Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280',
  modelType: 'task',
  maxTokens: 1280,
  topk: 40,
  temperature: 0.8
});
```

### Model Selection Guide

**For Android**: Gemma 3 270M is recommended because:
- Smallest size (~240-400MB)
- Text-only (perfect for chat)
- Optimized for mobile devices
- Works reliably with MediaPipe

**For iOS**: Apple Intelligence is recommended because:
- No download required
- Native iOS integration
- Better performance
- No compatibility issues

## Known Issues

- **iOS MediaPipe Compatibility**: MediaPipe iOS SDK has issues with `.task` format models
  - Symptom: `(prefill_input_names.size() % 2)==(0)` errors
  - Solution: Use Apple Intelligence (built-in) instead of custom models
  - Alternative: Try Gemma-2 2B models (experimental, may still fail)

- **Platform Requirements**:
  - iOS: Apple Intelligence requires iOS 26.0+
  - Android: Minimum SDK 24

- **Performance Considerations**:
  - Model files are large (300MB-2GB)
  - Initial download takes time
  - Some devices may have memory limitations
