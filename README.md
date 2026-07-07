# @capgo/capacitor-llm

<a href="https://capgo.app/"><img src='https://raw.githubusercontent.com/Cap-go/capgo/main/assets/capgo_banner.png' alt='Capgo - Instant updates for capacitor'/></a>

<div align="center">
  <h2><a href="https://capgo.app/?ref=plugin_llm"> ➡️ Get Instant updates for your App with Capgo 🚀</a></h2>
  <h2><a href="https://capgo.app/consulting/?ref=plugin_llm"> Fix your annoying bug now, Hire a Capacitor expert 💪</a></h2>
</div>

On-device LLM support for Capacitor.

Current platform strategy:

- iOS: Apple Intelligence by default, plus LiteRT-LM `.litertlm` custom models in SwiftPM integrations when the path ends in `.litertlm` or `modelType: 'litertlm'` is passed
- Android: Gemini Nano system model on supported devices where it is already available, LiteRT-LM for `.litertlm` bundles, and a compatibility fallback for legacy MediaPipe `.task` models
- Web: Gemma 4 web models through `@mediapipe/tasks-genai`

## Documentation

The most complete plugin docs are available at [capgo.app/docs/plugins/llm](https://capgo.app/docs/plugins/llm/).

## Compatibility

| Plugin version | Capacitor compatibility | Maintained |
| -------------- | ----------------------- | ---------- |
| v8.*.*         | v8.*.*                  | ✅         |
| v7.*.*         | v7.*.*                  | On demand  |
| v6.*.*         | v6.*.*                  | ❌         |
| v5.*.*         | v5.*.*                  | ❌         |

> **Note:** The plugin major version follows the Capacitor major version. Use the version that matches your Capacitor installation.

## Installation

```bash
npm install @capgo/capacitor-llm
npx cap sync
```

If you use the web implementation, also install the MediaPipe peer dependency:

```bash
npm install @mediapipe/tasks-genai
```

## Model Setup

### iOS

Recommended path:

- Use Apple Intelligence with `path: 'Apple Intelligence'`
- Requires iOS 26.0+

Custom iOS LiteRT-LM path:

- Available only when the plugin is integrated into the iOS app through Swift Package Manager
- Uses the official LiteRT-LM Swift API and prebuilt iOS xcframework for `.litertlm` models
- Selected only when the path ends in `.litertlm` or `modelType: 'litertlm'` is passed
- CocoaPods builds keep Apple Intelligence and the legacy MediaPipe `.task` compatibility path
- Other custom iOS model types keep the legacy MediaPipe compatibility path for backward compatibility

Example:

```ts
import { CapgoLLM } from '@capgo/capacitor-llm';

await CapgoLLM.setModel({ path: 'Apple Intelligence' });
const chat = await CapgoLLM.createChat();
```

### Android

Recommended path:

- Use Gemini Nano with `path: 'Gemini Nano'` when the Android device already has it available through AICore
- Use LiteRT-LM `.litertlm` bundles
- Gemma 4 E2B and E4B are good default examples
- Models are available from the public [`litert-community`](https://huggingface.co/litert-community) Hugging Face repos

Gemini Nano system model example:

```ts
await CapgoLLM.setModel({ path: 'Gemini Nano' });
const chat = await CapgoLLM.createChat();
```

Quickstart with a downloaded Gemma 4 model:

```ts
import { CapgoLLM } from '@capgo/capacitor-llm';

const result = await CapgoLLM.downloadModel({
  url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true',
  filename: 'gemma-4-E2B-it.litertlm',
});

await CapgoLLM.setModel({
  path: result.path,
  modelType: 'litertlm',
  maxTokens: 4096,
  topk: 40,
  temperature: 0.8,
});

const chat = await CapgoLLM.createChat();
```

Bundled asset example:

```ts
await CapgoLLM.setModel({
  path: '/android_asset/gemma-4-E2B-it.litertlm',
  modelType: 'litertlm',
  maxTokens: 4096,
});
```

Legacy compatibility:

- Existing Android `.task` models still load through the compatibility path
- New integrations should prefer `.litertlm`

### Web

The web implementation uses `@mediapipe/tasks-genai` with web-ready model artifacts.

Gemma 4 web models are published next to the mobile LiteRT-LM bundles and use `*-web.task`.

Example:

```ts
await CapgoLLM.setModel({
  path: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it-web.task?download=true',
  modelType: 'task',
  maxTokens: 4096,
});
```

## Usage

```ts
import { CapgoLLM } from '@capgo/capacitor-llm';

const { readiness } = await CapgoLLM.getReadiness();
console.log('LLM readiness:', readiness);

const { id } = await CapgoLLM.createChat();

await CapgoLLM.addListener('textFromAi', (event) => {
  console.log('chunk', event.text);
});

await CapgoLLM.addListener('aiFinished', ({ chatId }) => {
  console.log('finished', chatId);
});

await CapgoLLM.sendMessage({
  chatId: id,
  message: 'Explain why local inference is useful on mobile.',
});
```
## Notes

- Android now prefers LiteRT-LM and Gemma 4 style `.litertlm` bundles.
- iOS LiteRT-LM custom-model support now uses the official LiteRT-LM Swift API and prebuilt iOS binaries, is available only in SwiftPM integrations of this plugin, and is selected only for explicit `.litertlm` models.
- CocoaPods builds on iOS should use Apple Intelligence or the legacy MediaPipe `.task` compatibility path.
- Web uses Gemma 4 `*-web.task` artifacts through `@mediapipe/tasks-genai`.
- Apple Intelligence remains the preferred default on iOS where available.

<docgen-index>

* [`createChat()`](#createchat)
* [`sendMessage(...)`](#sendmessage)
* [`getReadiness()`](#getreadiness)
* [`setModel(...)`](#setmodel)
* [`downloadModel(...)`](#downloadmodel)
* [`addListener('textFromAi', ...)`](#addlistenertextfromai-)
* [`addListener('aiFinished', ...)`](#addlisteneraifinished-)
* [`addListener('generationError', ...)`](#addlistenergenerationerror-)
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
- iOS: Use "Apple Intelligence" as path for the system model. Custom LiteRT-LM `.litertlm` models are supported on iOS only when this plugin is integrated through Swift Package Manager, and are selected only when `modelType: 'litertlm'` is passed or the path ends in `.litertlm`.
- Android: Use "Gemini Nano" for the AICore system model on supported devices where it is already available. Prefer LiteRT-LM `.litertlm` bundles for custom models; legacy MediaPipe `.task` models are still supported
- Web: Provide a web-ready model asset for `@mediapipe/tasks-genai` such as Gemma 4 `*-web.task`

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


### addListener('generationError', ...)

```typescript
addListener(eventName: 'generationError', listenerFunc: (event: GenerationErrorEvent) => void) => Promise<{ remove: () => Promise<void>; }>
```

Adds a listener for generation failures that happen after streaming starts

| Param              | Type                                                                                      | Description                               |
| ------------------ | ----------------------------------------------------------------------------------------- | ----------------------------------------- |
| **`eventName`**    | <code>'generationError'</code>                                                            | - Event name 'generationError'            |
| **`listenerFunc`** | <code>(event: <a href="#generationerrorevent">GenerationErrorEvent</a>) =&gt; void</code> | - Callback function for generation errors |

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
Only `path` is required. All other properties are optional overrides.

| Prop              | Type                        | Description                                                                                                                                                                                                                                                                                                                             | Since |
| ----------------- | --------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----- |
| **`path`**        | <code>string</code>         | Model path, "Apple Intelligence" for the Apple system model on iOS, or "Gemini Nano" for the Android AICore system model when already available on the device. On iOS, custom `.litertlm` models require the plugin to be integrated through Swift Package Manager. Gemma 4 examples use `.litertlm` on mobile and `*-web.task` on web. |       |
| **`modelType`**   | <code>string</code>         | Optional. Model file type/extension (for example `task`, `bin`, `litertlm`, or `gemini-nano`). If not provided, it is extracted from the path. On iOS, LiteRT-LM is selected only when this resolves to `litertlm`; all other custom types keep the legacy MediaPipe compatibility path.                                                |       |
| **`maxTokens`**   | <code>number</code>         | Maximum number of tokens the model handles                                                                                                                                                                                                                                                                                              |       |
| **`topk`**        | <code>number</code>         | Number of tokens the model considers at each step                                                                                                                                                                                                                                                                                       |       |
| **`temperature`** | <code>number</code>         | Amount of randomness in generation (0.0-1.0)                                                                                                                                                                                                                                                                                            |       |
| **`randomSeed`**  | <code>number</code>         | Optional. Random seed for generation.                                                                                                                                                                                                                                                                                                   |       |
| **`backend`**     | <code>'gpu' \| 'cpu'</code> | Optional. LiteRT-LM engine backend for iOS (SwiftPM) and Android. Use `cpu` for stable long generations. When omitted, iOS prefers CPU then falls back to GPU; Android uses CPU.                                                                                                                                                        | 8.2.0 |


#### DownloadModelResult

Result of model download

| Prop                | Type                | Description                                             |
| ------------------- | ------------------- | ------------------------------------------------------- |
| **`path`**          | <code>string</code> | Path where the model was saved                          |
| **`companionPath`** | <code>string</code> | Path where the companion file was saved (if applicable) |


#### DownloadModelOptions

Options for downloading a model
Only `url` is required. `companionUrl` and `filename` are optional.

| Prop               | Type                | Description                                                |
| ------------------ | ------------------- | ---------------------------------------------------------- |
| **`url`**          | <code>string</code> | URL of the model file to download                          |
| **`companionUrl`** | <code>string</code> | Optional: URL of a companion file for legacy model formats |
| **`filename`**     | <code>string</code> | Optional: Custom filename (defaults to filename from URL)  |


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


#### GenerationErrorEvent

Event data for generation failures
`chatId` is optional and may be omitted when the failure is not tied to a specific chat.

| Prop         | Type                | Description                                                |
| ------------ | ------------------- | ---------------------------------------------------------- |
| **`chatId`** | <code>string</code> | Optional. The chat session ID that failed, when available. |
| **`error`**  | <code>string</code> | Error message describing the failure                       |


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

## Example App

The repo includes an `example-app/` that demonstrates:

- Apple Intelligence on iOS
- Gemma 4 LiteRT-LM model downloads on Android

See [example-app/README.md](./example-app/README.md) for local setup instructions.
