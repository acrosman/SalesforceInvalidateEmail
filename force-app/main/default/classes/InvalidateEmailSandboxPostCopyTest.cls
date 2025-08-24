@isTest
private class InvalidateEmailSandboxPostCopyTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    InvalidateEmailTestDataFactory.createTestContacts(contactCount);
  }

  @IsTest
  static void testInvalidateEmailSandboxPostCopyConstructor() {
    Test.startTest();
    InvalidateEmailSandboxPostCopy spc = new InvalidateEmailSandboxPostCopy();
    Test.stopTest();

    Assert.isInstanceOfType(
      spc,
      InvalidateEmailSandboxPostCopy.class,
      'Failed to create base object.'
    );
  }

  @IsTest
  static void testInvalidateEmailSandboxPostCopyRun() {
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
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    List<Contact> updatedContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email LIKE :('%' + invalidationText)
    ];
    System.assertEquals(
      contactCount,
      updatedContacts.size(),
      'All contact emails should be invalidated'
    );

    for (Contact contact : updatedContacts) {
      System.assert(
        contact.Email.contains(invalidationText),
        'Email should contain ' + invalidationText
      );
    }
  }
}
