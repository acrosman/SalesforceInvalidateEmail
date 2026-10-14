/**
 * Utility class for retrieving Email Invalidator settings from custom metadata
 */
public without sharing class InvalidateEmailSettings {
  public static final String DEFAULT_INVALIDATION_TEXT = '.invalid';
  private static String invalidationText;

  /**
   * Gets the invalidation text from custom metadata
   * @return String The invalidation text to append to email addresses
   */
  public static String getInvalidationText() {
    if (invalidationText == null) {
      try {
        Email_Invalidator_Settings__mdt setting = Email_Invalidator_Settings__mdt.getInstance(
          'Invalidation_Text'
        );
        if (setting != null && String.isNotBlank(setting.Setting_Value__c)) {
          invalidationText = setting.Setting_Value__c;
        } else {
          // Fallback to default value if custom metadata is not found
          invalidationText = DEFAULT_INVALIDATION_TEXT;
          System.debug(
            'Warning: Invalidation_Text custom metadata not found, using default value: ' +
            invalidationText
          );
        }
      } catch (Exception e) {
        // Fallback to default value if there's any error
        invalidationText = DEFAULT_INVALIDATION_TEXT;
        System.debug(
          'Error retrieving invalidation text from custom metadata: ' +
            e.getMessage() +
            ', using default value: ' +
            invalidationText
        );
      }
    }
    return invalidationText;
  }

  /**
   * Clears the cached invalidation text (useful for testing and after settings updates)
   */
  public static void clearCache() {
    invalidationText = null;
  }
}
