/** @type {import('jest').Config} */
export default {
  testEnvironment: 'node',
  testMatch: ['**/src/__tests__/**/*.test.js'],
  moduleNameMapper: {
    '^(\\.{1,2}/.*)\\.js$': '$1',
  },
  transform: {},
  collectCoverageFrom: ['src/**/*.js', '!src/__tests__/**'],
  coverageThreshold: {
    global: {
      lines: 80,
    },
  },
};
