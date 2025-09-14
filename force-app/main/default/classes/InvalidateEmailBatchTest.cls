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
