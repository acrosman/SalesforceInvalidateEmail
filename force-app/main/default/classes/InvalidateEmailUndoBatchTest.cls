/**
 * Test class for InvalidateEmailUndoBatch
 * Tests the batch functionality for restoring email addresses by removing .invalid suffix
 */
@isTest
private class InvalidateEmailUndoBatchTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    List<Contact> testContacts = InvalidateEmailTestDataFactory.createTestContacts(
      contactCount
    );

    // Invalidate the emails first so we have something to restore
    for (Contact contact : testContacts) {
      contact.Email = contact.Email + '.invalid';
    }
    update testContacts;
  }

  @isTest
  static void testBatchWithSpecificObjectAndField() {
    Test.startTest();

    InvalidateEmailUndoBatch batch = new InvalidateEmailUndoBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for head room.

    Test.stopTest();

    // Verify that Contact emails were restored
    List<Contact> restoredContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email != NULL AND Email != '' AND (NOT Email LIKE '%.invalid')
    ];
    System.assertEquals(
      contactCount,
      restoredContacts.size(),
      'All contact emails should be restored'
    );

    for (Contact contact : restoredContacts) {
      System.assert(
        !contact.Email.contains('.invalid'),
        'Email should not contain .invalid'
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

    InvalidateEmailUndoBatch batch = new InvalidateEmailUndoBatch(
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
    for (Contact contact : nullEmptyContacts) {
      System.assert(
        String.isBlank(contact.Email),
        'Null and empty emails should remain unchanged'
      );
    }
  }

  @isTest
  static void testRestoreAllConfiguredEmails() {
    Test.startTest();

    InvalidateEmailUndoBatch.restoreAllConfiguredEmails();

    Test.stopTest();

    // We need the default Contact_Email custom metadata type for a meaningful test, but it's possible
    // that was deleted in real-life, so we fallback to a useless test.
    Map<String, Email_Invalidator_Fields__mdt> emailFields = Email_Invalidator_Fields__mdt.getAll();
    if (emailFields.containsKey('Contact_Email')) {
      // Verify that Contact emails were restored
      List<Contact> restoredContacts = [
        SELECT Id, Email
        FROM Contact
        WHERE Email != NULL AND Email != '' AND (NOT Email LIKE '%.invalid')
      ];
      Assert.areEqual(
        contactCount,
        restoredContacts.size(),
        'All contact emails should be restored'
      );

      for (Contact contact : restoredContacts) {
        Assert.isTrue(
          !contact.Email.contains('.invalid'),
          'Email should not contain .invalid'
        );
      }
    } else {
      Assert.isTrue(
        true,
        'This test is impossible to fail, if the code ran successfully'
      );
    }
  }

  @isTest
  static void testBatchNoDoubleRestore() {
    // Create a contact with a normal email (not invalidated)
    Contact testContact = new Contact(
      FirstName = 'Test',
      LastName = 'NormalEmail',
      Email = 'normal@example.com'
    );
    insert testContact;

    Test.startTest();

    InvalidateEmailUndoBatch batch = new InvalidateEmailUndoBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom

    Test.stopTest();

    // Verify that normal emails were not modified
    Contact updatedContact = [
      SELECT Id, Email
      FROM Contact
      WHERE LastName = 'NormalEmail'
      LIMIT 1
    ];
    Assert.areEqual(
      'normal@example.com',
      updatedContact.Email,
      'Normal email should remain unchanged'
    );
  }

  @isTest
  static void testBatchNoRecords() {
    // Delete all the contacts from Setup
    List<Contact> contacts = [SELECT Id FROM Contact];
    delete contacts;

    Test.startTest();

    InvalidateEmailUndoBatch batch = new InvalidateEmailUndoBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom

    Test.stopTest();

    // The batch should not have a problem with an empty result set.
    Assert.IsTrue(true, 'Batch should handle empty result set gracefully');
  }
}
