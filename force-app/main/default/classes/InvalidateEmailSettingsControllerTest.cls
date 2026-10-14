/**
 * Test class for InvalidateEmailSettingsController
 */
@IsTest
private class InvalidateEmailSettingsControllerTest {
  private static final String SETTING_NAME = 'Invalidation_Text';
  private static final String SETTING_LABEL = 'Invalidation Text';

  private static InvalidateEmailSettingsController.SettingWrapper findSetting(
    InvalidateEmailSettingsController.OperationResponse response,
    String settingName
  ) {
    for (
      InvalidateEmailSettingsController.SettingWrapper setting : response.settings
    ) {
      if (setting.name == settingName) {
        return setting;
      }
    }
    return null;
  }

  @IsTest
  static void testGetCurrentSettings() {
    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.getCurrentSettings();

    Assert.isTrue(response.success, 'getCurrentSettings should succeed');
    Assert.isNotNull(response.settings, 'Settings should not be null');
    Assert.areEqual(1, response.settings.size(), 'Should have one setting');

    InvalidateEmailSettingsController.SettingWrapper setting = findSetting(
      response,
      SETTING_NAME
    );
    Assert.isNotNull(
      setting,
      'Response should include the ' + SETTING_NAME + ' setting'
    );
    Assert.areEqual(
      SETTING_LABEL,
      setting.label,
      'Setting label should be formatted'
    );
    // The org may have customized the value, so compare against what the
    // batches will actually use rather than a hard coded default.
    Assert.areEqual(
      InvalidateEmailSettings.getInvalidationText(),
      setting.value,
      'Controller and InvalidateEmailSettings should resolve the same value'
    );
    Assert.isFalse(setting.isModified, 'Should not be modified initially');
  }

  @IsTest
  static void testSaveSettingsWithNoModifications() {
    // Create settings with no modifications
    List<InvalidateEmailSettingsController.SettingWrapper> settings = new List<InvalidateEmailSettingsController.SettingWrapper>();
    settings.add(
      new InvalidateEmailSettingsController.SettingWrapper(
        SETTING_NAME,
        SETTING_LABEL,
        InvalidateEmailSettings.getInvalidationText()
      )
    );

    String settingsJson = JSON.serialize(settings);

    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.saveSettings(
      settingsJson
    );

    Assert.isFalse(response.success, 'Should fail when no modifications');
    Assert.isTrue(
      response.message.contains('No modified settings'),
      'Should indicate no modifications'
    );
  }

  @IsTest
  static void testSaveSettingsWithModifications() {
    // Create settings with modifications
    List<InvalidateEmailSettingsController.SettingWrapper> settings = new List<InvalidateEmailSettingsController.SettingWrapper>();
    InvalidateEmailSettingsController.SettingWrapper setting = new InvalidateEmailSettingsController.SettingWrapper(
      SETTING_NAME,
      SETTING_LABEL,
      '.test'
    );
    setting.isModified = true;
    settings.add(setting);

    String settingsJson = JSON.serialize(settings);

    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.saveSettings(
      settingsJson
    );

    Assert.isTrue(response.success, 'Should succeed when modifications exist');
    Assert.isTrue(
      response.message.contains('deployment initiated'),
      'Should indicate deployment started'
    );
  }

  @IsTest
  static void testSaveSettingsWithInvalidJson() {
    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.saveSettings(
      'invalid json'
    );

    Assert.isFalse(response.success, 'Should fail with invalid JSON');
    Assert.isTrue(
      response.message.contains('Error saving settings'),
      'Should indicate error'
    );
  }

  @IsTest
  static void testFormatLabel() {
    // Test the private formatLabel method indirectly through getCurrentSettings
    InvalidateEmailSettingsController.OperationResponse response = InvalidateEmailSettingsController.getCurrentSettings();

    for (
      InvalidateEmailSettingsController.SettingWrapper setting : response.settings
    ) {
      Assert.areEqual(
        setting.name.replace('_', ' '),
        setting.label,
        'Underscores should be replaced with spaces'
      );
    }
  }

  @IsTest
  static void testSettingWrapperConstructor() {
    InvalidateEmailSettingsController.SettingWrapper setting = new InvalidateEmailSettingsController.SettingWrapper(
      'Test_Name',
      'Test Label',
      'Test Value'
    );

    Assert.areEqual('Test_Name', setting.name, 'Name should be set correctly');
    Assert.areEqual(
      'Test Label',
      setting.label,
      'Label should be set correctly'
    );
    Assert.areEqual(
      'Test Value',
      setting.value,
      'Value should be set correctly'
    );
    Assert.isFalse(setting.isModified, 'isModified should default to false');
  }

  @IsTest
  static void testOperationResponseConstructor() {
    InvalidateEmailSettingsController.OperationResponse response = new InvalidateEmailSettingsController.OperationResponse(
      true,
      'Test message'
    );

    Assert.isTrue(response.success, 'Success should be set correctly');
    Assert.areEqual(
      'Test message',
      response.message,
      'Message should be set correctly'
    );
    Assert.isNull(response.settings, 'Settings should default to null');
  }

  @IsTest
  static void testSettingsDeployCallback() {
    InvalidateEmailSettingsController.SettingsDeployCallback callback = new InvalidateEmailSettingsController.SettingsDeployCallback();

    // Create a mock deploy result
    Metadata.DeployResult mockResult = new Metadata.DeployResult();
    mockResult.done = true;
    mockResult.success = true;

    InvalidateEmailSettings.getInvalidationText();
    callback.handleResult(mockResult, null);

    // A successful deploy clears the cache; the next read must reload a value.
    Assert.isTrue(
      String.isNotBlank(InvalidateEmailSettings.getInvalidationText()),
      'Invalidation text should reload after the cache is cleared'
    );
  }
}
