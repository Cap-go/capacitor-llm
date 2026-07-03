import type { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'app.capgo.llm',
  appName: '@capgo/capacitor-llm',
  webDir: 'dist',
  android: {
    adjustMarginsForEdgeToEdge: 'auto'
  }
};

export default config;
