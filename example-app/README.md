# Capacitor LLM Example App

This example app shows the current recommended plugin flows:

- iOS: Apple Intelligence by default
- Android: LiteRT-LM with Gemma 4 downloads

## Setup

```bash
bun install
bunx cap sync
```

## iOS

The example defaults to Apple Intelligence.

Requirements:

- iOS 26.0+
- Apple Intelligence enabled on the device

Optional legacy custom-model path:

- The plugin still supports bundled MediaPipe `.task` models on iOS.
- Add the file to the Xcode target's "Copy Bundle Resources".
- Select `Gemma 2 2B (Legacy MediaPipe)` from the in-app model picker.

## Android

The example is now centered on Gemma 4 with LiteRT-LM.

Available in the model picker:

- `Gemma 4 E2B (LiteRT-LM)`
- `Gemma 4 E4B (LiteRT-LM)`

The app downloads the models directly from the public `litert-community` Hugging Face repositories:

- [Gemma 4 E2B LiteRT-LM](https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm)
- [Gemma 4 E4B LiteRT-LM](https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm)

If you prefer to bundle a model manually, place a `.litertlm` file in your Android app assets and call:

```ts
await CapgoLLM.setModel({
  path: '/android_asset/gemma-4-E2B-it.litertlm',
  modelType: 'litertlm',
  maxTokens: 4096,
});
```

## Run

```bash
bunx cap run ios
bunx cap run android
```

Or open the native projects:

```bash
bunx cap open ios
bunx cap open android
```

## Notes

- Android now prefers `.litertlm` bundles through LiteRT-LM.
- Legacy Android `.task` models still work through the compatibility fallback in the plugin.
- Web still uses MediaPipe `.task` models and is not demonstrated by this example app.
