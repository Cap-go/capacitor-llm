import type { CapacitorConfig } from '@capacitor/cli';
import pkg from './package.json';

const config: CapacitorConfig = {
  appId: 'app.capgo.llm',
  appName: 'LLM Example',
  webDir: 'dist',
  android: {
    adjustMarginsForEdgeToEdge: 'auto'
  }
  plugins: {
    CapacitorUpdater: {
      appId: 'app.capgo.llm',
      autoUpdate: true,
      autoSplashscreen: true,
      directUpdate: 'always',
      defaultChannel: 'production',
      version: pkg.version,
    },
  },
};

export default config;
