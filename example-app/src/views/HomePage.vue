<template>
  <ion-page>
    <ion-header :translucent="true">
      <ion-toolbar>
        <ion-title>LLM Chatbot</ion-title>
        <div slot="end" class="toolbar-end">
          <!-- Model Selector Button -->
          <ion-button fill="clear" @click="showModelSelector = true">
            <ion-icon slot="start" :icon="settingsOutline"></ion-icon>
            Model
          </ion-button>
          <!-- Readiness Status -->
          <ion-chip :color="getReadinessColor()" outline>
            <ion-label>{{ readinessStatus }}</ion-label>
          </ion-chip>
        </div>
      </ion-toolbar>
    </ion-header>

    <ion-content :fullscreen="true" class="chat-content" ref="contentRef">
      <ion-refresher slot="fixed" @ionRefresh="refresh($event)">
        <ion-refresher-content></ion-refresher-content>
      </ion-refresher>

      <ion-header collapse="condense">
        <ion-toolbar>
          <ion-title size="large">Apple AI Chatbot</ion-title>
        </ion-toolbar>
      </ion-header>

      <ion-list>
        <!-- Dynamic messages -->
        <ion-item 
          v-for="message in messages" 
          :key="message.id" 
          :class="['message-item', message.isUser ? 'user-message' : 'ai-message']"
          v-show="message.isUser || message.text || !isThinking"
        >
          <div :class="['message-container', message.isUser ? 'user' : 'ai']">
            <!-- AI Avatar (only for AI messages) -->
            <div v-if="!message.isUser" class="ai-avatar">
              <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24">
                <path fill="currentColor" d="M9.376 22.08c-.32 0-.64-.07-.95-.21c-.73-.33-1.21-1-1.3-1.79l-.28-2.64l-2.62-.68c-.81-.21-1.41-.81-1.61-1.6s.04-1.6.64-2.16l1.93-1.8l-1.06-2.33c-.33-.73-.25-1.56.22-2.21c.49-.67 1.27-1.01 2.1-.91l2.79.33l1.32-2.36c.39-.7 1.1-1.13 1.9-1.15c.79-.04 1.54.36 1.97 1.03l1.48 2.32l2.74-.49c.81-.15 1.61.14 2.14.77c.52.62.66 1.44.37 2.19l-.93 2.43l2.01 1.66c.63.52.92 1.31.77 2.11s-.73 1.45-1.51 1.71l-2.6.83l-.11 2.6c-.04.8-.48 1.49-1.19 1.87c-.72.38-1.56.35-2.26-.07l-2.4-1.48l-2.28 1.6c-.39.27-.84.41-1.3.41zm-.97-4.23l.22 2.08c.04.37.31.53.43.58c.25.11.54.09.77-.07l1.75-1.23l-.59-.37c-.63-.38-1.3-.67-2.01-.86l-.55-.14zm5.88 1.28l1.85 1.14c.24.14.52.15.77.02c.11-.06.37-.24.39-.61l.08-2.05l-.73.23c-.7.23-1.36.55-1.96.97l-.41.28zm-6.05-2.88l1.1.28c.86.22 1.67.57 2.43 1.03l1.14.71l.94-.66c.72-.5 1.51-.9 2.36-1.17l1.25-.4l.04-.97c.04-.91.23-1.81.55-2.66l.42-1.1l-.8-.67c-.7-.58-1.3-1.26-1.78-2.01l-.68-1.06l-1.15.2c-.86.16-1.74.18-2.62.08l-1.36-.16l-.5.91c-.44.78-.99 1.5-1.65 2.11l-.91.85l.92 2.03c.03.07.05.15.06.23l.26 2.42zm-2.39-3.6l-1.55 1.45c-.28.26-.24.57-.21.7c.03.12.15.42.53.52l2.07.54l-.18-1.74l-.66-1.46zm13.83-.33l-.24.62c-.26.71-.42 1.45-.45 2.2l-.02.42l2.08-.67a.717.717 0 0 0 .25-1.24l-1.62-1.34zM6.186 7.24a.74.74 0 0 0-.61.31c-.07.1-.22.37-.07.7l.85 1.87l.54-.5c.54-.51 1-1.10 1.37-1.75l.21-.37l-2.18-.26zm10.61.06l.34.53c.4.62.89 1.18 1.47 1.66l.41.34l.75-1.95a.7.7 0 0 0-.12-.7a.74.74 0 0 0-.72-.26l-2.12.38zm-5.94-1.01l.75.09c.73.09 1.46.07 2.18-.06l.54-.1l-1.15-1.79c-.21-.32-.51-.34-.67-.34c-.13 0-.45.05-.64.38l-1.02 1.82z"/>
              </svg>
            </div>
            <!-- Message bubble -->
            <div :class="['message-bubble', message.isUser ? 'user-bubble' : 'ai-bubble']">
              <ion-label>
                <div class="message-content" v-html="message.text"></div>
                <span v-if="!message.isUser && !isTypingComplete(message)" class="typing-cursor">|</span>
              </ion-label>
            </div>
          </div>
        </ion-item>
        
        <!-- Thinking Indicator -->
        <ion-item v-if="isThinking" class="message-item ai-message">
          <div class="message-container ai">
            <div class="ai-avatar">
              <svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 24 24">
                <path fill="currentColor" d="M9.376 22.08c-.32 0-.64-.07-.95-.21c-.73-.33-1.21-1-1.3-1.79l-.28-2.64l-2.62-.68c-.81-.21-1.41-.81-1.61-1.6s.04-1.6.64-2.16l1.93-1.8l-1.06-2.33c-.33-.73-.25-1.56.22-2.21c.49-.67 1.27-1.01 2.1-.91l2.79.33l1.32-2.36c.39-.7 1.1-1.13 1.9-1.15c.79-.04 1.54.36 1.97 1.03l1.48 2.32l2.74-.49c.81-.15 1.61.14 2.14.77c.52.62.66 1.44.37 2.19l-.93 2.43l2.01 1.66c.63.52.92 1.31.77 2.11s-.73 1.45-1.51 1.71l-2.6.83l-.11 2.6c-.04.8-.48 1.49-1.19 1.87c-.72.38-1.56.35-2.26-.07l-2.4-1.48l-2.28 1.6c-.39.27-.84.41-1.3.41zm-.97-4.23l.22 2.08c.04.37.31.53.43.58c.25.11.54.09.77-.07l1.75-1.23l-.59-.37c-.63-.38-1.3-.67-2.01-.86l-.55-.14zm5.88 1.28l1.85 1.14c.24.14.52.15.77.02c.11-.06.37-.24.39-.61l.08-2.05l-.73.23c-.7.23-1.36.55-1.96.97l-.41.28zm-6.05-2.88l1.1.28c.86.22 1.67.57 2.43 1.03l1.14.71l.94-.66c.72-.5 1.51-.9 2.36-1.17l1.25-.4l.04-.97c.04-.91.23-1.81.55-2.66l.42-1.1l-.8-.67c-.7-.58-1.3-1.26-1.78-2.01l-.68-1.06l-1.15.2c-.86.16-1.74.18-2.62.08l-1.36-.16l-.5.91c-.44.78-.99 1.5-1.65 2.11l-.91.85l.92 2.03c.03.07.05.15.06.23l.26 2.42zm-2.39-3.6l-1.55 1.45c-.28.26-.24.57-.21.7c.03.12.15.42.53.52l2.07.54l-.18-1.74l-.66-1.46zm13.83-.33l-.24.62c-.26.71-.42 1.45-.45 2.2l-.02.42l2.08-.67a.717.717 0 0 0 .25-1.24l-1.62-1.34zM6.186 7.24a.74.74 0 0 0-.61.31c-.07.1-.22.37-.07.7l.85 1.87l.54-.5c.54-.51 1-1.10 1.37-1.75l.21-.37l-2.18-.26zm10.61.06l.34.53c.4.62.89 1.18 1.47 1.66l.41.34l.75-1.95a.7.7 0 0 0-.12-.7a.74.74 0 0 0-.72-.26l-2.12.38zm-5.94-1.01l.75.09c.73.09 1.46.07 2.18-.06l.54-.1l-1.15-1.79c-.21-.32-.51-.34-.67-.34c-.13 0-.45.05-.64.38l-1.02 1.82z"/>
              </svg>
            </div>
            <div class="message-bubble ai-bubble thinking-bubble">
              <div class="thinking-dots">
                <span></span>
                <span></span>
                <span></span>
              </div>
              <ion-label class="thinking-text">Thinking...</ion-label>
            </div>
          </div>
        </ion-item>
      </ion-list>
    </ion-content>

    <!-- Message input area as footer -->
    <ion-footer>
      <ion-toolbar>
        <ion-item class="message-input-item">
          <ion-input
            v-model="newMessage"
            :placeholder="inputPlaceholder"
            class="message-input"
            @keyup.enter="sendMessage"
          ></ion-input>
          <ion-button
            slot="end"
            fill="solid"
            shape="round"
            @click="sendMessage"
            :disabled="!canSendMessage"
            class="send-button"
          >
            <ion-icon :icon="sendIcon" />
          </ion-button>
        </ion-item>
      </ion-toolbar>
    </ion-footer>
    
    <!-- Model Selection Modal -->
    <ion-modal :is-open="showModelSelector" @didDismiss="showModelSelector = false">
      <ion-header>
        <ion-toolbar>
          <ion-title>Select Model</ion-title>
          <ion-buttons slot="end">
            <ion-button @click="showModelSelector = false">Close</ion-button>
          </ion-buttons>
        </ion-toolbar>
      </ion-header>
      <ion-content>
        <ion-list>
          <ion-item v-for="model in availableModels" :key="model.id" @click="selectModel(model)">
            <ion-label>
              <h2>{{ model.name }}</h2>
              <p v-if="model.needsDownload && !model.downloadedPath" class="status-download">
                <ion-icon :icon="cloudDownloadOutline" class="status-icon"></ion-icon>
                Requires download
              </p>
              <p v-else-if="model.downloadedPath" class="status-downloaded">
                <ion-icon :icon="checkmarkDoneOutline" class="status-icon"></ion-icon>
                Downloaded
              </p>
              <p v-else class="status-ready">
                <ion-icon :icon="checkmarkOutline" class="status-icon"></ion-icon>
                Ready to use
              </p>
              <p v-if="model.note" class="model-note">{{ model.note }}</p>
            </ion-label>
            <ion-icon 
              v-if="selectedModel === model.id" 
              slot="end" 
              :icon="checkmarkCircle" 
              color="primary"
            ></ion-icon>
            <ion-button 
              v-else-if="model.needsDownload && !model.downloadedPath" 
              slot="end" 
              fill="outline"
              @click.stop="downloadModel(model)"
            >
              Download
            </ion-button>
          </ion-item>
        </ion-list>
        
        <!-- Download Progress -->
        <ion-item v-if="isDownloading">
          <ion-label>
            <h2>Downloading model...</h2>
            <ion-progress-bar :value="downloadProgress / 100"></ion-progress-bar>
            <p>{{ Math.round(downloadProgress) }}%</p>
          </ion-label>
        </ion-item>
      </ion-content>
    </ion-modal>
  </ion-page>
