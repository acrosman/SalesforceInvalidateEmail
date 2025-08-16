/**
 * Test data factory for Email Invalidator classes
 * Centralizes test data creation for consistent testing across all test classes
 */
@isTest
public class InvalidateEmailTestDataFactory {
  /**
   * Creates test contacts with email addresses
   * @param count Number of contacts to create
   * @return List of Contact records (inserted)
   */
  public static List<Contact> createTestContacts(Integer count) {
    List<Contact> testContacts = new List<Contact>();

    for (Integer i = 0; i < count; i++) {
      testContacts.add(
        new Contact(
          FirstName = 'Test',
          LastName = 'Contact' + i,
          Email = 'test' + i + '@example.com'
        )
      );
    }

    insert testContacts;
    return testContacts;
  }
}
