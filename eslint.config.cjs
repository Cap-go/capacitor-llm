const ionic = require('@ionic/eslint-config/recommended');

module.exports = [
  {
    ignores: [
      'build/**',
      'dist/**',
      'example-app/**',
      'docs/**',
      'node_modules/**',
      'eslint.config.cjs',
    ],
  },
  ...ionic,
];
