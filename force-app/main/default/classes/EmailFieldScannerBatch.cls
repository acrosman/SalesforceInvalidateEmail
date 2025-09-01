public without sharing class EmailFieldScannerBatch implements Database.Batchable<String>, Database.Stateful {
  private List<String> objectsToProcess;
  @TestVisible
  private List<EmailFieldInfo> emailFieldsFound;
  @TestVisible
  private Integer totalObjectsProcessed = 0;
  @TestVisible
  private Integer totalEmailFieldsFound = 0;
  @TestVisible
  private List<String> errors = new List<String>();

  // Inner class to hold email field information
  public class EmailFieldInfo {
    public String objectName;
    public String fieldName;
    public String fieldLabel;

    public EmailFieldInfo(
      String objectName,
      String fieldName,
      String fieldLabel
    ) {
      this.objectName = objectName;
      this.fieldName = fieldName;
      this.fieldLabel = fieldLabel;
    }
  }

  public EmailFieldScannerBatch() {
    this.emailFieldsFound = new List<EmailFieldInfo>();
  }

  public Iterable<String> start(Database.BatchableContext context) {
    // Get all objects in the org
    List<String> allObjects = new List<String>();

    try {
      // Query all entity definitions to get object names
      List<EntityDefinition> entities = [
        SELECT QualifiedApiName, Label, IsCustomizable
        FROM EntityDefinition
        WHERE
          IsQueryable = TRUE
          AND IsCustomizable = TRUE
          AND IsDeprecatedAndHidden = FALSE
        WITH SECURITY_ENFORCED
        ORDER BY QualifiedApiName
      ];

      // For testing we need to cut this down to just ten objects.
      if (Test.isRunningTest()) {
        while (entities.size() > 10) {
          entities.remove(0);
        }
      }

      // Filter objects to only include those valid for Custom Metadata
      List<String> validObjects = filterValidCustomMetadataObjects(entities);
      allObjects.addAll(validObjects);

      System.debug(
        'EmailFieldScannerBatch: Found ' +
          entities.size() +
          ' total objects, filtered to ' +
          allObjects.size() +
          ' valid objects for Custom Metadata'
      );
    } catch (Exception e) {
      errors.add('Error retrieving objects: ' + e.getMessage());
      System.debug('Error retrieving objects: ' + e.getMessage());
    }

    this.objectsToProcess = allObjects;
    return allObjects;
  }

  @TestVisible
  private List<String> filterValidCustomMetadataObjects(
    List<EntityDefinition> entities
  ) {
    List<String> validObjects = new List<String>();

    for (EntityDefinition entity : entities) {
      // Skip objects that are not valid for Custom Metadata
      validObjects.add(entity.QualifiedApiName);
    }

    return validObjects;
  }

  public void execute(Database.BatchableContext context, List<String> scope) {
    for (String objectName : scope) {
      try {
        scanObjectForEmailFields(objectName);
        totalObjectsProcessed++;
      } catch (Exception e) {
        errors.add(
          'Error scanning object ' + objectName + ': ' + e.getMessage()
        );
        System.debug(
          'Error scanning object ' + objectName + ': ' + e.getMessage()
        );
      }
    }
  }

  @TestVisible
  private void scanObjectForEmailFields(String objectName) {
    try {
      // Get field definitions for this object
      List<FieldDefinition> fields = [
        SELECT
          QualifiedApiName,
          Label,
          DataType,
          EntityDefinition.QualifiedApiName
        FROM FieldDefinition
        WHERE
          EntityDefinition.QualifiedApiName = :objectName
          AND DataType = 'Email'
          AND IsCompound = FALSE
      ];

      for (FieldDefinition field : fields) {
        EmailFieldInfo emailField = new EmailFieldInfo(
          objectName,
          field.QualifiedApiName,
          field.Label
        );
        emailFieldsFound.add(emailField);
        totalEmailFieldsFound++;

        System.debug(
          'Found email field: ' + objectName + '.' + field.QualifiedApiName
        );
      }
    } catch (Exception e) {
      errors.add(
        'Error querying fields for object ' + objectName + ': ' + e.getMessage()
      );
      System.debug(
        'Error querying fields for object ' + objectName + ': ' + e.getMessage()
      );
    }
  }

  public void finish(Database.BatchableContext context) {
    System.debug('EmailFieldScannerBatch completed');
    System.debug('Objects processed: ' + totalObjectsProcessed);
    System.debug('Email fields found: ' + totalEmailFieldsFound);

    // Cache the found email fields instead of deploying immediately
    if (!emailFieldsFound.isEmpty()) {
      try {
        cacheEmailFieldResults();
      } catch (Exception e) {
        errors.add('Error caching email field results: ' + e.getMessage());
        System.debug('Error caching email field results: ' + e.getMessage());
      }
    }

    // Send completion email
    sendCompletionEmail(context);
  }

  @TestVisible
  private void cacheEmailFieldResults() {
    // Get existing custom metadata records to filter out duplicates
    Set<String> existingRecords = new Set<String>();
    Map<String, Email_Invalidator_Fields__mdt> existingFields = Email_Invalidator_Fields__mdt.getAll();

    for (Email_Invalidator_Fields__mdt existing : existingFields.values()) {
      String key = existing.Object__c + '.' + existing.Field_Name__c;
      existingRecords.add(key);
    }

    // Filter out existing records and prepare new ones for caching
    List<EmailFieldInfo> newEmailFields = new List<EmailFieldInfo>();

    for (EmailFieldInfo emailField : emailFieldsFound) {
      String key = emailField.objectName + '.' + emailField.fieldName;

      // Skip if record already exists
      if (existingRecords.contains(key)) {
        System.debug('Skipping existing record: ' + key);
        continue;
      }

      newEmailFields.add(emailField);
    }

    if (newEmailFields.isEmpty()) {
      System.debug(
        'No new email fields to cache - all found fields already have metadata records'
      );
      return;
    }

    // Convert email fields to JSON for caching
    List<Map<String, Object>> emailFieldsForCache = new List<Map<String, Object>>();

    for (EmailFieldInfo emailField : newEmailFields) {
      Map<String, Object> fieldData = new Map<String, Object>();
      fieldData.put('objectName', emailField.objectName);
      fieldData.put('fieldName', emailField.fieldName);
      fieldData.put('fieldLabel', emailField.fieldLabel);
      fieldData.put('discoveredDate', System.now().format());
      emailFieldsForCache.add(fieldData);
    }

    // Create the cache payload
    Map<String, Object> cachePayload = new Map<String, Object>();
    cachePayload.put('scanDate', System.now().format());
    cachePayload.put('totalObjectsScanned', totalObjectsProcessed);
    cachePayload.put('totalEmailFieldsFound', totalEmailFieldsFound);
    cachePayload.put('newEmailFields', emailFieldsForCache);
    cachePayload.put(
      'existingFieldsSkipped',
      emailFieldsFound.size() - newEmailFields.size()
    );

    String jsonPayload = JSON.serialize(cachePayload);
    System.debug('Caching Payload: ' + jsonPayload);

    // Store in cache using metadata deployment
    Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();

    Metadata.CustomMetadata cacheMetadata = new Metadata.CustomMetadata();
    cacheMetadata.fullName = 'Email_Invalidator_Cache.Field_Scan';
    cacheMetadata.label = 'Email Field Scan';

    Metadata.CustomMetadataValue cachedValueField = new Metadata.CustomMetadataValue();
    cachedValueField.field = 'Cached_Value__c';
    cachedValueField.value = jsonPayload;

    cacheMetadata.values = new List<Metadata.CustomMetadataValue>{
      cachedValueField
    };
    deployContainer.addMetadata(cacheMetadata);

    // Deploy the cache metadata
    if (!Test.isRunningTest()) {
      try {
        Metadata.Operations.enqueueDeployment(
          deployContainer,
          new EmailFieldCacheDeployCallback()
        );
        System.debug(
          'Cached ' +
            newEmailFields.size() +
            ' new email fields for user review'
        );
      } catch (Exception e) {
        errors.add('Error deploying cache metadata: ' + e.getMessage());
        System.debug('Error deploying cache metadata: ' + e.getMessage());
      }
    } else {
      System.debug(
        'Test context - skipping cache deployment of ' +
          newEmailFields.size() +
          ' fields'
      );
    }
  }

  @TestVisible
  private void deployCustomMetadataRecords() {
    // Get existing custom metadata records to avoid duplicates
    Set<String> existingRecords = new Set<String>();
    Map<String, Email_Invalidator_Fields__mdt> existingFields = Email_Invalidator_Fields__mdt.getAll();

    for (Email_Invalidator_Fields__mdt existing : existingFields.values()) {
      String key = existing.Object__c + '.' + existing.Field_Name__c;
      existingRecords.add(key);
    }

    // Filter out existing records and prepare new ones for deployment
    List<EmailFieldInfo> newEmailFields = new List<EmailFieldInfo>();

    for (EmailFieldInfo emailField : emailFieldsFound) {
      String key = emailField.objectName + '.' + emailField.fieldName;

      // Skip if record already exists
      if (existingRecords.contains(key)) {
        System.debug('Skipping existing record: ' + key);
        continue;
      }

      newEmailFields.add(emailField);
    }

    if (newEmailFields.isEmpty()) {
      System.debug(
        'No new email fields to deploy - all found fields already have metadata records'
      );
      return;
    }

    // Create deployment container
    Metadata.DeployContainer deployContainer = new Metadata.DeployContainer();

    // Track used metadata record names to ensure uniqueness
    Set<String> usedMetadataNames = new Set<String>();

    // Add existing metadata record names to the used names set
    for (Email_Invalidator_Fields__mdt existing : existingFields.values()) {
      usedMetadataNames.add(existing.DeveloperName);
    }

    for (EmailFieldInfo emailField : newEmailFields) {
      // Create custom metadata record
      Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
      String uniqueRecordName = generateUniqueMetadataRecordName(
        emailField.objectName,
        emailField.fieldName,
        usedMetadataNames
      );

      customMetadata.fullName = 'Email_Invalidator_Fields.' + uniqueRecordName;
      customMetadata.label =
        emailField.objectName +
        ' ' +
        emailField.fieldLabel;

      // Add field values
      Metadata.CustomMetadataValue objectField = new Metadata.CustomMetadataValue();
      objectField.field = 'Object__c';
      objectField.value = emailField.objectName;

      Metadata.CustomMetadataValue fieldNameField = new Metadata.CustomMetadataValue();
      fieldNameField.field = 'Field_Name__c';
      fieldNameField.value = emailField.fieldName;

      customMetadata.values = new List<Metadata.CustomMetadataValue>{
        objectField,
        fieldNameField
      };

      // Add to deployment container
      deployContainer.addMetadata(customMetadata);

      System.debug(
        'Added to deployment: ' +
          emailField.objectName +
          '.' +
          emailField.fieldName +
          ' with metadata name: ' +
          uniqueRecordName
      );
    }

    // Deploy the metadata
    if (!Test.isRunningTest()) {
      try {
        Metadata.Operations.enqueueDeployment(
          deployContainer,
          new EmailFieldMetadataDeployCallback()
        );
        System.debug(
          'Enqueued deployment of ' +
            newEmailFields.size() +
            ' new custom metadata records'
        );
      } catch (Exception e) {
        errors.add('Error enqueuing metadata deployment: ' + e.getMessage());
        System.debug('Error enqueuing metadata deployment: ' + e.getMessage());
      }
    } else {
      System.debug(
        'Test context - skipping actual deployment of ' +
          newEmailFields.size() +
          ' records'
      );
    }
  }

  @TestVisible
  private String generateMetadataRecordName(
    String objectName,
    String fieldName
  ) {
    return generateUniqueMetadataRecordName(
      objectName,
      fieldName,
      new Set<String>()
    );
  }

  @TestVisible
  private String generateUniqueMetadataRecordName(
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

    // Salesforce Custom Metadata record names have a maximum length of 40 characters
    // If the name is too long, truncate it while preserving uniqueness
    if (baseName.length() > 40) {
      baseName = truncateMetadataName(objectName, fieldName, baseName);
    }

    // Ensure uniqueness by adding a counter if needed
    String uniqueName = baseName;
    Integer counter = 1;

    while (usedNames.contains(uniqueName)) {
      String suffix = '_' + counter;
      // Ensure the name with suffix doesn't exceed 40 characters
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

  @TestVisible
  private String truncateMetadataName(
    String objectName,
    String fieldName,
    String baseName
  ) {
    // Try to preserve both object and field parts by truncating each proportionally
    String objectPart = objectName.replace('__c', '');
    String fieldPart = fieldName.replace('__c', '');

    // Calculate available space (40 chars - 1 for underscore - potential 'Field_' prefix)
    Integer maxLength = baseName.startsWith('Field_') ? 34 : 39; // 40 - 6 for 'Field_' or 40 - 1 for underscore
    Integer availableLength = baseName.startsWith('Field_')
      ? maxLength - 6
      : maxLength;

    // Split available length between object and field parts
    Integer objectMaxLength = Math.min(
      objectPart.length(),
      availableLength / 2
    );
    Integer fieldMaxLength = availableLength - objectMaxLength - 1; // -1 for underscore

    // Ensure minimum lengths
    if (objectMaxLength < 3 && objectPart.length() >= 3) {
      objectMaxLength = 3;
      fieldMaxLength = availableLength - 4; // -3 for object, -1 for underscore
    }
    if (fieldMaxLength < 3 && fieldPart.length() >= 3) {
      fieldMaxLength = 3;
      objectMaxLength = availableLength - 4; // -3 for field, -1 for underscore
    }

    // Truncate parts
    String truncatedObjectPart = objectPart.length() > objectMaxLength
      ? objectPart.substring(0, objectMaxLength)
      : objectPart;
    String truncatedFieldPart = fieldPart.length() > fieldMaxLength
      ? fieldPart.substring(0, fieldMaxLength)
      : fieldPart;

    String truncatedName = truncatedObjectPart + '_' + truncatedFieldPart;

    // Add Field_ prefix if it was there originally
    if (baseName.startsWith('Field_')) {
      truncatedName = 'Field_' + truncatedName;
      // If still too long after adding prefix, truncate further
      if (truncatedName.length() > 40) {
        truncatedName = truncatedName.substring(0, 40);
      }
    }

    return truncatedName;
  }

  @TestVisible
  private void sendCompletionEmail(Database.BatchableContext context) {
    AsyncApexJob job = [
      SELECT
        Id,
        Status,
        NumberOfErrors,
        JobItemsProcessed,
        TotalJobItems,
        CreatedBy.Email
      FROM AsyncApexJob
      WHERE Id = :context.getJobId()
    ];

    if (String.isNotBlank(job.CreatedBy.Email)) {
      try {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ job.CreatedBy.Email });
        email.setSubject('Email Field Scanner Batch Job Completed');

        String emailBody = 'The email field scanner batch job has completed.\n\n';
        emailBody += 'Job Status: ' + job.Status + '\n';
        emailBody += 'Objects Processed: ' + totalObjectsProcessed + '\n';
        emailBody += 'Email Fields Found: ' + totalEmailFieldsFound + '\n';

        // Count new vs existing fields
        Set<String> existingRecords = new Set<String>();
        Map<String, Email_Invalidator_Fields__mdt> existingFields = Email_Invalidator_Fields__mdt.getAll();

        for (Email_Invalidator_Fields__mdt existing : existingFields.values()) {
          String key = existing.Object__c + '.' + existing.Field_Name__c;
          existingRecords.add(key);
        }

        Integer newFieldsCount = 0;
        Integer existingFieldsCount = 0;

        for (EmailFieldInfo field : emailFieldsFound) {
          String key = field.objectName + '.' + field.fieldName;
          if (existingRecords.contains(key)) {
            existingFieldsCount++;
          } else {
            newFieldsCount++;
          }
        }

        emailBody += 'New Fields to Deploy: ' + newFieldsCount + '\n';
        emailBody += 'Existing Fields Skipped: ' + existingFieldsCount + '\n';

        if (job.NumberOfErrors > 0 || !errors.isEmpty()) {
          emailBody += 'Number of Errors: ' + job.NumberOfErrors + '\n';
          if (!errors.isEmpty()) {
            emailBody += '\nDetailed Errors:\n';
            for (String error : errors) {
              emailBody += '- ' + error + '\n';
            }
          }
        }

        emailBody += '\nAll email fields found:\n';
        for (EmailFieldInfo field : emailFieldsFound) {
          String key = field.objectName + '.' + field.fieldName;
          String status = existingRecords.contains(key)
            ? ' (existing)'
            : ' (new)';
          emailBody +=
            '- ' +
            field.objectName +
            '.' +
            field.fieldName +
            ' (' +
            field.fieldLabel +
            ')' +
            status +
            '\n';
        }

        email.setPlainTextBody(emailBody);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
      } catch (Exception e) {
        System.debug('Error sending completion email: ' + e.getMessage());
      }
    }
  }

  // Static method to start the email field scanning process
  public static void scanAllEmailFields() {
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();
    Database.executeBatch(batch, 10); // Process 10 objects at a time
  }
}