</template>

<script setup lang="ts">
import {
  IonContent,
  IonHeader,
  IonList,
  IonPage,
  IonRefresher,
  IonRefresherContent,
  IonTitle,
  IonToolbar,
  IonItem,
  IonLabel,
  IonInput,
  IonButton,
  IonIcon,
  IonFooter,
  IonChip,
  IonModal,
  IonButtons,
  IonProgressBar,
} from '@ionic/vue';
import { send, settingsOutline, checkmarkCircle, cloudDownloadOutline, checkmarkDoneOutline, checkmarkOutline } from 'ionicons/icons';
import { ref, nextTick, onMounted, onUnmounted, computed } from 'vue';
import type { TextFromAiEvent, AiFinishedEvent, GenerationErrorEvent } from '@capgo/capacitor-llm';
import { CapgoLLM } from '@capgo/capacitor-llm';
import { marked } from 'marked';
import { Capacitor } from '@capacitor/core';

interface Message {
  id: number;
  text: string;
  isUser: boolean;
  timestamp: Date;
  isComplete?: boolean;
}

const newMessage = ref('');
const sendIcon = send;
const contentRef = ref();
const chatId = ref<string>('');
const currentAiMessageId = ref<number | null>(null);
const readinessStatus = ref<string>('Checking...');
const isThinking = ref(false);
const downloadProgress = ref(0);
const isDownloading = ref(false);
const selectedModel = ref('apple-intelligence');
const showModelSelector = ref(false);
let listenerRemove: (() => Promise<void>) | null = null;

