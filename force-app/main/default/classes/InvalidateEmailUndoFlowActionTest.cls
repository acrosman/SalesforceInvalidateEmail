/**
 * Test class for InvalidateEmailUndoFlowAction
 * Tests the invocable methods that trigger the email restoration batch
 */
@isTest
private class InvalidateEmailUndoFlowActionTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    List<Contact> testContacts = InvalidateEmailTestDataFactory.createTestContacts(
      contactCount
    );

    // Invalidate the emails first so we have something to restore
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    for (Contact contact : testContacts) {
      contact.Email = contact.Email + invalidationText;
    }
    update testContacts;
  }

  @isTest
  static void testRestoreAllConfiguredEmailsAction() {
    Test.startTest();

    List<InvalidateEmailUndoFlowAction.EmailRestorationResponse> responses = InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAction();

    Test.stopTest();

    // Verify response
    Assert.areEqual(1, responses.size(), 'Should return one response');
    InvalidateEmailUndoFlowAction.EmailRestorationResponse response = responses[0];
    Assert.areEqual(true, response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );

    // Verify that Contact emails were restored
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    String notLikePattern = '%' + invalidationText;
    List<Contact> restoredContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email != NULL AND Email != '' AND (NOT Email LIKE :notLikePattern)
    ];
    Assert.areEqual(
      contactCount,
      restoredContacts.size(),
      'All contact emails should be restored'
    );

    for (Contact contact : restoredContacts) {
      Assert.isFalse(
        contact.Email.contains(invalidationText),
        'Email should not contain ' + invalidationText
      );
    }
  }

  @isTest
  static void testRestoreAllConfiguredEmailsAuraMethod() {
    Test.startTest();

    InvalidateEmailUndoFlowAction.EmailRestorationResponse response = InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAura();

    Test.stopTest();

    // Verify response
    Assert.isInstanceOfType(
      response,
      InvalidateEmailUndoFlowAction.EmailRestorationResponse.class,
      'Response is the wrong type? How?!?'
    );
    Assert.isTrue(response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );

    // Verify that Contact emails were restored
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    String notLikePattern = '%' + invalidationText;
    List<Contact> restoredContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email != NULL AND Email != '' AND (NOT Email LIKE :notLikePattern)
    ];
    Assert.areEqual(
      contactCount,
      restoredContacts.size(),
      'All contact emails should be restored'
    );

    for (Contact contact : restoredContacts) {
      Assert.isFalse(
        contact.Email.contains(invalidationText),
        'Email should not contain ' + invalidationText
      );
    }
  }

  @isTest
  static void testExecuteEmailRestorationHelper() {
    Test.startTest();

    InvalidateEmailUndoFlowAction.EmailRestorationResponse response = InvalidateEmailUndoFlowAction.executeEmailRestoration();

    Test.stopTest();

    // Verify response
    Assert.isInstanceOfType(
      response,
      InvalidateEmailUndoFlowAction.EmailRestorationResponse.class,
      'Response is the wrong type? How?!?'
    );
    Assert.isTrue(response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );

    // Verify that Contact emails were restored
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    String notLikePattern = '%' + invalidationText;
    List<Contact> restoredContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email != NULL AND Email != '' AND (NOT Email LIKE :notLikePattern)
    ];
    Assert.areEqual(
      contactCount,
      restoredContacts.size(),
      'All contact emails should be restored'
    );

    for (Contact contact : restoredContacts) {
      Assert.isFalse(
        contact.Email.contains(invalidationText),
        'Email should not contain ' + invalidationText
      );
    }
  }

  @isTest
  static void testBlankDatabase() {
    // Delete all the contacts from Setup
    List<Contact> contacts = [SELECT Id FROM Contact];
    delete contacts;

    Test.startTest();

    InvalidateEmailUndoFlowAction.EmailRestorationResponse response = InvalidateEmailUndoFlowAction.executeEmailRestoration();

    Test.stopTest();

    // Verify response
    Assert.isInstanceOfType(
      response,
      InvalidateEmailUndoFlowAction.EmailRestorationResponse.class,
      'Response is the wrong type? How?!?'
    );
    Assert.isTrue(response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );
  }

  @isTest
  static void testEmailRestorationResponseClass() {
    InvalidateEmailUndoFlowAction.EmailRestorationResponse response = new InvalidateEmailUndoFlowAction.EmailRestorationResponse();

    String testMessage = 'Hello World';
    response.success = true;
    response.message = testMessage;

    Assert.isTrue(response.success, 'Success status setting failed.');
    Assert.areEqual(
      testMessage,
      response.message,
      'Response message setting failed'
    );
  }
}
