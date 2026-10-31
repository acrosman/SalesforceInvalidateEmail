/**
 * Test class for InvalidateEmailFieldStatusController
 * Tests listing configured fields and counting invalidated values
 */
@isTest
private class InvalidateEmailFieldStatusControllerTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    List<Contact> contacts = InvalidateEmailTestDataFactory.createTestContacts(
      contactCount
    );

    // Invalidate 4 of the emails and blank 2 more, leaving 8 non-blank.
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    for (Integer i = 0; i < 4; i++) {
      contacts[i].Email = contacts[i].Email + invalidationText;
    }
    contacts[4].Email = null;
    contacts[5].Email = null;
    update contacts;
  }

  // Use a known field configuration so results don't depend on the
  // Email_Invalidator_Fields__mdt records in the org.
  private static void useContactEmailConfig() {
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Contact' => new Set<String>{ 'Email' }
    };
  }

  @isTest
  static void testGetConfiguredFieldsIsSorted() {
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Lead' => new Set<String>{ 'Email' },
      'Contact' => new Set<String>{ 'Email', 'AssistantEmail__c' }
    };

    Test.startTest();
    InvalidateEmailFieldStatusController.ConfiguredFieldsResponse response = InvalidateEmailFieldStatusController.getConfiguredFields();
    Test.stopTest();

    Assert.isTrue(response.success, 'Should be successful');
    Assert.areEqual(3, response.fields.size(), 'Should list every field');

    List<String> order = new List<String>();
    for (InvalidateEmailFieldStatusController.FieldRef field : response.fields) {
      order.add(field.objectName + '.' + field.fieldName);
    }
    Assert.areEqual(
      new List<String>{
        'Contact.AssistantEmail__c',
        'Contact.Email',
        'Lead.Email'
      },
      order,
      'Fields should be sorted by object then field'
    );
  }

  @isTest
  static void testFieldStatusCounts() {
    useContactEmailConfig();

    Test.startTest();
    InvalidateEmailFieldStatusController.FieldStatus status = InvalidateEmailFieldStatusController.getFieldStatus(
      'Contact',
      'Email'
    );
    Test.stopTest();

    Assert.isTrue(status.success, 'Should be successful: ' + status.message);
    Assert.areEqual('Contact', status.objectName, 'Object name is wrong');
    Assert.areEqual('Email', status.fieldName, 'Field name is wrong');
    Assert.areEqual(8, status.nonBlankCount, 'Should skip blank emails');
    Assert.areEqual(4, status.invalidatedCount, 'Invalidated count is wrong');
    Assert.areEqual(0.5, status.percentInvalidated, 'Percent is wrong');
  }

  @isTest
  static void testFieldStatusWithNoValues() {
    useContactEmailConfig();
    List<Contact> contacts = [SELECT Id FROM Contact];
    for (Contact c : contacts) {
      c.Email = null;
    }
    update contacts;

    Test.startTest();
    InvalidateEmailFieldStatusController.FieldStatus status = InvalidateEmailFieldStatusController.getFieldStatus(
      'Contact',
      'Email'
    );
    Test.stopTest();

    Assert.isTrue(status.success, 'Should be successful: ' + status.message);
    Assert.areEqual(0, status.nonBlankCount, 'Should find no values');
    Assert.areEqual(0, status.invalidatedCount, 'Should find no values');
    Assert.areEqual(0, status.percentInvalidated, 'Empty field should be 0%');
  }

  @isTest
  static void testUnconfiguredFieldIsRejected() {
    useContactEmailConfig();

    Test.startTest();
    InvalidateEmailFieldStatusController.FieldStatus wrongField = InvalidateEmailFieldStatusController.getFieldStatus(
      'Contact',
      'LastName'
    );
    InvalidateEmailFieldStatusController.FieldStatus wrongObject = InvalidateEmailFieldStatusController.getFieldStatus(
      'Lead',
      'Email'
    );
    Test.stopTest();

    Assert.isFalse(wrongField.success, 'Unconfigured field should fail');
    Assert.isFalse(wrongObject.success, 'Unconfigured object should fail');
    Assert.isNull(wrongField.nonBlankCount, 'No counts should be returned');
  }

  @isTest
  static void testOnlyTrailingInvalidationTextCounts() {
    useContactEmailConfig();
    // The invalidation text in the middle of an address isn't an invalidated value
    Contact c = [SELECT Id FROM Contact WHERE LastName = 'Contact6'];
    c.Email = 'test' + InvalidateEmailSettings.getInvalidationText() + '@example.com';
    update c;

    Test.startTest();
    InvalidateEmailFieldStatusController.FieldStatus status = InvalidateEmailFieldStatusController.getFieldStatus(
      'Contact',
      'Email'
    );
    Test.stopTest();

    Assert.isTrue(status.success, 'Should be successful: ' + status.message);
    Assert.areEqual(8, status.nonBlankCount, 'Non-blank count is wrong');
    Assert.areEqual(
      4,
      status.invalidatedCount,
      'Mid-address invalidation text should not be counted'
    );
  }

  @isTest
  static void testQueryErrorIsReported() {
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Contact' => new Set<String>{ 'NotARealField__c' }
    };

    Test.startTest();
    InvalidateEmailFieldStatusController.FieldStatus status = InvalidateEmailFieldStatusController.getFieldStatus(
      'Contact',
      'NotARealField__c'
    );
    Test.stopTest();

    Assert.isFalse(status.success, 'Bad field should fail');
    Assert.isTrue(
      status.message.startsWith('Error counting records'),
      'Message is wrong: ' + status.message
    );
    Assert.isNull(status.nonBlankCount, 'No counts should be returned');
  }

  @isTest
  static void testEscapeLikePattern() {
    Assert.areEqual(
      '.invalid',
      InvalidateEmailFieldStatusController.escapeLikePattern('.invalid'),
      'Plain text should be unchanged'
    );
    Assert.areEqual(
      '\\_x\\%y\\\\',
      InvalidateEmailFieldStatusController.escapeLikePattern('_x%y\\'),
      'Wildcards and backslashes should be escaped'
    );
  }
}