const messages = ref<Message[]>([]);
let messageIdCounter = 1;
const isIOS = computed(() => Capacitor.getPlatform() === 'ios');
const isAndroid = computed(() => Capacitor.getPlatform() === 'android');
const canSendMessage = computed(() => Boolean(newMessage.value.trim()) && Boolean(chatId.value) && readinessStatus.value === 'ready');
const inputPlaceholder = computed(() => {
  if (chatId.value) {
    return 'Type a message...';
  }

  if (isAndroid.value) {
    return 'Select a Gemma 4 model first...';
  }

  if (isIOS.value) {
    return 'Preparing Apple Intelligence...';
  }

  return 'Load a model first...';
});

// Model type definition
interface Model {
  id: string;
  name: string;
  needsDownload: boolean;
  url?: string;
  companionUrl?: string;
  filename?: string;
  path?: string;
  modelType?: string;
  maxTokens?: number;
  note?: string;
  downloadedPath?: string;
}

// Available models
const models: { ios: Model[], android: Model[] } = {
  ios: [
    { 
      id: 'apple-intelligence', 
      name: 'Apple Intelligence (Built-in)', 
      needsDownload: false,
      note: 'System LLM - no download needed'
    },
    {
      id: 'gemma2-2b-legacy',
      name: 'Gemma 2 2B (Legacy MediaPipe)',
      needsDownload: false,
      path: 'Gemma2-2B-IT_multi-prefill-seq_q8_ekv1280',
      modelType: 'task',
      maxTokens: 1280,
      note: 'Manual bundle setup only. Android is the Gemma 4 LiteRT showcase.'
    }
  ],
  android: [
    {
      id: 'gemma4-e2b-download',
      name: 'Gemma 4 E2B (LiteRT-LM)',
      needsDownload: true,
      url: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm?download=true',
      filename: 'gemma-4-E2B-it.litertlm',
      modelType: 'litertlm',
      maxTokens: 4096,
      note: 'Recommended Android model. Real LiteRT-LM bundle from litert-community.'
    },
    {
      id: 'gemma4-e4b-download',
      name: 'Gemma 4 E4B (LiteRT-LM)',
      needsDownload: true,
      url: 'https://huggingface.co/litert-community/gemma-4-E4B-it-litert-lm/resolve/main/gemma-4-E4B-it.litertlm?download=true',
      filename: 'gemma-4-E4B-it.litertlm',
      modelType: 'litertlm',
      maxTokens: 4096,
      note: 'Larger Gemma 4 variant for devices with more RAM.'
    }
  ]
};

