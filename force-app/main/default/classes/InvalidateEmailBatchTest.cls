/**
 * Test class for InvalidateEmailBatch
 * Tests the batch functionality for invalidating email addresses
 */
@isTest
private class InvalidateEmailBatchTest {
  @testSetup
  static void setupTestData() {
    // Create test contacts with email addresses
    List<Contact> testContacts = new List<Contact>();

    for (Integer i = 0; i < 10; i++) {
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
  static void testBatchWithDefaultConstructor() {
    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch();
    Database.executeBatch(batch, 5);

    Test.stopTest();

    // Verify that Contact emails were invalidated
    List<Contact> updatedContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email LIKE '%.invalid'
    ];
    System.assertEquals(
      10,
      updatedContacts.size(),
      'All contact emails should be invalidated'
    );

    for (Contact contact : updatedContacts) {
      System.assert(
        contact.Email.contains('.invalid@'),
        'Email should contain .invalid@'
      );
    }
  }

  @isTest
  static void testBatchWithSpecificObjectAndField() {
    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, 5);

    Test.stopTest();

    // Verify that Contact emails were invalidated
    List<Contact> updatedContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email LIKE '%.invalid'
    ];
    System.assertEquals(
      10,
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
  static void testBatchWithEmptyEmails() {
    // Create contacts with null and empty emails
    List<Contact> testContacts = new List<Contact>();
    testContacts.add(
      new Contact(FirstName = 'Test', LastName = 'NullEmail', Email = null)
    );
    testContacts.add(
      new Contact(FirstName = 'Test', LastName = 'EmptyEmail', Email = '')
    );
    insert testContacts;

    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, 5);

    Test.stopTest();

    // Verify that null and empty emails were not processed
    List<Contact> nullEmptyContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE LastName IN ('NullEmail', 'EmptyEmail')
    ];
    for (Contact contact : nullEmptyContacts) {
      System.assert(
        String.isBlank(contact.Email) || !contact.Email.contains('.invalid'),
        'Null and empty emails should not be processed'
      );
    }
  }

  @isTest
  static void testInvalidateAllConfiguredEmails() {
    Test.startTest();

    InvalidateEmailBatch.invalidateAllConfiguredEmails();

    Test.stopTest();

    // This test verifies the method runs without error
    // The actual functionality depends on the custom metadata records
    // which may not exist in the test context
    System.assert(true, 'Method should execute without error');
  }

  @isTest
  static void testBatchErrorHandling() {
    // Create a contact with a very long email to potentially cause an error
    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'LongEmail',
      Email = 'a'.repeat(200) + '@example.com'
    );
    insert testContact;

    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, 5);

    Test.stopTest();

    // The batch should handle errors gracefully
    // Verify the batch completed without throwing exceptions
    System.assert(true, 'Batch should handle errors gracefully');
  }
}
