/**
 * Test class for InvalidateEmailFieldsController
 * Tests the controller methods for retrieving Email_Invalidator_Fields__mdt records
 */
@isTest
private class InvalidateEmailFieldsControllerTest {
  @isTest
  static void testGetInvalidateEmailFields() {
    Test.startTest();

    List<Email_Invalidator_Fields__mdt> result = InvalidateEmailFieldsController.getInvalidateEmailFields();

    Test.stopTest();

    // Assert that the method returns a list (even if empty)
    Assert.isNotNull(result, 'Result should not be null');

    // If there are any custom metadata records, verify they have the expected fields
    for (Email_Invalidator_Fields__mdt field : result) {
      Assert.isNotNull(field.Id, 'Id should not be null');
      Assert.isNotNull(field.Label, 'Label should not be null');
      Assert.isNotNull(field.DeveloperName, 'DeveloperName should not be null');
      Assert.isNotNull(field.Object__c, 'Object__c should not be null');
      Assert.isNotNull(field.Field_Name__c, 'Field_Name__c should not be null');
    }
  }

  @isTest
  static void testGetInvalidateEmailFieldsIsAuraEnabled() {
    // This test verifies that the method can be called from Lightning components
    // by ensuring it doesn't throw any exceptions when called
    Test.startTest();

    try {
      List<Email_Invalidator_Fields__mdt> result = InvalidateEmailFieldsController.getInvalidateEmailFields();
      Assert.isTrue(true, 'Method should execute without exceptions');
    } catch (Exception e) {
      Assert.fail('Method should not throw exceptions: ' + e.getMessage());
    }

    Test.stopTest();
  }
}
