/**
 * Test class for InvalidateEmailSettingsController
 */
@IsTest
private class InvalidateEmailSettingsControllerTest {
  @IsTest
  static void testGetCurrentSettings() {
    Test.startTest();

    // Test getting current settings
    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.getCurrentSettings();

    Test.stopTest();

    // Verify response
    System.assert(response.success, 'getCurrentSettings should succeed');
    System.assertNotEquals(
      null,
      response.settings,
      'Settings should not be null'
    );
    System.assertEquals(1, response.settings.size(), 'Should have one setting');

    // Verify the Invalidation_Text setting
    InvalidateEmailSettingsController.SettingWrapper setting = response.settings[0];
    System.assertEquals(
      'Invalidation_Text',
      setting.name,
      'Setting name should match'
    );
    System.assertEquals(
      'Invalidation Text',
      setting.label,
      'Setting label should be formatted'
    );
    System.assertEquals('.invalid', setting.value, 'Should have default value');
    System.assertEquals(
      false,
      setting.isModified,
      'Should not be modified initially'
    );
  }

  @IsTest
  static void testSaveSettingsWithNoModifications() {
    Test.startTest();

    // Create settings with no modifications
    List<InvalidateEmailSettingsController.SettingWrapper> settings = new List<InvalidateEmailSettingsController.SettingWrapper>();
    settings.add(
      new InvalidateEmailSettingsController.SettingWrapper(
        'Invalidation_Text',
        'Invalidation Text',
        '.invalid'
      )
    );

    String settingsJson = JSON.serialize(settings);

    // Test saving settings with no modifications
    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.saveSettings(
      settingsJson
    );

    Test.stopTest();

    // Verify response
    System.assertEquals(
      false,
      response.success,
      'Should fail when no modifications'
    );
    System.assert(
      response.message.contains('No modified settings'),
      'Should indicate no modifications'
    );
  }

  @IsTest
  static void testSaveSettingsWithModifications() {
    Test.startTest();

    // Create settings with modifications
    List<InvalidateEmailSettingsController.SettingWrapper> settings = new List<InvalidateEmailSettingsController.SettingWrapper>();
    InvalidateEmailSettingsController.SettingWrapper setting = new InvalidateEmailSettingsController.SettingWrapper(
      'Invalidation_Text',
      'Invalidation Text',
      '.test'
    );
    setting.isModified = true;
    settings.add(setting);

    String settingsJson = JSON.serialize(settings);

    // Test saving settings with modifications
    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.saveSettings(
      settingsJson
    );

    Test.stopTest();

    // Verify response
    System.assert(response.success, 'Should succeed when modifications exist');
    System.assert(
      response.message.contains('deployment initiated'),
      'Should indicate deployment started'
    );
  }

  @IsTest
  static void testSaveSettingsWithInvalidJson() {
    Test.startTest();

    // Test with invalid JSON
    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.saveSettings(
      'invalid json'
    );

    Test.stopTest();

    // Verify response
    System.assertEquals(
      false,
      response.success,
      'Should fail with invalid JSON'
    );
    System.assert(
      response.message.contains('Error saving settings'),
      'Should indicate error'
    );
  }

  @IsTest
  static void testFormatLabel() {
    // Test the private formatLabel method indirectly through getCurrentSettings
    Test.startTest();

    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.getCurrentSettings();

    Test.stopTest();

    // Verify label formatting
    InvalidateEmailSettingsController.SettingWrapper setting = response.settings[0];
    System.assertEquals(
      'Invalidation Text',
      setting.label,
      'Underscores should be replaced with spaces'
    );
  }

  @IsTest
  static void testSettingWrapperConstructor() {
    // Test SettingWrapper constructor
    InvalidateEmailSettingsController.SettingWrapper setting = new InvalidateEmailSettingsController.SettingWrapper(
      'Test_Name',
      'Test Label',
      'Test Value'
    );

    System.assertEquals(
      'Test_Name',
      setting.name,
      'Name should be set correctly'
    );
    System.assertEquals(
      'Test Label',
      setting.label,
      'Label should be set correctly'
    );
    System.assertEquals(
      'Test Value',
      setting.value,
      'Value should be set correctly'
    );
    System.assertEquals(
      false,
      setting.isModified,
      'isModified should default to false'
    );
  }

  @IsTest
  static void testOperationResponseConstructor() {
    // Test OperationResponse constructor
    InvalidateEmailSettingsController.OperationResponse response = new InvalidateEmailSettingsController.OperationResponse(
      true,
      'Test message'
    );

    System.assertEquals(
      true,
      response.success,
      'Success should be set correctly'
    );
    System.assertEquals(
      'Test message',
      response.message,
      'Message should be set correctly'
    );
    System.assertEquals(
      null,
      response.settings,
      'Settings should default to null'
    );
  }

  @IsTest
  static void testSettingsDeployCallback() {
    // Test the deploy callback class
    InvalidateEmailSettingsController.SettingsDeployCallback callback = new InvalidateEmailSettingsController.SettingsDeployCallback();

    // Create a mock deploy result
    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.done = true;
    mockResult.success = true;

    // Test the callback (this mainly tests that it doesn't throw exceptions)
    Test.startTest();
    callback.handleResult(mockResult, null);
    Test.stopTest();

    // If we get here without exceptions, the test passes
    System.assert(true, 'Callback should handle result without exceptions');
  }
}