const availableModels = computed(() => {
  if (isIOS.value) return models.ios;
  if (isAndroid.value) return models.android;
  return [];
});

const refresh = (ev: CustomEvent) => {
  setTimeout(() => {
    ev.detail.complete();
  }, 3000);
};

const scrollToBottom = async () => {
  await nextTick();
  if (contentRef.value) {
    contentRef.value.$el.scrollToBottom(300);
  }
};

const setConversationIntro = (text: string) => {
  messages.value = [
    {
      id: 1,
      text,
      isUser: false,
      timestamp: new Date(),
      isComplete: true,
    },
  ];
  messageIdCounter = 2;
  currentAiMessageId.value = null;
  rawMessages.clear();
  isThinking.value = false;
};

const isTypingComplete = (message: Message) => {
  return message.isComplete !== false;
};

const getReadinessColor = () => {
  switch (readinessStatus.value) {
    case 'ready':
      return 'success';
    case 'loading':
    case 'not_ready':
      return 'warning';
    case 'error':
      return 'danger';
    default:
      if (readinessStatus.value.toLowerCase().startsWith('failed')) {
        return 'danger';
      }
      return 'medium';
  }
};

const checkReadiness = async () => {
  try {
    const result = await CapgoLLM.getReadiness();
    readinessStatus.value = result.readiness;
  } catch (error) {
    console.error('Error checking readiness:', error);
    readinessStatus.value = 'error';
  }
};




