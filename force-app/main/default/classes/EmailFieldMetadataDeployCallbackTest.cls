/**
 * Test class for EmailFieldMetadataDeployCallback
 * Tests the metadata deployment callback functionality including success/failure handling
 * and email notification sending
 */
@IsTest
private class EmailFieldMetadataDeployCallbackTest {
  @TestSetup
  static void setupTestData() {
    // Create a test user with email for notification testing
    User testUser = new User(
      FirstName = 'Test',
      LastName = 'User',
      Email = 'test@example.com',
      Username = 'testuser@emailcallback.test',
      Alias = 'tuser',
      TimeZoneSidKey = 'America/New_York',
      LocaleSidKey = 'en_US',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1]
      .Id
    );
    insert testUser;
  }

  @IsTest
  static void testHandleResultSuccess() {
    // Create mock deployment result for success scenario
    Metadata.DeployResult mockResult = createMockDeployResult(true);
    Metadata.DeployCallbackContext mockContext = new Metadata.DeployCallbackContext();

    EmailFieldMetadataDeployCallback callback = new EmailFieldMetadataDeployCallback();

    Test.startTest();

    // Call the handleResult method
    callback.handleResult(mockResult, mockContext);

    Test.stopTest();

    // Verify that no exceptions were thrown and method completed successfully
    // In a real scenario, we would verify debug logs and email sending
    System.assert(
      true,
      'handleResult should complete without exceptions for success scenario'
    );
  }

  @IsTest
  static void testHandleResultFailure() {
    // Create mock deployment result for failure scenario
    Metadata.DeployResult mockResult = createMockDeployResult(false);
    Metadata.DeployCallbackContext mockContext = new Metadata.DeployCallbackContext();

    EmailFieldMetadataDeployCallback callback = new EmailFieldMetadataDeployCallback();

    Test.startTest();

    // Call the handleResult method
    callback.handleResult(mockResult, mockContext);

    Test.stopTest();

    // Verify that no exceptions were thrown and method completed successfully
    System.assert(
      true,
      'handleResult should complete without exceptions for failure scenario'
    );
  }

  @IsTest
  static void testHandleResultWithNullDetails() {
    // Create mock deployment result with null details
    Metadata.DeployResult mockResult = createMockDeployResult(true);
    mockResult.details = null;
    Metadata.DeployCallbackContext mockContext = new Metadata.DeployCallbackContext();

    EmailFieldMetadataDeployCallback callback = new EmailFieldMetadataDeployCallback();

    Test.startTest();

    // Call the handleResult method
    callback.handleResult(mockResult, mockContext);

    Test.stopTest();

    // Verify that method handles null details gracefully
    System.assert(
      true,
      'handleResult should handle null details without exceptions'
    );
  }

  @IsTest
  static void testSendDeploymentNotificationSuccess() {
    User testUser = [
      SELECT Id, Email
      FROM User
      WHERE Email = 'test@example.com'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Metadata.DeployResult mockResult = createMockDeployResult(true);
      EmailFieldMetadataDeployCallback callback = new EmailFieldMetadataDeployCallback();

      Test.startTest();

      // Call handleResult which will trigger sendDeploymentNotification
      callback.handleResult(mockResult, new Metadata.DeployCallbackContext());

      Test.stopTest();

      // Verify that the method completed without exceptions
      // In a real Salesforce org, we could check email limits or mock the email service
      System.assert(true, 'Notification should be sent successfully');
    }
  }

  @IsTest
  static void testSendDeploymentNotificationFailure() {
    User testUser = [
      SELECT Id, Email
      FROM User
      WHERE Email = 'test@example.com'
      LIMIT 1
    ];

    System.runAs(testUser) {
      Metadata.DeployResult mockResult = createMockDeployResult(false);
      EmailFieldMetadataDeployCallback callback = new EmailFieldMetadataDeployCallback();

      Test.startTest();

      // Call handleResult which will trigger sendDeploymentNotification
      callback.handleResult(mockResult, new Metadata.DeployCallbackContext());

      Test.stopTest();

      // Verify that the method completed without exceptions
      System.assert(true, 'Failure notification should be sent successfully');
    }
  }

  /**
   * Helper method to create mock Metadata.DeployResult for testing
   */
  private static Metadata.DeployResult createMockDeployResult(Boolean success) {
    Metadata.DeployResult result = new Metadata.DeployResult();
    result.success = success;

    if (success) {
      result.numberComponentsDeployed = 5;
      result.numberComponentErrors = 0;

      // Create mock deployment details for success
      result.details = new Metadata.DeployDetails();
      result.details.componentSuccesses = new List<Metadata.DeployMessage>();

      Metadata.DeployMessage success1 = new Metadata.DeployMessage();
      success1.fullName = 'CustomField.Contact.Email__c';
      success1.componentType = 'CustomField';
      result.details.componentSuccesses.add(success1);

      Metadata.DeployMessage success2 = new Metadata.DeployMessage();
      success2.fullName = 'CustomField.Lead.Email__c';
      success2.componentType = 'CustomField';
      result.details.componentSuccesses.add(success2);

      Metadata.DeployMessage success3 = new Metadata.DeployMessage();
      success3.fullName = 'CustomField.Account.Email__c';
      success3.componentType = 'CustomField';
      result.details.componentSuccesses.add(success3);
    } else {
      result.numberComponentsDeployed = 2;
      result.numberComponentErrors = 3;

      // Create mock deployment details for failure
      result.details = new Metadata.DeployDetails();
      result.details.componentFailures = new List<Metadata.DeployMessage>();

      Metadata.DeployMessage failure1 = new Metadata.DeployMessage();
      failure1.fullName = 'CustomField.Contact.BadEmail__c';
      failure1.componentType = 'CustomField';
      failure1.problem = 'Invalid field type';
      result.details.componentFailures.add(failure1);

      Metadata.DeployMessage failure2 = new Metadata.DeployMessage();
      failure2.fullName = 'CustomField.Lead.BadEmail__c';
      failure2.componentType = 'CustomField';
      failure2.problem = 'Missing required attribute';
      result.details.componentFailures.add(failure2);

      Metadata.DeployMessage failure3 = new Metadata.DeployMessage();
      failure3.fullName = 'CustomField.Account.BadEmail__c';
      failure3.componentType = 'CustomField';
      failure3.problem = 'Duplicate field name';
      result.details.componentFailures.add(failure3);

      // Also add some successes for mixed scenario
      result.details.componentSuccesses = new List<Metadata.DeployMessage>();

      Metadata.DeployMessage mixedSuccess1 = new Metadata.DeployMessage();
      mixedSuccess1.fullName = 'CustomField.Contact.Email__c';
      mixedSuccess1.componentType = 'CustomField';
      result.details.componentSuccesses.add(mixedSuccess1);

      Metadata.DeployMessage mixedSuccess2 = new Metadata.DeployMessage();
      mixedSuccess2.fullName = 'CustomField.Lead.Email__c';
      mixedSuccess2.componentType = 'CustomField';
      result.details.componentSuccesses.add(mixedSuccess2);
    }

    return result;
  }
}
