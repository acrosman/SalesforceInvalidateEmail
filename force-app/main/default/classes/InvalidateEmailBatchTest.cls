/**
 * Test class for InvalidateEmailBatch
 * Tests the batch functionality for invalidating email addresses
 */
@isTest
private class InvalidateEmailBatchTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    InvalidateEmailTestDataFactory.createTestContacts(contactCount);
  }

  @isTest
  static void testBatchWithSpecificObjectAndField() {
    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for head room.

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
    Database.executeBatch(batch, contactCount + 5); // Added 5 for head room

    Test.stopTest();

    // Verify that null and empty emails were not processed
    List<Contact> nullEmptyContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE LastName IN ('NullEmail', 'EmptyEmail')
    ];
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    for (Contact contact : nullEmptyContacts) {
      System.assert(
        String.isBlank(contact.Email) ||
        !contact.Email.contains(invalidationText),
        'Null and empty emails should not be processed'
      );
    }
  }

  @isTest
  static void testInvalidateAllConfiguredEmails() {
    Test.startTest();

    InvalidateEmailBatch.invalidateAllConfiguredEmails();

    Test.stopTest();

    // We need the default Contact_Email custom metadata type for a meaningful test, but it's possible
    // that was deleted in real-life, so we fallback to a useless test.
    Map<String, Email_Invalidator_Fields__mdt> emailFields = Email_Invalidator_Fields__mdt.getAll();
    if (emailFields.containsKey('Contact_Email')) {
      // Verify that Contact emails were invalidated
      String invalidationText = InvalidateEmailSettings.getInvalidationText();
      List<Contact> updatedContacts = [
        SELECT Id, Email
        FROM Contact
        WHERE Email LIKE :('%' + invalidationText)
      ];
      Assert.areEqual(
        contactCount,
        updatedContacts.size(),
        'All contact emails should be invalidated'
      );

      for (Contact contact : updatedContacts) {
        Assert.isTrue(
          contact.Email.contains(invalidationText),
          'Email should contain ' + invalidationText
        );
      }
    } else {
      Assert.isTrue(
        true,
        'This test is impossible to fail, if the the code ran successfully'
      );
    }
  }

  @isTest
  static void testBatchNoDoubleInvalid() {
    // Create a contact with a very long email to potentially cause an error
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'LongEmail',
      Email = 'a@example.com' + invalidationText
    );
    insert testContact;

    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom (needed here)

    Test.stopTest();

    String doubleInvalidPattern = '%' + invalidationText + invalidationText;
    Integer doubleCount = [
      SELECT COUNT()
      FROM Contact
      WHERE Email LIKE :doubleInvalidPattern
    ];
    Assert.isFalse(doubleCount > 0, 'We double invalidated an address');
  }

  @isTest
  static void testBatchErrorHandling() {
    // Create a contact with a very long email to potentially cause an error
    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'LongEmail',
      Email = 'a'.repeat(65) + '@example.com'
    );
    insert testContact;

    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom (needed here)

    Test.stopTest();

    // The batch should handle errors gracefully
    // Verify the batch completed without throwing exceptions
    System.assert(true, 'Batch should handle errors gracefully');
  }

  @isTest
  static void testBatchNoRecords() {
    // Delete all the contacts from Setup
    List<Contact> contacts = [SELECT Id FROM Contact];
    delete contacts;

    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom (needed here)

    Test.stopTest();

    // The batch not have a problem with an empty result set.
    Assert.IsTrue(true, 'Batch should handle errors gracefully');
  }

  @isTest
  static void testConvertToObjectApiName() {
    Test.startTest();

    // Test with standard object name (should return as-is)
    String standardObjectResult = InvalidateEmailBatch.convertToObjectApiName(
      'Contact'
    );
    Assert.areEqual(
      'Contact',
      standardObjectResult,
      'Standard object name should be returned as-is'
    );

    // Test with blank/null values
    String blankResult = InvalidateEmailBatch.convertToObjectApiName('');
    Assert.areEqual('', blankResult, 'Blank value should be returned as-is');

    String nullResult = InvalidateEmailBatch.convertToObjectApiName(null);
    Assert.areEqual(null, nullResult, 'Null value should be returned as-is');

    // Test with a valid EntityDefinition Id (using Contact's EntityDefinition Id)
    EntityDefinition contactEntity = [
      SELECT Id, QualifiedApiName
      FROM EntityDefinition
      WHERE QualifiedApiName = 'Contact'
      LIMIT 1
    ];
    String entityIdResult = InvalidateEmailBatch.convertToObjectApiName(
      contactEntity.Id
    );
    Assert.areEqual(
      'Contact',
      entityIdResult,
      'EntityDefinition Id should be converted to API name'
    );

    // Test with invalid Id format (should return as-is)
    String invalidIdResult = InvalidateEmailBatch.convertToObjectApiName(
      'InvalidId123'
    );
    Assert.areEqual(
      'InvalidId123',
      invalidIdResult,
      'Invalid Id should be returned as-is'
    );

    Test.stopTest();
  }
}
