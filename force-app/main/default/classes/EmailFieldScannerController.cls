public with sharing class EmailFieldScannerController {
  @AuraEnabled
  public static EmailScanResponse startEmailFieldScanAura() {
    return executeEmailFieldScan();
  }

  @TestVisible
  private static EmailScanResponse executeEmailFieldScan() {
    EmailScanResponse response = new EmailScanResponse();

    try {
      EmailFieldScannerBatch.scanAllEmailFields();

      response.success = true;
      response.message = 'Email field scanning batch job started successfully. Results will be cached for your review instead of being deployed immediately.';
    } catch (Exception e) {
      response.success = false;
      response.message = 'Error starting email field scan: ' + e.getMessage();
      System.debug(
        'Error in EmailFieldScannerController.executeEmailFieldScan: ' +
        e.getMessage()
      );
    }

    return response;
  }

  /**
   * Gets cached email field scan results
   * @return CachedResultsResponse containing the cached scan results
   */
  @AuraEnabled
  public static CachedResultsResponse getCachedScanResults() {
    CachedResultsResponse response = new CachedResultsResponse();

    try {
      // Get the specific cached scan results record directly

      Email_Invalidator_Cache__mdt cacheRecord = [
        SELECT QualifiedApiName, Cached_Value__c, SystemModstamp
        FROM Email_Invalidator_Cache__mdt
        WHERE DeveloperName = 'Field_Scan'
      ];

      if (
        cacheRecord != null && String.isNotBlank(cacheRecord.Cached_Value__c)
      ) {
        System.debug('Cached Data: ' + cacheRecord.Cached_Value__c);
        // Parse the JSON payload
        Map<String, Object> cacheData = (Map<String, Object>) JSON.deserializeUntyped(
          cacheRecord.Cached_Value__c
        );

        response.success = true;
        response.scanDate = (String) cacheData.get('scanDate');
        response.lastModifiedDate = cacheRecord.SystemModstamp;
        response.totalObjectsScanned = (Integer) cacheData.get(
          'totalObjectsScanned'
        );
        response.totalEmailFieldsFound = (Integer) cacheData.get(
          'totalEmailFieldsFound'
        );
        response.existingFieldsSkipped = (Integer) cacheData.get(
          'existingFieldsSkipped'
        );

        // Convert the cached fields to a more usable format
        List<Object> cachedFields = (List<Object>) cacheData.get(
          'newEmailFields'
        );
        response.newEmailFields = new List<CachedEmailField>();

        for (Object fieldObj : cachedFields) {
          Map<String, Object> fieldData = (Map<String, Object>) fieldObj;
          CachedEmailField field = new CachedEmailField();
          field.objectName = (String) fieldData.get('objectName');
          field.fieldName = (String) fieldData.get('fieldName');
          field.fieldLabel = (String) fieldData.get('fieldLabel');
          field.discoveredDate = (String) fieldData.get('discoveredDate');
          field.selected = false; // Default to not selected
          response.newEmailFields.add(field);
        }

        response.message = 'Cached scan results loaded successfully';
      } else {
        response.success = false;
        response.message = cacheRecord == null
          ? 'No cached scan results found. Please run a scan first.'
          : 'Cache record exists but contains no data';
      }
    } catch (Exception e) {
      response.success = false;
      response.message = 'Error loading cached results: ' + e.getMessage();
      System.debug('Error in getCachedScanResults: ' + e.getMessage());
    }

    return response;
  }

  /**
   * Deploys selected email fields from cache to custom metadata
   * @param selectedFieldsJson JSON string containing selected fields to deploy
   * @return EmailScanResponse indicating success or failure
   */
  @AuraEnabled
  public static EmailScanResponse deploySelectedFields(
    String selectedFieldsJson
  ) {
    EmailScanResponse response = new EmailScanResponse();

    try {
      List<CachedEmailField> selectedFields = (List<CachedEmailField>) JSON.deserialize(
        selectedFieldsJson,
        List<CachedEmailField>.class
      );

      if (selectedFields.isEmpty()) {
        response.success = false;
        response.message = 'No fields selected for deployment';
        return response;
      }

      // Create deployment container
      Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();

      // Get existing metadata records to ensure unique names
      Map<String, Email_Invalidator_Fields__mdt> existingFields = Email_Invalidator_Fields__mdt.getAll();
      Set<String> usedMetadataNames = new Set<String>();

      for (Email_Invalidator_Fields__mdt existing : existingFields.values()) {
        usedMetadataNames.add(existing.DeveloperName);
      }

      Integer deployedCount = 0;

      for (CachedEmailField field : selectedFields) {
        if (field.selected) {
          // Create custom metadata record
          Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
          String uniqueRecordName = generateUniqueMetadataRecordName(
            field.objectName,
            field.fieldName,
            usedMetadataNames
          );

          customMetadata.fullName =
            'Email_Invalidator_Fields.' + uniqueRecordName;
          customMetadata.label = field.objectName + ' ' + field.fieldLabel;

          // Add field values
          Metadata.CustomMetadataValue objectField = new Metadata.CustomMetadataValue();
          objectField.field = 'Object__c';
          objectField.value = field.objectName;

          Metadata.CustomMetadataValue fieldNameField = new Metadata.CustomMetadataValue();
          fieldNameField.field = 'Field_Name__c';
          fieldNameField.value = field.fieldName;

          customMetadata.values = new List<Metadata.CustomMetadataValue>{
            objectField,
            fieldNameField
          };

          deployContainer.addMetadata(customMetadata);
          deployedCount++;
        }
      }

      if (deployedCount == 0) {
        response.success = false;
        response.message = 'No fields were marked as selected for deployment';
        return response;
      }

      // Deploy the metadata
      if (!Test.isRunningTest()) {
        Metadata.Operations.enqueueDeployment(
          deployContainer,
          new EmailFieldMetadataDeployCallback()
        );
      }

      response.success = true;
      response.message =
        'Successfully initiated deployment of ' +
        deployedCount +
        ' email field(s)';
    } catch (Exception e) {
      response.success = false;
      response.message = 'Error deploying selected fields: ' + e.getMessage();
      System.debug('Error in deploySelectedFields: ' + e.getMessage());
    }

    return response;
  }

  /**
   * Clears the cached scan results
   * @return EmailScanResponse indicating success or failure
   */
  @AuraEnabled
  public static EmailScanResponse clearCachedResults() {
    EmailScanResponse response = new EmailScanResponse();

    try {
      // Create deployment container to remove the cache record
      Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();

      // Create a custom metadata record with empty cached value to clear it
      Metadata.CustomMetadata cacheMetadata = new Metadata.CustomMetadata();
      cacheMetadata.fullName = 'Email_Invalidator_Cache.Field_Scan';
      cacheMetadata.label = 'Email Field Scan Results - Cleared';

      Metadata.CustomMetadataValue cachedValueField = new Metadata.CustomMetadataValue();
      cachedValueField.field = 'Cached_Value__c';
      cachedValueField.value = '{}'; // Empty JSON object

      cacheMetadata.values = new List<Metadata.CustomMetadataValue>{
        cachedValueField
      };
      deployContainer.addMetadata(cacheMetadata);

      // Deploy the cleared cache
      if (!Test.isRunningTest()) {
        Metadata.Operations.enqueueDeployment(
          deployContainer,
          new EmailFieldCacheDeployCallback()
        );
      }
      response.success = true;
      response.message = 'Cache cleared successfully';
    } catch (Exception e) {
      response.success = false;
      response.message = 'Error clearing cache: ' + e.getMessage();
      System.debug('Error in clearCachedResults: ' + e.getMessage());
    }

    return response;
  }

  /**
   * Generates a unique metadata record name for deployment
   */
  private static String generateUniqueMetadataRecordName(
    String objectName,
    String fieldName,
    Set<String> usedNames
  ) {
    // Generate a base metadata record name
    String baseName =
      objectName.replace('__c', '') +
      '_' +
      fieldName.replace('__c', '');

    // Replace any invalid characters
    baseName = baseName.replaceAll('[^a-zA-Z0-9_]', '_');

    // Ensure it doesn't start with a number
    if (baseName.substring(0, 1).isNumeric()) {
      baseName = 'Field_' + baseName;
    }

    // Truncate if too long (max 40 characters)
    if (baseName.length() > 40) {
      baseName = baseName.substring(0, 40);
    }

    // Ensure uniqueness
    String uniqueName = baseName;
    Integer counter = 1;

    while (usedNames.contains(uniqueName)) {
      String suffix = '_' + counter;
      if (baseName.length() + suffix.length() > 40) {
        String truncatedBase = baseName.substring(0, 40 - suffix.length());
        uniqueName = truncatedBase + suffix;
      } else {
        uniqueName = baseName + suffix;
      }
      counter++;
    }

    usedNames.add(uniqueName);
    return uniqueName;
  }

  // Response class for the AuraEnabled method
  public class EmailScanResponse {
    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String message;
  }

  // Response class for cached results
  public class CachedResultsResponse {
    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String message;

    @AuraEnabled
    public String scanDate;

    @AuraEnabled
    public DateTime lastModifiedDate;

    @AuraEnabled
    public Integer totalObjectsScanned;

    @AuraEnabled
    public Integer totalEmailFieldsFound;

    @AuraEnabled
    public Integer existingFieldsSkipped;

    @AuraEnabled
    public List<CachedEmailField> newEmailFields;
  }

  // Class to represent a cached email field
  public class CachedEmailField {
    @AuraEnabled
    public String objectName;

    @AuraEnabled
    public String fieldName;

    @AuraEnabled
    public String fieldLabel;

    @AuraEnabled
    public String discoveredDate;

    @AuraEnabled
    public Boolean selected;
  }
}
