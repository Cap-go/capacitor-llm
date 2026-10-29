#!/usr/bin/env node

/**
 * Capacitor hook: configure optional ML Kit genai-agent dependency for Android.
 */

import fs from 'node:fs';
import path from 'node:path';

const PLUGIN_ROOT = process.cwd();
const CONFIG_JSON = process.env.CAPACITOR_CONFIG;
const PLATFORM = process.env.CAPACITOR_PLATFORM_NAME;
const gradlePropertiesPath = path.join(PLUGIN_ROOT, 'android', 'gradle.properties');

const defaults = {
  include: false,
  dependencyType: 'implementation',
};

function readConfig() {
  if (!CONFIG_JSON) {
    return defaults;
  }

  try {
    const config = JSON.parse(CONFIG_JSON);
    const pluginConfig = config?.plugins?.CapgoLLM?.android?.genaiAgent ?? {};
    const include = pluginConfig.include === true || pluginConfig.include === 'true';
    const dependencyType =
      typeof pluginConfig.dependencyType === 'string' &&
      pluginConfig.dependencyType.trim().length > 0
        ? pluginConfig.dependencyType.trim()
        : defaults.dependencyType;

    return { include, dependencyType };
  } catch {
    return defaults;
  }
}

function updateGradleProperties({ include, dependencyType }) {
  let existing = '';
  if (fs.existsSync(gradlePropertiesPath)) {
    existing = fs.readFileSync(gradlePropertiesPath, 'utf8');
  }

  const filtered = existing
    .split('\n')
    .filter((line) => {
      const trimmed = line.trim();
      return (
        trimmed.length === 0 ||
        (!trimmed.startsWith('capacitorLLM.genaiAgent.') &&
          trimmed !== '# Capgo LLM optional Android dependencies (auto-generated hook)')
      );
    })
    .join('\n')
    .replace(/\n+$/, '');

  const generated = [
    '',
    '# Capgo LLM optional Android dependencies (auto-generated hook)',
    `capacitorLLM.genaiAgent.include=${include}`,
    `capacitorLLM.genaiAgent.dependencyType=${dependencyType}`,
    '',
  ].join('\n');

  fs.writeFileSync(gradlePropertiesPath, `${filtered}${generated}`, 'utf8');
}

function main() {
  if (PLATFORM && PLATFORM !== 'android') {
    return;
  }

  const settings = readConfig();
  updateGradleProperties(settings);
}

main();
