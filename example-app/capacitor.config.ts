import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'app.capgo.llm',
  appName: 'LLM Example',
  webDir: 'dist',
  android: {
    adjustMarginsForEdgeToEdge: 'auto'
  }
};

export default config;
