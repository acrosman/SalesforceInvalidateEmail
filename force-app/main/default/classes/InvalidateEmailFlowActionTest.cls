/**
 * Test class for InvalidateEmailFlowAction
 * Tests the invocable methods that trigger the email invalidation batch
 */
@isTest
private class InvalidateEmailFlowActionTest {
  @testSetup
  static void setupTestData() {
    // Create test contacts with email addresses
    List<Contact> testContacts = new List<Contact>();

    for (Integer i = 0; i < 5; i++) {
      testContacts.add(
        new Contact(
          FirstName = 'Test',
          LastName = 'Contact' + i,
          Email = 'test' + i + '@example.com'
        )
      );
    }

    insert testContacts;
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
