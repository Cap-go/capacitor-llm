# @capgo/capacitor-llm

<a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_llm"> ➡️ Get Instant updates for your App with Capgo 🚀</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_llm"> Fix your annoying bug now, Hire a Capacitor expert 💪</a></h2>
</div>

Adds support for LLM locally run for Capacitor

It uses Apple Intelligence for the iOS system model, MediaPipe for existing `.task` models, and ExecuTorch `.pte` models on both iOS and Android.

**Mac Catalyst:** Native iOS functionality is disabled for Mac Catalyst builds. MediaPipe pods are skipped and native calls will return an unsupported response; use an iOS/iPadOS target for native features.

## Documentation

The most complete doc is available here: https://capgo.app/docs/plugins/llm/

## Compatibility

| Plugin version | Capacitor compatibility | Maintained |
| -------------- | ----------------------- | ---------- |
| v8.\*.\*       | v8.\*.\*                | ✅          |
| v7.\*.\*       | v7.\*.\*                | On demand   |
| v6.\*.\*       | v6.\*.\*                | ❌          |
| v5.\*.\*       | v5.\*.\*                | ❌          |

> **Note:** The major version of this plugin follows the major version of Capacitor. Use the version that matches your Capacitor installation (e.g., plugin v8 for Capacitor 8). Only the latest major version is actively maintained.

## Installation

```bash
bun add @capgo/capacitor-llm
bunx cap sync
```

### iOS Additional Setup for Custom Models

Apple Intelligence works without bundled model files on supported iOS versions. For custom models, the plugin supports MediaPipe through CocoaPods and ExecuTorch through Swift Package Manager.

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
The main Swift package stays compatible with iOS 15. To use ExecuTorch `.pte` models on iOS, add the ExecuTorch Swift package to your app target and link `executorch_llm`, `backend_xnnpack`, `kernels_llm`, `kernels_optimized`, `kernels_quantized`, and `kernels_torchao`. ExecuTorch currently requires iOS 17 or newer in the app target that links it. MediaPipe GenAI still does not officially support SPM, so use CocoaPods for MediaPipe `.task` models.

## Adding a Model to Your App

The simplest cross-platform custom model path is ExecuTorch. It uses the same kind of `.pte` model file on iOS and Android, plus a tokenizer file.

### ExecuTorch Models (iOS and Android)

iOS uses ExecuTorch when the app target links the ExecuTorch SwiftPM products. Android uses the ExecuTorch Maven package.

Bundle the model files:

- iOS: add the `.pte` model and tokenizer file to your app target's Copy Bundle Resources.
- Android: place the `.pte` model and tokenizer file under `android/app/src/main/assets/`, then reference them with `/android_asset/...`.

```typescript
import { Capacitor } from '@capacitor/core';
import { CapgoLLM } from '@capgo/capacitor-llm';

const isAndroid = Capacitor.getPlatform() === 'android';

await CapgoLLM.setModel({
  engine: 'executorch',
  path: isAndroid ? '/android_asset/model.pte' : 'model.pte',
  tokenizerPath: isAndroid ? '/android_asset/tokenizer.model' : 'tokenizer.model',
  maxTokens: 2048,
  sequenceLength: 2048,
  temperature: 0.8,
});

const { id: chatId } = await CapgoLLM.createChat();
```

`engine: 'auto'` also selects ExecuTorch when the model path ends in `.pte` or when `tokenizerPath` is provided. Passing `engine: 'executorch'` is recommended when loading ExecuTorch models so failures are explicit.

### MediaPipe Models

MediaPipe remains available for existing `.task` models. Android models usually need both `.task` and `.litertlm` files. iOS MediaPipe support is available through CocoaPods and remains experimental for some `.task` files.

```typescript
await CapgoLLM.setModel({
  path: '/android_asset/gemma-3-270m-it-int8.task',
  modelType: 'task',
  maxTokens: 2048,
  topk: 40,
  temperature: 0.8,
});
```

### Apple Intelligence

On supported iOS devices, Apple Intelligence can be used without bundling a model.

```typescript
await CapgoLLM.setModel({
  path: 'Apple Intelligence',
  engine: 'apple',
});
```

### Downloading Models at Runtime

Use `downloadModel` to keep large model files out of the app bundle. For ExecuTorch, `companionUrl` can point at the tokenizer file.

