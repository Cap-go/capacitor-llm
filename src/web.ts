import { WebPlugin } from '@capacitor/core';
import { FilesetResolver, LlmInference } from '@mediapipe/tasks-genai';

import type {
  LLMPlugin,
  DownloadModelOptions,
  DownloadModelResult,
  ModelOptions,
  TextFromAiEvent,
  AiFinishedEvent,
  DownloadProgressEvent,
  ReadinessChangeEvent,
} from './definitions';

interface ChatSession {
  id: string;
  llm: any;
  isActive: boolean;
}

export class CapgoLLMWeb extends WebPlugin implements LLMPlugin {
  private llm: any = null;
  private chatSessions: Map<string, ChatSession> = new Map();
  private readiness = 'not-loaded';

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

    try {
      // Generate response using MediaPipe GenAI streaming API
      const response = session.llm.generateResponseStream(options.message);

      for await (const partialResponse of response) {
        // Send incremental text
        this.notifyListeners('textFromAi', {
          text: partialResponse,
          chatId: options.chatId,
          isChunk: true,
        } as TextFromAiEvent);
      }

      // Notify completion
      this.notifyListeners('aiFinished', {
        chatId: options.chatId,
      } as AiFinishedEvent);
    } catch (error) {
      console.error('Error generating response:', error);
      throw error;
    }
  }

  async setModel(options: ModelOptions): Promise<void> {
    const engine = options.engine ?? 'auto';
    const normalizedPath = options.path.toLowerCase();
    const wantsApple = engine === 'apple' || (engine === 'auto' && normalizedPath === 'apple intelligence');
    const wantsExecuTorch =
      engine === 'executorch' || (engine === 'auto' && (options.tokenizerPath || normalizedPath.endsWith('.pte')));

    if (wantsApple) {
      throw new Error('Apple Intelligence is only available on native iOS.');
    }

    if (wantsExecuTorch) {
      throw new Error('ExecuTorch is only available on native iOS and Android.');
    }

    try {
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

      // Update readiness
      this.readiness = 'ready';
      this.notifyListeners('readinessChange', { readiness: this.readiness } as ReadinessChangeEvent);
    } catch (error) {
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
}
