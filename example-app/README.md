# Capacitor LLM Example App

This example app shows the current recommended plugin flows:

- iOS: Apple Intelligence by default in this CocoaPods-based host app, plus the legacy bundled MediaPipe `.task` path
- Android: LiteRT-LM with Gemma 4 downloads
- Web: Gemma 4 web models through `@mediapipe/tasks-genai`

## Setup

```bash
npm install
npx cap sync
```

## iOS

The bundled example defaults to Apple Intelligence.

Requirements:

- iOS 26.0+
- Apple Intelligence enabled on the device

Important limitation:

- This example app integrates the plugin through CocoaPods.
- LiteRT-LM on iOS is supported only when the plugin is integrated through Swift Package Manager in the host app.
- Because of that, the bundled example does not expose downloadable `.litertlm` models on iOS.

Optional legacy custom-model path:

- The plugin still supports bundled MediaPipe `.task` models on iOS for CocoaPods hosts.
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

## Web

Available in the model picker:

- `Gemma 4 E2B (Web)`
- `Gemma 4 E4B (Web)`

These load the web-specific `*-web.task` artifacts from the same `litert-community` Hugging Face repos and require a WebGPU-capable browser.

## Run

```bash
npx cap run ios
npx cap run android
```

Or open the native projects:

```bash
npx cap open ios
npx cap open android
```

## Notes

- Android now prefers `.litertlm` bundles through LiteRT-LM.
- iOS LiteRT-LM requires a SwiftPM-integrated host app. This bundled example uses CocoaPods, so it demonstrates Apple Intelligence and the legacy MediaPipe `.task` path instead.
- Web uses Gemma 4 `*-web.task` artifacts through `@mediapipe/tasks-genai`.