```typescript
const result = await CapgoLLM.downloadModel({
  url: 'https://your-server.com/models/model.pte',
  companionUrl: 'https://your-server.com/models/tokenizer.model',
  filename: 'model.pte',
});

await CapgoLLM.setModel({
  engine: 'executorch',
  path: result.path,
  tokenizerPath: result.companionPath,
  sequenceLength: 2048,
});
```

## Usage Example

```typescript
import { CapgoLLM } from '@capgo/capacitor-llm';

const { readiness } = await CapgoLLM.getReadiness();
console.log('LLM readiness:', readiness);

const { id: chatId } = await CapgoLLM.createChat();

CapgoLLM.addListener('textFromAi', (event) => {
  console.log('AI:', event.text);
});

CapgoLLM.addListener('aiFinished', (event) => {
  console.log('AI finished responding to chat:', event.chatId);
});

await CapgoLLM.sendMessage({
  chatId,
  message: 'Hello! How are you today?',
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
- iOS: Use "Apple Intelligence" as path for system model, provide a MediaPipe model, or set engine to "executorch"
- Android: Path to a MediaPipe or ExecuTorch model file (in assets or files directory)

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

| Prop                 | Type                                                          | Description                                                                                                                                                                                                                                                                                                                       |
| -------------------- | ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **`path`**           | <code>string</code>                                           | Model path or "Apple Intelligence" for iOS system model                                                                                                                                                                                                                                                                           |
| **`engine`**         | <code>'auto' \| 'apple' \| 'mediapipe' \| 'executorch'</code> | Runtime engine to use. - "auto": uses Apple Intelligence on iOS when path is "Apple Intelligence", ExecuTorch for `.pte` or tokenizerPath, otherwise MediaPipe - "apple": iOS Foundation Models / Apple Intelligence - "mediapipe": MediaPipe GenAI `.task` models - "executorch": ExecuTorch `.pte` models with a tokenizer file |
| **`modelType`**      | <code>string</code>                                           | Model file type/extension (e.g., "task", "bin", "litertlm"). If not provided, will be extracted from path.                                                                                                                                                                                                                        |
| **`tokenizerPath`**  | <code>string</code>                                           | Tokenizer path for ExecuTorch models. Required when engine is "executorch".                                                                                                                                                                                                                                                       |
| **`specialTokens`**  | <code>string[]</code>                                         | Optional special tokens passed to ExecuTorch tokenizers when supported.                                                                                                                                                                                                                                                           |
| **`maxTokens`**      | <code>number</code>                                           | Maximum number of tokens the model handles                                                                                                                                                                                                                                                                                        |
| **`sequenceLength`** | <code>number</code>                                           | Sequence length for ExecuTorch generation. Defaults to maxTokens when omitted.                                                                                                                                                                                                                                                    |
| **`topk`**           | <code>number</code>                                           | Number of tokens the model considers at each step                                                                                                                                                                                                                                                                                 |
| **`temperature`**    | <code>number</code>                                           | Amount of randomness in generation (0.0-1.0)                                                                                                                                                                                                                                                                                      |
| **`randomSeed`**     | <code>number</code>                                           | Random seed for generation                                                                                                                                                                                                                                                                                                        |


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

The example app can use either the older MediaPipe assets or the new ExecuTorch assets.

### Recommended Custom Path: ExecuTorch

1. Export or download an ExecuTorch `.pte` model and matching tokenizer file.
2. Add both files to the iOS app bundle, or place both files in `example-app/android/app/src/main/assets/` for Android.
3. Call `setModel` with `engine: 'executorch'`, `path`, and `tokenizerPath`.

### Legacy MediaPipe Path

Android still supports Gemma 3 LiteRT assets from Kaggle. Download both files and place them in `example-app/android/app/src/main/assets/`:

- `gemma-3-270m-it-int8.task`
- `gemma-3-270m-it-int8.litertlm`

iOS MediaPipe remains experimental because some `.task` models can fail during prefill. Apple Intelligence or ExecuTorch is preferred on iOS.

## Known Issues

- ExecuTorch is native-only and is not available on web.
- iOS ExecuTorch requires linking the ExecuTorch SwiftPM products in the app target, and that app target must support iOS 17 or newer.
- Apple Intelligence requires iOS 26.0 or later and a supported device.
- Android requires minSdkVersion 24 or higher.
- Model files are large, so production apps should usually download them after install.
