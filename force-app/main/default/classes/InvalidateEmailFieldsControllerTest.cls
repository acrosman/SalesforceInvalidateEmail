/**
 * Test class for InvalidateEmailFieldsController
 * Tests the controller methods for retrieving Email_Invalidator_Fields__mdt records
 */
@isTest
private class InvalidateEmailFieldsControllerTest {
  @isTest
  static void testGetInvalidateEmailFields() {
    Test.startTest();

    Map<String, Email_Invalidator_Fields__mdt> result = InvalidateEmailFieldsController.getInvalidateEmailFields();

    Test.stopTest();

    // Assert that the method returns a list (even if empty)
    Assert.isNotNull(result, 'Result should not be null');

    // If there are any custom metadata records, verify they have the expected fields
    for (String record : result.keySet()) {
      Email_Invalidator_Fields__mdt field = result.get(record);
      Assert.isNotNull(field.Id, 'Id should not be null');
      Assert.isNotNull(field.Label, 'Label should not be null');
      Assert.isNotNull(field.DeveloperName, 'DeveloperName should not be null');
      Assert.isNotNull(field.Object__c, 'Object__c should not be null');
      Assert.isNotNull(field.Field_Name__c, 'Field_Name__c should not be null');
    }
  }

  @IsTest
  static void testGetCustomMetadataObjectPrefix() {
    String expectedPrefix = Email_Invalidator_Fields__mdt.sobjecttype.getDescribe()
      .getKeyPrefix();

    System.assertEquals(
      expectedPrefix,
      InvalidateEmailFieldsController.getCustomMetadataObjectPrefix(),
      'Prefix does not match expected value'
    );
  }
}
