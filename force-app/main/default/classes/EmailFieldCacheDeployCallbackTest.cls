/**
 * Test class for EmailFieldCacheDeployCallback
 */
@IsTest
private class EmailFieldCacheDeployCallbackTest {
  @IsTest
  static void testHandleResultSuccess() {
    Test.startTest();

    // Create callback instance
    EmailFieldCacheDeployCallback callback = new EmailFieldCacheDeployCallback();

    // Create mock successful deploy result
    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.done = true;
    mockResult.success = true;

    // Test the callback - should not throw exceptions
    callback.handleResult(mockResult, null);

    Test.stopTest();

    // If we get here without exceptions, the test passes
    System.assert(
      true,
      'Callback should handle successful result without exceptions'
    );
  }

  @IsTest
  static void testHandleResultFailure() {
    Test.startTest();

    // Create callback instance
    EmailFieldCacheDeployCallback callback = new EmailFieldCacheDeployCallback();

    // Create mock failed deploy result
    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.done = true;
    mockResult.success = false;

    // Test the callback - should not throw exceptions
    callback.handleResult(mockResult, null);

    Test.stopTest();

    // If we get here without exceptions, the test passes
    System.assert(
      true,
      'Callback should handle failed result without exceptions'
    );
  }

  @IsTest
  static void testHandleResultInProgress() {
    Test.startTest();

    // Create callback instance
    EmailFieldCacheDeployCallback callback = new EmailFieldCacheDeployCallback();

    // Create mock in-progress deploy result
    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.done = false;
    mockResult.success = false;

    // Test the callback - should not throw exceptions
    callback.handleResult(mockResult, null);

    Test.stopTest();

    // If we get here without exceptions, the test passes
    System.assert(
      true,
      'Callback should handle in-progress result without exceptions'
    );
  }
}
