export default {
  transform: {
    '^.+\\.(t|j)sx?$': ['babel-jest'],
  },
  collectCoverage: true,
  collectCoverageFrom: [
    'src'
  ],
  coverageReporters: ["text"],
};
