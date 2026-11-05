/** @type {import('jest').Config} */
export default {
  testEnvironment: 'node',
  testMatch: ['**/src/__tests__/**/*.test.js'],
  collectCoverageFrom: ['src/**/*.js', '!src/__tests__/**'],
  coverageThreshold: {
    global: {
      lines: 80,
    },
  },
};
