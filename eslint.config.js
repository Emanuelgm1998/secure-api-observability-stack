import pluginImport from 'eslint-plugin-import';

export default [
  {
    files: ['**/*.js'],
    ignores: ['node_modules/**', 'coverage/**'],
    languageOptions: {
      ecmaVersion: 2022,
      sourceType: 'module',
      globals: { jest: 'readonly' }
    },
    plugins: { import: pluginImport },
    rules: {
      'no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      'import/no-unresolved': 'off'
    }
  }
];
