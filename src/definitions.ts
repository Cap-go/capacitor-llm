/**
 * LLM Plugin interface for interacting with on-device language models
 */
export interface LLMPlugin {
  /**
   * Creates a new chat session
   * @returns Promise with chat id and optional instructions
   */
  createChat(): Promise<{ id: string; instructions?: string }>;

  /**
   * Sends a message to the AI in a specific chat session
   * @param options - The chat id and message to send
   * @returns Promise that resolves when message is sent
   */
  sendMessage(options: { chatId: string; message: string }): Promise<void>;

  /**
   * Gets the readiness status of the LLM
   * @returns Promise with readiness status string
   */
  getReadiness(): Promise<{ readiness: string }>;

  /**
   * Sets the model configuration
   * - iOS: Use "Apple Intelligence" as path for the system model, or provide a downloaded custom model bundle such as Gemma 4 `.litertlm`
   * - Android: Prefer LiteRT-LM `.litertlm` bundles; legacy MediaPipe `.task` models are still supported
   * - Web: Provide a web-ready model asset for `@mediapipe/tasks-genai` such as Gemma 4 `*-web.task`
   * @param options - The model configuration
   * @returns Promise that resolves when model is loaded
   */
  setModel(options: ModelOptions): Promise<void>;

  /**
   * Downloads a model from a URL and saves it to the appropriate location
   * - iOS: Downloads to the app's documents directory
   * - Android: Downloads to the app's files directory
   * @param options - The download configuration
   * @returns Promise with download result including the saved path
   */
  downloadModel(options: DownloadModelOptions): Promise<DownloadModelResult>;

  /**
   * Adds a listener for text received from AI
   * @param eventName - Event name 'textFromAi'
   * @param listenerFunc - Callback function for text events
   * @returns Promise with remove function to unsubscribe
   */
  addListener(
    eventName: 'textFromAi',
    listenerFunc: (event: TextFromAiEvent) => void,
  ): Promise<{ remove: () => Promise<void> }>;

  /**
   * Adds a listener for AI completion events
   * @param eventName - Event name 'aiFinished'
   * @param listenerFunc - Callback function for finish events
   * @returns Promise with remove function to unsubscribe
   */
  addListener(
    eventName: 'aiFinished',
    listenerFunc: (event: AiFinishedEvent) => void,
  ): Promise<{ remove: () => Promise<void> }>;

  /**
   * Adds a listener for generation failures that happen after streaming starts
   * @param eventName - Event name 'generationError'
   * @param listenerFunc - Callback function for generation errors
   * @returns Promise with remove function to unsubscribe
   */
  addListener(
    eventName: 'generationError',
    listenerFunc: (event: GenerationErrorEvent) => void,
  ): Promise<{ remove: () => Promise<void> }>;

  /**
   * Adds a listener for model download progress events
   * @param eventName - Event name 'downloadProgress'
   * @param listenerFunc - Callback function for progress events
   * @returns Promise with remove function to unsubscribe
   */
  addListener(
    eventName: 'downloadProgress',
    listenerFunc: (event: DownloadProgressEvent) => void,
  ): Promise<{ remove: () => Promise<void> }>;

  /**
   * Adds a listener for readiness status changes
   * @param eventName - Event name 'readinessChange'
   * @param listenerFunc - Callback function for readiness events
   * @returns Promise with remove function to unsubscribe
   */
  addListener(
    eventName: 'readinessChange',
    listenerFunc: (event: ReadinessChangeEvent) => void,
  ): Promise<{ remove: () => Promise<void> }>;

  /**
   * Get the native Capacitor plugin version.
   *
   * @returns Promise that resolves with the plugin version
   * @throws Error if getting the version fails
   * @since 1.0.0
   * @example
   * ```typescript
   * const { version } = await CapgoLLM.getPluginVersion();
   * console.log('Plugin version:', version);
   * ```
   */
  getPluginVersion(): Promise<{ version: string }>;
}

/**
 * Event data for text received from AI
 */
export interface TextFromAiEvent {
  /** The text content from AI - this is an incremental chunk, not the full text */
  text: string;
  /** The chat session ID */
  chatId: string;
  /** Whether this is a complete chunk (true) or partial streaming data (false) */
  isChunk?: boolean;
}

/**
 * Event data for AI completion
 */
export interface AiFinishedEvent {
  /** The chat session ID that finished */
  chatId: string;
}

/**
 * Event data for generation failures
 * `chatId` is optional and may be omitted when the failure is not tied to a specific chat.
 */
export interface GenerationErrorEvent {
  /** Optional. The chat session ID that failed, when available. */
  chatId?: string;
  /** Error message describing the failure */
  error: string;
}

/**
 * Options for downloading a model
 * Only `url` is required. `companionUrl` and `filename` are optional.
 */
export interface DownloadModelOptions {
  /** URL of the model file to download */
  url: string;
  /** Optional: URL of a companion file for legacy model formats */
  companionUrl?: string;
  /** Optional: Custom filename (defaults to filename from URL) */
  filename?: string;
}

/**
 * Result of model download
 */
export interface DownloadModelResult {
  /** Path where the model was saved */
  path: string;
  /** Path where the companion file was saved (if applicable) */
  companionPath?: string;
}

/**
 * Event data for download progress
 */
export interface DownloadProgressEvent {
  /** Percentage of download completed (0-100) */
  progress: number;
  /** Total bytes to download */
  totalBytes?: number;
  /** Bytes downloaded so far */
  downloadedBytes?: number;
}

/**
 * Event data for readiness status changes
 */
export interface ReadinessChangeEvent {
  /** The readiness status */
  readiness: string;
}

/**
 * Model configuration options
 * Only `path` is required. All other properties are optional overrides.
 */
export interface ModelOptions {
  /** Model path or "Apple Intelligence" for the Apple system model on iOS. Gemma 4 examples use `.litertlm` on mobile and `*-web.task` on web. */
  path: string;
  /** Optional. Model file type/extension (for example `task`, `bin`, or `litertlm`). If not provided, it is extracted from the path. */
  modelType?: string;
  /** Maximum number of tokens the model handles */
  maxTokens?: number;
  /** Number of tokens the model considers at each step */
  topk?: number;
  /** Amount of randomness in generation (0.0-1.0) */
  temperature?: number;
  /** Optional. Random seed for generation. */
  randomSeed?: number;
}