// Track raw text for each message to accumulate chunks
const rawMessages = new Map<number, string>();

const handleAiResponse = async (event: TextFromAiEvent) => {
  if (event.chatId !== chatId.value) return;
  
  // Hide thinking indicator when first chunk arrives
  if (isThinking.value) {
    isThinking.value = false;
  }
  
  // Find the current AI message being streamed
  if (currentAiMessageId.value !== null) {
    const messageIndex = messages.value.findIndex(m => m.id === currentAiMessageId.value);
    if (messageIndex !== -1) {
      // Accumulate chunks
      const currentRaw = rawMessages.get(currentAiMessageId.value) || '';
      const newRaw = currentRaw + event.text;
      rawMessages.set(currentAiMessageId.value, newRaw);
      
      // Parse and update the displayed message
      messages.value[messageIndex].text = await marked.parse(newRaw);
      scrollToBottom();
    }
  }
};

const sendMessage = async () => {
  if (canSendMessage.value) {
    // Add user message
    const userMessage: Message = {
      id: messageIdCounter++,
      text: newMessage.value,
      isUser: true,
      timestamp: new Date(),
      isComplete: true
    };
    messages.value.push(userMessage);
    
    const messageText = newMessage.value;
    newMessage.value = '';
    
    // Scroll to bottom
    await scrollToBottom();
    
    // Create empty AI message for streaming response
    const aiMessage: Message = {
      id: messageIdCounter++,
      text: "",
      isUser: false,
      timestamp: new Date(),
      isComplete: false
    };
    messages.value.push(aiMessage);
    currentAiMessageId.value = aiMessage.id;
    
    // Start thinking indicator
    isThinking.value = true;
    
    await scrollToBottom();
    
    try {
      // Send message to AI
      await CapgoLLM.sendMessage({
        chatId: chatId.value,
        message: messageText
      });
    } catch (error) {
      console.error('Error sending message to AI:', error);
      // Handle error - maybe show an error message
      const messageIndex = messages.value.findIndex(m => m.id === aiMessage.id);
      if (messageIndex !== -1) {
        messages.value[messageIndex].text = "Sorry, I encountered an error. Please try again.";
        messages.value[messageIndex].isComplete = true;
      }
      currentAiMessageId.value = null;
      isThinking.value = false;
    }
  }
};

const handleAiFinished = (event: AiFinishedEvent) => {
  if (event.chatId !== chatId.value) return;
  const messageIndex = messages.value.findIndex(m => m.id === currentAiMessageId.value);
  if (messageIndex !== -1) {
    messages.value[messageIndex].isComplete = true;
    // Clean up raw message data
    if (currentAiMessageId.value !== null) {
      rawMessages.delete(currentAiMessageId.value);
    }
    currentAiMessageId.value = null;
  }
  isThinking.value = false;
};

const handleGenerationError = (event: GenerationErrorEvent) => {
  if (event.chatId && event.chatId !== chatId.value) return;

  const messageIndex = messages.value.findIndex(m => m.id === currentAiMessageId.value);
  if (messageIndex !== -1) {
    messages.value[messageIndex].text = `Sorry, I encountered an error. ${event.error}`;
    messages.value[messageIndex].isComplete = true;
  }

  if (currentAiMessageId.value !== null) {
    rawMessages.delete(currentAiMessageId.value);
  }

  currentAiMessageId.value = null;
  isThinking.value = false;
};

const downloadModel = async (model: Model) => {
  if (!model.needsDownload || !model.url) return;
  
  try {
    isDownloading.value = true;
    downloadProgress.value = 0;
    
    const result = await CapgoLLM.downloadModel({
      url: model.url,
      companionUrl: model.companionUrl,
      filename: model.filename
    });
    
    console.log('Model downloaded to:', result.path);
    
    // Update model path with downloaded path
    model.downloadedPath = result.path;
    
    // Switch to the downloaded model
    await selectModel(model);
    
  } catch (error) {
    console.error('Error downloading model:', error);
    alert(`Failed to download model: ${error}`);
  } finally {
    isDownloading.value = false;
    downloadProgress.value = 0;
  }
};

