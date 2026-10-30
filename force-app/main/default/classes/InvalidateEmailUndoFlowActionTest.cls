/**
 * Test class for InvalidateEmailUndoFlowAction
 * Tests the invocable methods that trigger the email restoration batch
 */
@isTest
private class InvalidateEmailUndoFlowActionTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    Assert.isTrue(
      String.isNotBlank(invalidationText),
      'Invalidation text should never be blank'
    );

    List<Contact> testContacts = InvalidateEmailTestDataFactory.createTestContacts(
      contactCount
    );

    // Invalidate the emails first so we have something to restore
    for (Contact contact : testContacts) {
      contact.Email = contact.Email + invalidationText;
    }
    update testContacts;

    String likePattern = '%' + invalidationText;
    Assert.areEqual(
      contactCount,
      [SELECT COUNT() FROM Contact WHERE Email LIKE :likePattern],
      'Setup failed to leave ' + contactCount + ' contacts invalidated'
    );
  }

  // Use a known field configuration so results don't depend on the
  // Email_Invalidator_Fields__mdt records in the org.
  private static void useContactEmailConfig() {
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Contact' => new Set<String>{ 'Email' }
    };
  }

  private static void assertAllEmailsRestored() {
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    List<Contact> contacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email != NULL
    ];
    Assert.areEqual(
      contactCount,
      contacts.size(),
      'Expected ' + contactCount + ' contacts with an email address'
    );

    for (Contact contact : contacts) {
      Assert.isFalse(
        contact.Email.endsWith(invalidationText),
        'Email was not restored, still ends with ' + invalidationText
      );
    }
  }

  @isTest
  static void testRestoreAllConfiguredEmailsAction() {
    useContactEmailConfig();
    Test.startTest();

    List<InvalidateEmailUndoFlowAction.EmailRestorationResponse> responses = InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAction();

    Test.stopTest();

    // Verify response
    Assert.areEqual(1, responses.size(), 'Should return one response');
    InvalidateEmailUndoFlowAction.EmailRestorationResponse response = responses[0];
    Assert.isTrue(response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );

    assertAllEmailsRestored();
  }

  @isTest
  static void testRestoreAllConfiguredEmailsAuraMethod() {
    useContactEmailConfig();
    Test.startTest();

    InvalidateEmailUndoFlowAction.EmailRestorationResponse response = InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAura();

    Test.stopTest();

    Assert.areEqual(
      new Set<String>{ 'Contact' },
      new Set<String>(response.jobs.values()),
      'Response should map started jobs to their objects'
    );

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

    assertAllEmailsRestored();
  }

  @isTest
  static void testExecuteEmailRestorationHelper() {
    useContactEmailConfig();
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

    assertAllEmailsRestored();
  }

  @isTest
  static void testBlankDatabase() {
    // Delete all the contacts from Setup
    List<Contact> contacts = [SELECT Id FROM Contact];
    delete contacts;
    useContactEmailConfig();

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
