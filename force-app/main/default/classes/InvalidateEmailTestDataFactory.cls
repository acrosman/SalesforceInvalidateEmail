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

  /**
   * Builds a valid email address of an exact length
   * @param length Total length of the address (16 to 116)
   * @return String email address
   */
  public static String buildEmailOfLength(Integer length) {
    // Pad the domain with short labels so every part of the address stays valid.
    return 'test@' + 'abcdefghi.'.repeat(10).left(length - 16) + 'example.com';
  }
}