const selectModel = async (model: Model) => {
  try {
    selectedModel.value = model.id;

    chatId.value = '';
    setConversationIntro(`Preparing ${model.name}...`);

    if (model.id === 'apple-intelligence') {
      await CapgoLLM.setModel({ path: 'Apple Intelligence' });
    } else if (model.downloadedPath || !model.needsDownload) {
      await CapgoLLM.setModel({
        path: model.downloadedPath || model.path || '',
        modelType: model.modelType,
        maxTokens: model.maxTokens,
        topk: 40,
        temperature: 0.8
      });
    } else {
      // Need to download first
      await downloadModel(model);
      return;
    }
    
    // Recreate chat
    await initializeChat();
    setConversationIntro(`${model.name} is ready. Ask anything.`);
    showModelSelector.value = false;
    
  } catch (error) {
    console.error('Error selecting model:', error);
    alert(`Failed to load model: ${error}`);
  }
};

const initializeChat = async () => {
  try {
    // Create a new chat session
    const chat = await CapgoLLM.createChat();
    chatId.value = chat.id;
    console.log('LLM chat created:', chat.id);
  } catch (error) {
    console.error('Error creating chat:', error);
    throw error;
  }
};

onMounted(async () => {
  try {
    setConversationIntro('Checking model readiness...');

    // Set up readiness listener
    const readinessListener = await CapgoLLM.addListener('readinessChange', (event) => {
      readinessStatus.value = event.readiness;
      console.log('Readiness changed:', event.readiness);
    });
    
    // Check initial readiness
    await checkReadiness();
    
    // Set model path based on platform
    try {
      const platform = Capacitor.getPlatform();
      if (platform === 'ios') {
        selectedModel.value = 'apple-intelligence';
        await CapgoLLM.setModel({ path: 'Apple Intelligence' });
        await initializeChat();
        setConversationIntro('Apple Intelligence is ready. Ask anything.');
        console.log('iOS: Using Apple Intelligence (default)');
      } else if (platform === 'android') {
        selectedModel.value = 'gemma4-e2b-download';
        readinessStatus.value = 'not_ready';
        setConversationIntro('Select a Gemma 4 LiteRT-LM model from the Model menu to start chatting.');
      }
    } catch (modelError) {
      console.warn('Model setup error (using defaults):', modelError);
    }

    // Set up listener for AI responses
    const textFromAiListener = await CapgoLLM.addListener('textFromAi', handleAiResponse);
    const aiFinishedListener = await CapgoLLM.addListener('aiFinished', handleAiFinished);
    const generationErrorListener = await CapgoLLM.addListener('generationError', handleGenerationError);
    const downloadProgressListener = await CapgoLLM.addListener('downloadProgress', (event) => {
      downloadProgress.value = event.progress;
      console.log('Download progress:', event.progress);
    });
    listenerRemove = async () => {
      await textFromAiListener.remove();
      await aiFinishedListener.remove();
      await generationErrorListener.remove();
      await readinessListener.remove();
      await downloadProgressListener.remove();
    };
  } catch (error) {
    console.error('Error initializing LLM:', error);
  }
});

onUnmounted(async () => {
  // Clean up listeners when component is destroyed
  if (listenerRemove) {
    await listenerRemove();
  }
});
</script>

<style scoped>
.chat-content {
  --padding-bottom: 0px;
}

.readiness-status {
  margin-right: 8px;
}

.readiness-status ion-chip {
  font-size: 12px;
  height: 24px;
}

.message-item {
  --padding-start: 0;
  --padding-end: 0;
  --inner-padding-end: 0;
  --inner-padding-start: 0;
  --min-height: auto;
}

.message-container {
  width: 100%;
  display: flex;
  padding: 8px 16px;
  margin: 4px 0;
}

.message-container.user {
  justify-content: flex-end;
}

.message-container.ai {
  justify-content: flex-start;
  align-items: flex-start;
  gap: 12px;
}

.message-bubble {
  max-width: 80%;
  padding: 12px 16px;
  border-radius: 18px;
  word-wrap: break-word;
}

.user-bubble {
  background-color: #007AFF;
  color: white;
  border-bottom-right-radius: 4px;
}

.ai-bubble {
  background-color: #F2F2F7;
  color: #000;
  border-bottom-left-radius: 4px;
}

