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
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    for (Contact contact : testContacts) {
      contact.Email = contact.Email + invalidationText;
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
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    String notLikePattern = '%' + invalidationText;
    List<Contact> restoredContacts = [
      SELECT Id, Email
      FROM Contact
      WHERE Email != NULL AND Email != '' AND (NOT Email LIKE :notLikePattern)
    ];
    System.assertEquals(
      contactCount,
      restoredContacts.size(),
      'All contact emails should be restored'
    );

    for (Contact contact : restoredContacts) {
      System.assert(
        !contact.Email.contains(invalidationText),
        'Email should not contain ' + invalidationText
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
    // Use a known field configuration so results don't depend on the
    // Email_Invalidator_Fields__mdt records in the org.
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Contact' => new Set<String>{ 'Email' }
    };

    Test.startTest();

    InvalidateEmailUndoBatch.restoreAllConfiguredEmails();

    Test.stopTest();

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
        contact.Email.endsWith(invalidationText),
        'Email should not end with ' + invalidationText
      );
    }
  }

  @isTest
  static void testBatchMultipleFieldsSameRecord() {
    // Contact has no second standard email field, so Title stands in for one.
    // Restoring two fields on one record must not add it to the update list twice.
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    List<Contact> contacts = [SELECT Id FROM Contact];
    for (Contact contact : contacts) {
      contact.Title = 'Manager' + invalidationText;
    }
    update contacts;

    Test.startTest();

    InvalidateEmailUndoBatch batch = new InvalidateEmailUndoBatch(
      'Contact',
      new Set<String>{ 'Email', 'Title' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom

    Test.stopTest();

    for (Contact contact : [SELECT Email, Title FROM Contact]) {
      Assert.isFalse(
        contact.Email.endsWith(invalidationText),
        'Email should be restored'
      );
      Assert.areEqual('Manager', contact.Title, 'Title should be restored');
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
  static void testRestoreValue() {
    String nearLimitEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(
      77
    );
    String fitsEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(72);

    Assert.areEqual(
      'a@b.com',
      InvalidateEmailBatch.restoreValue('a@b.com.invalid', '.invalid'),
      'The full text should be removed'
    );
    Assert.areEqual(
      fitsEmail,
      InvalidateEmailBatch.restoreValue(fitsEmail + '.invalid', '.invalid'),
      'The full text should be removed from emails at the limit'
    );
    Assert.areEqual(
      nearLimitEmail,
      InvalidateEmailBatch.restoreValue(nearLimitEmail + '.in', '.invalid'),
      'Part of the text left at the limit should be removed'
    );
    Assert.areEqual(
      'a@b.co.in',
      InvalidateEmailBatch.restoreValue('a@b.co.in', '.invalid'),
      'Emails under the limit without the full text should be unchanged'
    );
  }

  @isTest
  static void testBatchRestoresTruncatedEmails() {
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    String nearLimitEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(
      77
    );
    String atLimitEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(80);
    insert new List<Contact>{
      new Contact(
        LastName = 'NearLimit',
        Email = InvalidateEmailBatch.invalidateValue(
          nearLimitEmail,
          invalidationText
        )
      ),
      new Contact(
        LastName = 'AtLimit',
        Email = InvalidateEmailBatch.invalidateValue(
          atLimitEmail,
          invalidationText
        )
      )
    };

    Test.startTest();

    InvalidateEmailUndoBatch batch = new InvalidateEmailUndoBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom

    Test.stopTest();

    Map<String, String> emailsByName = new Map<String, String>();
    for (Contact contact : [
      SELECT LastName, Email
      FROM Contact
      WHERE LastName IN ('NearLimit', 'AtLimit')
    ]) {
      emailsByName.put(contact.LastName, contact.Email);
    }

    Assert.areEqual(
      nearLimitEmail,
      emailsByName.get('NearLimit'),
      'Emails cut off at the limit should be fully restored'
    );
    Assert.areEqual(
      atLimitEmail.left(80 - invalidationText.length()),
      emailsByName.get('AtLimit'),
      'Emails shortened to fit the text can only be partly restored'
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
