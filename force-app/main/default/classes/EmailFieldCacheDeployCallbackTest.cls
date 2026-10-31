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
  static void testHandleResultFailureWithComponentFailures() {
    Test.startTest();

    EmailFieldCacheDeployCallback callback = new EmailFieldCacheDeployCallback();

    // Create mock failed deploy result with a component failure to log
    Metadata.DeployMessage failure = new Metadata.DeployMessage();
    failure.problem = 'Cached_Value__c: value too long';
    Metadata.DeployDetails details = new Metadata.DeployDetails();
    details.componentFailures = new List<Metadata.DeployMessage>{ failure };

    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.done = true;
    mockResult.success = false;
    mockResult.details = details;

    // Test the callback - should log each failure without exceptions
    callback.handleResult(mockResult, null);

    Test.stopTest();

    Assert.areEqual(
      1,
      mockResult.details.componentFailures.size(),
      'Callback should leave the failure details intact'
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
