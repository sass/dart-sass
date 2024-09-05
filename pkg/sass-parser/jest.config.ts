const config = {
  preset: 'ts-jest',
  roots: ['lib'],
  testEnvironment: 'node',
  setupFilesAfterEnv: ['jest-extended/all', '<rootDir>/test/setup.ts'],
  verbose: false,
};

export default config;
