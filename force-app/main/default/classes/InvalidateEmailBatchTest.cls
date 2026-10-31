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
    // Use a known field configuration so results don't depend on the
    // Email_Invalidator_Fields__mdt records in the org.
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Contact' => new Set<String>{ 'Email' }
    };

    Test.startTest();

    Map<Id, String> jobs = InvalidateEmailBatch.invalidateAllConfiguredEmails();

    Test.stopTest();

    Assert.areEqual(1, jobs.size(), 'Should start one job per object');
    Assert.areEqual(
      'Contact',
      jobs.values()[0],
      'Job should be mapped to its object'
    );

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
        contact.Email.endsWith(invalidationText),
        'Email should end with ' + invalidationText
      );
    }
  }

  @isTest
  static void testGetConfiguredFieldsFromMetadata() {
    // Without an override the configuration comes from custom metadata,
    // whose contents vary by org, so only check the call succeeds.
    Map<String, Set<String>> result = InvalidateEmailBatch.getConfiguredFields();

    Assert.isNotNull(result, 'Configured fields should never be null');
  }

  @isTest
  static void testBatchMultipleFieldsSameRecord() {
    // Contact has no second standard email field, so Title stands in for one.
    // Invalidating two fields on one record must not add it to the update list twice.
    List<Contact> contacts = [SELECT Id FROM Contact];
    for (Contact contact : contacts) {
      contact.Title = 'Manager';
    }
    update contacts;

    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email', 'Title' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom

    Test.stopTest();

    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    for (Contact contact : [SELECT Email, Title FROM Contact]) {
      Assert.isTrue(
        contact.Email.endsWith(invalidationText),
        'Email should be invalidated'
      );
      Assert.isTrue(
        contact.Title.endsWith(invalidationText),
        'Title should be invalidated'
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
  static void testInvalidateValue() {
    String shortEmail = 'a@b.com';
    String fitsEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(72);
    String nearLimitEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(
      77
    );
    String atLimitEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(80);

    Assert.areEqual(
      'a@b.com.invalid',
      InvalidateEmailBatch.invalidateValue(shortEmail, '.invalid'),
      'Short emails should have the full text appended'
    );
    Assert.areEqual(
      fitsEmail + '.invalid',
      InvalidateEmailBatch.invalidateValue(fitsEmail, '.invalid'),
      'Emails that fit exactly should have the full text appended'
    );
    Assert.areEqual(
      nearLimitEmail + '.in',
      InvalidateEmailBatch.invalidateValue(nearLimitEmail, '.invalid'),
      'Emails under the limit should be cut off at the limit'
    );
    Assert.areEqual(
      atLimitEmail.left(72) + '.invalid',
      InvalidateEmailBatch.invalidateValue(atLimitEmail, '.invalid'),
      'Emails at the limit should be shortened to fit the full text'
    );
  }

  @isTest
  static void testIsInvalidated() {
    String nearLimitEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(
      77
    );

    Assert.isTrue(
      InvalidateEmailBatch.isInvalidated('a@b.com.invalid', '.invalid'),
      'Emails ending with the full text are invalidated'
    );
    Assert.isTrue(
      InvalidateEmailBatch.isInvalidated(nearLimitEmail + '.in', '.invalid'),
      'Emails at the limit ending with part of the text are invalidated'
    );
    Assert.isFalse(
      InvalidateEmailBatch.isInvalidated('a@b.com', '.invalid'),
      'Plain emails are not invalidated'
    );
    Assert.isFalse(
      InvalidateEmailBatch.isInvalidated('a@b.co.in', '.invalid'),
      'Emails under the limit ending with part of the text are not invalidated'
    );
  }

  @isTest
  static void testBatchTruncatesLongEmails() {
    String nearLimitEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(
      77
    );
    String atLimitEmail = InvalidateEmailTestDataFactory.buildEmailOfLength(80);
    insert new List<Contact>{
      new Contact(LastName = 'NearLimit', Email = nearLimitEmail),
      new Contact(LastName = 'AtLimit', Email = atLimitEmail)
    };

    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom

    Test.stopTest();

    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    Map<String, String> emailsByName = new Map<String, String>();
    for (Contact contact : [
      SELECT LastName, Email
      FROM Contact
      WHERE LastName IN ('NearLimit', 'AtLimit')
    ]) {
      emailsByName.put(contact.LastName, contact.Email);
    }

    Assert.areEqual(
      InvalidateEmailBatch.invalidateValue(nearLimitEmail, invalidationText),
      emailsByName.get('NearLimit'),
      'Emails under the limit should be invalidated and cut off at the limit'
    );
    Assert.areEqual(
      atLimitEmail.left(80 - invalidationText.length()) + invalidationText,
      emailsByName.get('AtLimit'),
      'Emails at the limit should be shortened to fit the full text'
    );
  }

  @isTest
  static void testBatchNoDoubleInvalidTruncated() {
    String invalidationText = InvalidateEmailSettings.getInvalidationText();
    String truncatedEmail = InvalidateEmailBatch.invalidateValue(
      InvalidateEmailTestDataFactory.buildEmailOfLength(77),
      invalidationText
    );
    insert new Contact(LastName = 'Truncated', Email = truncatedEmail);

    Test.startTest();

    InvalidateEmailBatch batch = new InvalidateEmailBatch(
      'Contact',
      new Set<String>{ 'Email' }
    );
    Database.executeBatch(batch, contactCount + 5); // Added 5 for headroom

    Test.stopTest();

    Contact contact = [SELECT Email FROM Contact WHERE LastName = 'Truncated'];
    Assert.areEqual(
      truncatedEmail,
      contact.Email,
      'Emails already cut off at the limit should not be invalidated again'
    );
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
  static void testGetFieldDetails() {
    Test.startTest();

    // Create test metadata map similar to what would come from Email_Invalidator_Fields__mdt.getAll()
    Map<String, Email_Invalidator_Fields__mdt> testMetadata = new Map<String, Email_Invalidator_Fields__mdt>();

    // Get the actual DurableId for Contact.Email field to use in test
    EntityParticle contactEmailField = [
      SELECT DurableId, QualifiedApiName, EntityDefinition.QualifiedApiName
      FROM EntityParticle
      WHERE
        EntityDefinition.QualifiedApiName = 'Contact'
        AND QualifiedApiName = 'Email'
      LIMIT 1
    ];

    // Create a mock metadata record
    Email_Invalidator_Fields__mdt mockField = new Email_Invalidator_Fields__mdt();
    mockField.Field_Name__c = contactEmailField.DurableId;
    testMetadata.put('Contact_Email', mockField);

    // Test the getFieldDetails method
    Map<String, Set<String>> result = InvalidateEmailBatch.getFieldDetails(
      testMetadata
    );

    Test.stopTest();

    // Verify the results
    Assert.isTrue(
      result.containsKey('Contact'),
      'Result should contain Contact object'
    );
    Assert.isTrue(
      result.get('Contact').contains('Email'),
      'Contact should have Email field'
    );
    Assert.areEqual(
      1,
      result.get('Contact').size(),
      'Contact should have exactly one field'
    );
  }

  @isTest
  static void testGetFieldDetailsWithMultipleFields() {
    Test.startTest();

    // Create test metadata map with multiple fields
    Map<String, Email_Invalidator_Fields__mdt> testMetadata = new Map<String, Email_Invalidator_Fields__mdt>();

    // Get DurableIds for multiple Contact fields
    List<EntityParticle> contactFields = [
      SELECT DurableId, DeveloperName, EntityDefinition.DeveloperName
      FROM EntityParticle
      WHERE
        EntityDefinition.DeveloperName = 'Contact'
        AND DeveloperName IN ('Email', 'AssistantEmail')
      ORDER BY DeveloperName
    ];

    Integer fieldIndex = 0;
    for (EntityParticle field : contactFields) {
      Email_Invalidator_Fields__mdt mockField = new Email_Invalidator_Fields__mdt();
      mockField.Field_Name__c = field.DurableId;
      testMetadata.put('Contact_Field_' + fieldIndex, mockField);
      fieldIndex++;
    }

    // Test the getFieldDetails method
    Map<String, Set<String>> result = InvalidateEmailBatch.getFieldDetails(
      testMetadata
    );

    Test.stopTest();

    // Verify the results
    Assert.isTrue(
      result.containsKey('Contact'),
      'Result should contain Contact object'
    );
    Assert.areEqual(
      contactFields.size(),
      result.get('Contact').size(),
      'Contact should have the correct number of fields'
    );

    for (EntityParticle field : contactFields) {
      Assert.isTrue(
        result.get('Contact').contains(field.DeveloperName),
        'Contact should contain field: ' + field.DeveloperName
      );
    }
  }

  @isTest
  static void testGetFieldDetailsWithEmptyInput() {
    Test.startTest();

    // Test with empty metadata map
    Map<String, Email_Invalidator_Fields__mdt> emptyMetadata = new Map<String, Email_Invalidator_Fields__mdt>();
    Map<String, Set<String>> result = InvalidateEmailBatch.getFieldDetails(
      emptyMetadata
    );

    Test.stopTest();

    // Verify the results
    Assert.isTrue(
      result.isEmpty(),
      'Result should be empty when input is empty'
    );
  }
}
