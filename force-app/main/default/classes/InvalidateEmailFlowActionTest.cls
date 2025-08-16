/**
 * Test class for InvalidateEmailFlowAction
 * Tests the invocable methods that trigger the email invalidation batch
 */
@isTest
private class InvalidateEmailFlowActionTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    InvalidateEmailTestDataFactory.createTestContacts(contactCount);
  }

  @isTest
  static void testInvalidateAllConfiguredEmails() {
    Test.startTest();

    List<InvalidateEmailFlowAction.EmailInvalidationResponse> responses = InvalidateEmailFlowAction.invalidateAllConfiguredEmails();

    Test.stopTest();

    // Verify response
    Assert.areEqual(1, responses.size(), 'Should return one response');
    InvalidateEmailFlowAction.EmailInvalidationResponse response = responses[0];
    Assert.areEqual(true, response.success, 'Should be successful');
    Assert.isTrue(
      response.message.contains('started'),
      'Should contain success message'
    );

    // Verify that Contact emails were invalidated
    List<Contact> updatedContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email LIKE '%.invalid'
    ];
    System.assertEquals(
      contactCount,
      updatedContacts.size(),
      'All contact emails should be invalidated'
    );

    for (Contact contact : updatedContacts) {
      System.assert(
        contact.Email.contains('.invalid'),
        'Email should contain .invalid'
      );
    }
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
