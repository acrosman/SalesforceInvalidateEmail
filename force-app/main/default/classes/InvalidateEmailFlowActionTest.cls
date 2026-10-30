/**
 * Test class for InvalidateEmailFlowAction
 * Tests the invocable methods that trigger the email invalidation batch
 */
@isTest
private class InvalidateEmailFlowActionTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    Assert.isTrue(
      String.isNotBlank(invalidationText),
      'Invalidation text should never be blank'
    );

    InvalidateEmailTestDataFactory.createTestContacts(contactCount);

    String likePattern = '%' + invalidationText;
    Assert.areEqual(
      contactCount,
      [SELECT COUNT() FROM Contact WHERE Email != NULL],
      'Setup should have created ' + contactCount + ' contacts with an email'
    );
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Contact WHERE Email LIKE :likePattern],
      'No contact should already be invalidated before the batch runs'
    );
  }

  // Use a known field configuration so results don't depend on the
  // Email_Invalidator_Fields__mdt records in the org.
  private static void useContactEmailConfig() {
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Contact' => new Set<String>{ 'Email' }
    };
  }

  private static void assertAllEmailsInvalidated() {
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    String likePattern = '%' + invalidationText;
    List<Contact> invalidatedContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email LIKE :likePattern
    ];
    Assert.areEqual(
      contactCount,
      invalidatedContacts.size(),
      'All contact emails should be invalidated'
    );

    for (Contact contact : invalidatedContacts) {
      Assert.isTrue(
        contact.Email.endsWith(invalidationText),
        'Email should end with ' + invalidationText
      );
    }
  }

  @isTest
  static void testInvalidateAllConfiguredEmailsAction() {
    useContactEmailConfig();
    Test.startTest();

    List<InvalidateEmailFlowAction.EmailInvalidationResponse> responses = InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAction();

    Test.stopTest();

    // Verify response
    Assert.areEqual(1, responses.size(), 'Should return one response');
    InvalidateEmailFlowAction.EmailInvalidationResponse response = responses[0];
    Assert.isTrue(response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );

    assertAllEmailsInvalidated();
  }

  @isTest
  static void testInvalidateAllConfiguredEmailsAuraMethod() {
    useContactEmailConfig();
    Test.startTest();

    InvalidateEmailFlowAction.EmailInvalidationResponse response = InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura();

    Test.stopTest();

    Assert.areEqual(
      new Set<String>{ 'Contact' },
      new Set<String>(response.jobs.values()),
      'Response should map started jobs to their objects'
    );

    // Verify response
    Assert.isInstanceOfType(
      response,
      InvalidateEmailFlowAction.EmailInvalidationResponse.class,
      'Response is the wrong type? How?!?'
    );
    Assert.isTrue(response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );

    assertAllEmailsInvalidated();
  }

  @isTest
  static void testInvalidateAllConfiguredEmailsHelper() {
    useContactEmailConfig();
    Test.startTest();

    InvalidateEmailFlowAction.EmailInvalidationResponse response = InvalidateEmailFlowAction.executeEmailInvalidation();

    Test.stopTest();

    // Verify response
    Assert.isInstanceOfType(
      response,
      InvalidateEmailFlowAction.EmailInvalidationResponse.class,
      'Response is the wrong type? How?!?'
    );
    Assert.isTrue(response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );

    assertAllEmailsInvalidated();
  }

  @isTest
  static void testBlankDatabase() {
    // Delete all the contacts from Setup
    List<Contact> contacts = [SELECT Id FROM Contact];
    delete contacts;
    useContactEmailConfig();

    Test.startTest();

    InvalidateEmailFlowAction.EmailInvalidationResponse response = InvalidateEmailFlowAction.executeEmailInvalidation();

    Test.stopTest();

    // Verify response
    Assert.isInstanceOfType(
      response,
      InvalidateEmailFlowAction.EmailInvalidationResponse.class,
      'Response is the wrong type? How?!?'
    );
    Assert.isTrue(response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );
  }

  @isTest
  static void testEmailInvalidationResponseClass() {
    InvalidateEmailFlowAction.EmailInvalidationResponse response = new InvalidateEmailFlowAction.EmailInvalidationResponse();

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