.ai-avatar {
  flex-shrink: 0;
  width: 32px;
  height: 32px;
  border-radius: 16px;
  background-color: #E5E5EA;
  display: flex;
  align-items: center;
  justify-content: center;
  color: #8E8E93;
  margin-top: 4px;
}

.message-content {
  font-size: 16px;
  line-height: 1.4;
  margin: 0;
}

.message-content .list-item {
  margin: 4px 0;
  font-weight: 500;
}

.message-content .list-subitem {
  margin: 2px 0 2px 16px;
  font-size: 15px;
}

.message-content strong {
  font-weight: 600;
}

.typing-cursor {
  animation: blink 1s infinite;
  color: #007AFF;
  font-weight: bold;
}

@keyframes blink {
  0%, 50% { opacity: 1; }
  51%, 100% { opacity: 0; }
}

.message-input-item {
  --padding-start: 12px;
  --padding-end: 12px;
  --inner-padding-end: 0;
  --inner-padding-start: 0;
  --background: transparent;
}

.message-input {
  font-size: 16px;
}

.send-button {
  --padding-start: 12px;
  --padding-end: 12px;
  margin-left: 8px;
  height: 36px;
  width: 36px;
}

.send-button ion-icon {
  font-size: 18px;
}

.send-button[disabled] {
  opacity: 0.4;
}

ion-footer {
  --background: var(--ion-color-light);
}

ion-footer ion-toolbar {
  --background: transparent;
  --border-width: 1px 0 0 0;
  --border-color: var(--ion-color-medium);
}

/* Dark mode support */
@media (prefers-color-scheme: dark) {
  .ai-bubble {
    background-color: #2C2C2E;
    color: #FFFFFF;
  }
  
  .user-bubble {
    background-color: #007AFF;
    color: #FFFFFF;
  }
  
  .ai-avatar {
    background-color: #48484A;
    color: #8E8E93;
  }
  
  .message-bubble ion-label,
  .message-bubble ion-label p {
    color: #FFFFFF;
  }
  
  .message-input {
    color: #FFFFFF;
  }
  
  .message-input-item {
    --color: #FFFFFF;
  }
  
  ion-footer {
    --background: var(--ion-color-dark);
  }
  
  ion-footer ion-toolbar {
    --border-color: var(--ion-color-medium-shade);
  }
}

/* Toolbar end styling */
.toolbar-end {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-right: 16px;
}

.model-toggle {
  --padding-start: 0;
  --padding-end: 0;
  --inner-padding-end: 0;
}

.model-toggle ion-label {
  margin-right: 8px;
  font-size: 14px;
}

/* Thinking bubble styles */
.thinking-bubble {
  display: flex;
  align-items: center;
  gap: 12px;
}

.thinking-dots {
  display: flex;
  gap: 4px;
}

.thinking-dots span {
  width: 8px;
  height: 8px;
  border-radius: 50%;
  background-color: #8E8E93;
  animation: thinking-bounce 1.4s infinite ease-in-out both;
}

.thinking-dots span:nth-child(1) {
  animation-delay: -0.32s;
}

.thinking-dots span:nth-child(2) {
  animation-delay: -0.16s;
}

.thinking-text {
  font-size: 14px;
  color: #8E8E93;
  font-style: italic;
}

@keyframes thinking-bounce {
  0%, 80%, 100% {
    transform: scale(0.8);
    opacity: 0.5;
  }
  40% {
    transform: scale(1.0);
    opacity: 1;
  }
}

/* Dark mode thinking styles */
@media (prefers-color-scheme: dark) {
  .thinking-dots span {
    background-color: #ABABAB;
  }
  
  .thinking-text {
    color: #ABABAB;
  }
}

/* Model note style */
.model-note {
  font-size: 12px;
  color: var(--ion-color-medium);
  font-style: italic;
  margin-top: 4px;
}

/* Status styles */
.status-icon {
  font-size: 16px;
  margin-right: 4px;
  vertical-align: middle;
}

.status-ready {
  color: var(--ion-color-success);
  display: flex;
  align-items: center;
}

.status-download {
  color: var(--ion-color-warning);
  display: flex;
  align-items: center;
}

.status-downloaded {
  color: var(--ion-color-primary);
  display: flex;
  align-items: center;
}
</style>
