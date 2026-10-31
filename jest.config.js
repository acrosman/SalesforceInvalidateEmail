const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    // The default babel provider reports 0% for LWC sources with this toolchain
    coverageProvider: 'v8',
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver']
};
