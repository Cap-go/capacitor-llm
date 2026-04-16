import { mount } from '@vue/test-utils';
import HomePage from '@/views/HomePage.vue';
import { describe, expect, test } from 'vitest';

describe('HomePage.vue', () => {
  test('renders home view', () => {
    const wrapper = mount(HomePage);
    expect(wrapper.text()).toContain('LLM Chatbot');
    expect(wrapper.text()).toContain('Model');
  });
});
