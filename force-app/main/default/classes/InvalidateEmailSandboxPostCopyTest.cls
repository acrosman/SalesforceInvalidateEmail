/**
 * Test class for InvalidateEmailSandboxPostCopy
 */
@IsTest
private class InvalidateEmailSandboxPostCopyTest {
  private static Integer contactCount = 10;

  @TestSetup
  static void setupTestData() {
    InvalidateEmailTestDataFactory.createTestContacts(contactCount);
  }

  @IsTest
  static void testInvalidateEmailSandboxPostCopyConstructor() {
    InvalidateEmailSandboxPostCopy spc = new InvalidateEmailSandboxPostCopy();

    Assert.isInstanceOfType(
      spc,
      InvalidateEmailSandboxPostCopy.class,
      'Failed to create base object.'
    );
  }

  @IsTest
  static void testInvalidateEmailSandboxPostCopyRun() {
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    String likePattern = '%' + invalidationText;
    Assert.areEqual(
      0,
      [SELECT COUNT() FROM Contact WHERE Email LIKE :likePattern],
      'No contact should already be invalidated before the script runs'
    );

    // Use a known field configuration so results don't depend on the
    // Email_Invalidator_Fields__mdt records in the org.
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Contact' => new Set<String>{ 'Email' }
    };

    Test.startTest();
    Test.testSandboxPostCopyScript(
      new InvalidateEmailSandboxPostCopy(),
      UserInfo.getOrganizationId(),
      '00D000000000000',
      UserInfo.getOrganizationName(),
      true
    );
    Test.stopTest();

    // Verify that Contact emails were invalidated
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
}
