import { WebPlugin } from '@capacitor/core';
import { FilesetResolver, LlmInference } from '@mediapipe/tasks-genai';

import type {
  LLMPlugin,
  DownloadModelOptions,
  DownloadModelResult,
  ModelOptions,
  TextFromAiEvent,
  AiFinishedEvent,
  GenerationErrorEvent,
  DownloadProgressEvent,
  ReadinessChangeEvent,
} from './definitions';

interface ChatTurn {
  role: 'user' | 'model';
  content: string;
}

interface ChatSession {
  id: string;
  llm: LlmInference;
  isActive: boolean;
  modelPath: string;
  modelType: string;
  history: ChatTurn[];
}

export class CapgoLLMWeb extends WebPlugin implements LLMPlugin {
  private llm: LlmInference | null = null;
  private chatSessions: Map<string, ChatSession> = new Map();
  private readiness = 'not-loaded';
  private modelPath = '';
  private modelType = 'task';

  async getReadiness(): Promise<{ readiness: string }> {
    return { readiness: this.readiness };
  }

  async createChat(): Promise<{ id: string; instructions?: string }> {
    if (!this.llm) {
      throw new Error('Model not loaded. Call setModel first.');
    }

    const chatId = `chat_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;

    this.chatSessions.set(chatId, {
      id: chatId,
      llm: this.llm,
      isActive: true,
      modelPath: this.modelPath,
      modelType: this.modelType,
      history: [],
    });

    return { id: chatId };
  }

  async sendMessage(options: { chatId: string; message: string }): Promise<void> {
    const session = this.chatSessions.get(options.chatId);
    if (!session) {
      throw new Error(`Chat session ${options.chatId} not found`);
    }

    if (!session.isActive) {
      throw new Error(`Chat session ${options.chatId} is not active`);
    }

    let hasStreamed = false;
    let responseText = '';

    try {
      const prompt = this.buildPrompt(session, options.message);

      const finalResponse = await session.llm.generateResponse(prompt, (partialResponse, done) => {
        if (done || !partialResponse) {
          return;
        }

        hasStreamed = true;
        responseText += partialResponse;

        this.notifyListeners('textFromAi', {
          text: partialResponse,
          chatId: options.chatId,
          isChunk: true,
        } as TextFromAiEvent);
      });

      if (!hasStreamed && finalResponse) {
        responseText = finalResponse;
        this.notifyListeners('textFromAi', {
          text: finalResponse,
          chatId: options.chatId,
          isChunk: true,
        } as TextFromAiEvent);
      }

      session.history.push(
        { role: 'user', content: options.message },
        { role: 'model', content: responseText || finalResponse },
      );

      // Notify completion
      this.notifyListeners('aiFinished', {
        chatId: options.chatId,
      } as AiFinishedEvent);
    } catch (error) {
      console.error('Error generating response:', error);
      const message = error instanceof Error ? error.message : String(error);
      if (hasStreamed) {
        this.notifyListeners('generationError', {
          chatId: options.chatId,
          error: message,
        } as GenerationErrorEvent);
        return;
      }

      throw error;
    }
  }

  async setModel(options: ModelOptions): Promise<void> {
    try {
      this.closeCurrentModel();

      // Update readiness
      this.readiness = 'loading';
      this.notifyListeners('readinessChange', { readiness: this.readiness } as ReadinessChangeEvent);

      // Create LLM configuration
      const config: any = {
        baseOptions: {
          modelAssetPath: options.path,
        },
        maxTokens: options.maxTokens || 2048,
        topK: options.topk || 40,
        temperature: options.temperature || 0.8,
        randomSeed: options.randomSeed || 0,
      };

      const genai = await FilesetResolver.forGenAiTasks(
        'https://cdn.jsdelivr.net/npm/@mediapipe/tasks-genai@latest/wasm',
      );
      // Create LLM instance
      this.llm = await LlmInference.createFromOptions(genai, config);
      this.modelPath = options.path;
      this.modelType = this.resolveModelType(options);
      this.chatSessions.clear();

      // Update readiness
      this.readiness = 'ready';
      this.notifyListeners('readinessChange', { readiness: this.readiness } as ReadinessChangeEvent);
    } catch (error) {
      this.closeCurrentModel();
      this.readiness = 'error';
      this.notifyListeners('readinessChange', { readiness: this.readiness } as ReadinessChangeEvent);
      throw error;
    }
  }

  async downloadModel(options: DownloadModelOptions): Promise<DownloadModelResult> {
    try {
      // For web, we'll simulate download by fetching and storing in IndexedDB or returning the URL
      const response = await fetch(options.url, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/octet-stream',
        },
      });

      if (!response.ok) {
        throw new Error(`Failed to download model: ${response.statusText}`);
      }

      const contentLength = response.headers.get('content-length');
      const totalBytes = contentLength ? parseInt(contentLength, 10) : undefined;

      // Read the response with progress
      const reader = response.body?.getReader();
      if (!reader) {
        throw new Error('Failed to get reader from response');
      }

      const chunks: Uint8Array[] = [];
      let downloadedBytes = 0;

      while (true) {
        const { done, value } = await reader.read();

        if (done) break;

        if (value) {
          chunks.push(value);
          downloadedBytes += value.length;
        }

        // Notify progress
        const progress = totalBytes ? (downloadedBytes / totalBytes) * 100 : 0;
        this.notifyListeners('downloadProgress', {
          progress,
          totalBytes,
          downloadedBytes,
        } as DownloadProgressEvent);
      }

      // For web, we'll return the original URL as the path
      // In a real implementation, you might want to store this in IndexedDB
      const result: DownloadModelResult = {
        path: options.url,
      };

      // Handle companion file if provided
      if (options.companionUrl) {
        // For web, just return the companion URL
        result.companionPath = options.companionUrl;
      }

      return result;
    } catch (error) {
      console.error('Error downloading model:', error);
      throw error;
    }
  }

  async getPluginVersion(): Promise<{ version: string }> {
    return { version: 'web' };
  }

  private closeCurrentModel(): void {
    this.chatSessions.clear();
    this.llm?.close();
    this.llm = null;
    this.modelPath = '';
    this.modelType = 'task';
  }

  private resolveModelType(options: ModelOptions): string {
    if (options.modelType?.trim()) {
      return options.modelType.trim().toLowerCase();
    }

    const extension = options.path.split('.').pop();
    return extension ? extension.toLowerCase() : 'task';
  }

  private buildPrompt(session: ChatSession, message: string): string {
    if (!this.usesGemmaChatTemplate(session)) {
      return message;
    }

    const history = [...session.history, { role: 'user' as const, content: message }];
    return `${history
      .map((turn) => `<start_of_turn>${turn.role}\n${turn.content}<end_of_turn>`)
      .join('\n')}\n<start_of_turn>model\n`;
  }

  private usesGemmaChatTemplate(session: ChatSession): boolean {
    return /gemma/i.test(session.modelPath) || session.modelType === 'litertlm';
  }
}
