/**
 * Controller for the invalidateEmailSettings LWC component
 * Handles loading, saving, and deploying Email Invalidator settings
 */
public with sharing class InvalidateEmailSettingsController {
  /**
   * Wrapper class for settings data
   */
  public class SettingWrapper {
    @AuraEnabled
    public String name { get; set; }
    @AuraEnabled
    public String label { get; set; }
    @AuraEnabled
    public String value { get; set; }
    @AuraEnabled
    public Boolean isModified { get; set; }

    public SettingWrapper(String name, String label, String value) {
      this.name = name;
      this.label = label;
      this.value = value;
      this.isModified = false;
    }
  }

  /**
   * Response wrapper for operations
   */
  public class OperationResponse {
    @AuraEnabled
    public Boolean success { get; set; }
    @AuraEnabled
    public String message { get; set; }
    @AuraEnabled
    public List<SettingWrapper> settings { get; set; }

    public OperationResponse(Boolean success, String message) {
      this.success = success;
      this.message = message;
    }
  }

  // Known settings that the component should manage
  private static final List<String> KNOWN_SETTINGS = new List<String>{
    'Invalidation_Text'
  };

  /**
   * Gets all current settings values
   * @return OperationResponse containing the current settings
   */
  @AuraEnabled(cacheable=true)
  public static OperationResponse getCurrentSettings() {
    try {
      List<SettingWrapper> settings = new List<SettingWrapper>();

      // Get all existing settings
      Map<String, Email_Invalidator_Settings__mdt> existingSettings = Email_Invalidator_Settings__mdt.getAll();

      // Process each known setting
      for (String settingName : KNOWN_SETTINGS) {
        String label = formatLabel(settingName);
        String value = '';

        if (existingSettings.containsKey(settingName)) {
          Email_Invalidator_Settings__mdt setting = existingSettings.get(
            settingName
          );
          value = setting.Setting_Value__c != null
            ? setting.Setting_Value__c
            : '';
        }

        settings.add(new SettingWrapper(settingName, label, value));
      }

      OperationResponse response = new OperationResponse(
        true,
        'Settings loaded successfully'
      );
      response.settings = settings;
      return response;
    } catch (Exception e) {
      System.debug('Error loading settings: ' + e.getMessage());
      return new OperationResponse(
        false,
        'Error loading settings: ' + e.getMessage()
      );
    }
  }

  /**
   * Saves settings by creating/updating custom metadata records
   * @param settingsJson JSON string containing the settings to save
   * @return OperationResponse indicating success or failure
   */
  @AuraEnabled
  public static OperationResponse saveSettings(String settingsJson) {
    try {
      List<SettingWrapper> settings = (List<SettingWrapper>) JSON.deserialize(
        settingsJson,
        List<SettingWrapper>.class
      );

      // Create metadata records for deployment
      List<Metadata.CustomMetadata> customMetadataList = new List<Metadata.CustomMetadata>();

      for (SettingWrapper setting : settings) {
        if (setting.isModified) {
          Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
          customMetadata.fullName =
            'Email_Invalidator_Settings.' + setting.name;
          customMetadata.label = setting.label;

          Metadata.CustomMetadataValue customField = new Metadata.CustomMetadataValue();
          customField.field = 'Setting_Value__c';
          customField.value = setting.value;

          customMetadata.values = new List<Metadata.CustomMetadataValue>{
            customField
          };
          customMetadataList.add(customMetadata);
        }
      }

      if (customMetadataList.isEmpty()) {
        return new OperationResponse(false, 'No modified settings to save');
      }

      // Deploy the metadata
      Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();
      for (Metadata.CustomMetadata cmd : customMetadataList) {
        deployContainer.addMetadata(cmd);
      }

      // Create callback for deployment
      SettingsDeployCallback callback = new SettingsDeployCallback();
      if (!Test.isRunningTest()) {
        Id deploymentId = Metadata.Operations.enqueueDeployment(
          deployContainer,
          callback
        );
      }
      return new OperationResponse(
        true,
        'Settings deployment initiated successfully. Changes will be applied automatically when deployment completes.'
      );
    } catch (Exception e) {
      System.debug('Error saving settings: ' + e.getMessage());
      return new OperationResponse(
        false,
        'Error saving settings: ' + e.getMessage()
      );
    }
  }

  /**
   * Formats a setting name into a readable label
   * @param settingName The setting name to format
   * @return String formatted label
   */
  private static String formatLabel(String settingName) {
    return settingName.replace('_', ' ');
  }

  /**
   * Callback class for metadata deployment
   */
  public class SettingsDeployCallback implements Metadata.DeployCallback {
    public void handleResult(
      Metadata.DeployResult result,
      Metadata.DeployCallbackContext context
    ) {
      if (result.done) {
        if (result.success) {
          System.debug('Settings deployment completed successfully');
          // Clear the cache in InvalidateEmailSettings
          InvalidateEmailSettings.clearCache();
        } else {
          System.debug('Settings deployment failed: ' + result);
        }
      }
    }
  }
}
