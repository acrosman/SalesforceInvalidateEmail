/**
 * Test class for InvalidateEmailSettings
 * Tests the utility methods for retrieving invalidation text from custom metadata
 */
@isTest
private class InvalidateEmailSettingsTest {
  @isTest
  static void testGetInvalidationTextWithValidMetadata() {
    // The test will use the existing custom metadata record
    Test.startTest();

    String invalidationText = InvalidateEmailSettings.getInvalidationText();

    Test.stopTest();

    // Should return the value from custom metadata (which is ".invalid" by default)
    Assert.isNotNull(invalidationText, 'Invalidation text should not be null');
    Assert.isTrue(
      String.isNotBlank(invalidationText),
      'Invalidation text should not be blank'
    );
  }

  @isTest
  static void testGetInvalidationTextCaching() {
    Test.startTest();

    // Call the method twice to test caching
    String invalidationText1 = InvalidateEmailSettings.getInvalidationText();
    String invalidationText2 = InvalidateEmailSettings.getInvalidationText();

    Test.stopTest();

    // Both calls should return the same value
    Assert.areEqual(
      invalidationText1,
      invalidationText2,
      'Cached value should be the same'
    );
  }

  @isTest
  static void testClearCache() {
    Test.startTest();

    // Get the value first to populate cache
    String invalidationText1 = InvalidateEmailSettings.getInvalidationText();

    // Clear the cache
    InvalidateEmailSettings.clearCache();

    // Get the value again
    String invalidationText2 = InvalidateEmailSettings.getInvalidationText();

    Test.stopTest();

    // Both values should be the same (since we're using the same metadata)
    Assert.areEqual(
      invalidationText1,
      invalidationText2,
      'Values should be consistent after cache clear'
    );
  }
}
