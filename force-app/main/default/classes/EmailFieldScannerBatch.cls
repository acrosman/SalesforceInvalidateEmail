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
        WHERE IsQueryable = TRUE AND IsCustomizable = TRUE
        ORDER BY QualifiedApiName
      ];

      for (EntityDefinition entity : entities) {
        allObjects.add(entity.QualifiedApiName);
      }

      System.debug(
        'EmailFieldScannerBatch: Found ' +
          allObjects.size() +
          ' objects to scan'
      );
    } catch (Exception e) {
      errors.add('Error retrieving objects: ' + e.getMessage());
      System.debug('Error retrieving objects: ' + e.getMessage());
    }

    this.objectsToProcess = allObjects;
    return allObjects;
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

    // Generate and deploy custom metadata records for found email fields
    if (!emailFieldsFound.isEmpty()) {
      try {
        deployCustomMetadataRecords();
      } catch (Exception e) {
        errors.add('Error deploying custom metadata: ' + e.getMessage());
        System.debug('Error deploying custom metadata: ' + e.getMessage());
      }
    }

    // Send completion email
    sendCompletionEmail(context);
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

    for (EmailFieldInfo emailField : newEmailFields) {
      // Create custom metadata record
      Metadata.CustomMetadata customMetadata = new Metadata.CustomMetadata();
      customMetadata.fullName =
        'Email_Invalidator_Fields.' +
        generateMetadataRecordName(emailField.objectName, emailField.fieldName);
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
          emailField.fieldName
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
    // Generate a valid metadata record name
    String recordName =
      objectName.replace('__c', '') +
      '_' +
      fieldName.replace('__c', '');

    // Replace any invalid characters
    recordName = recordName.replaceAll('[^a-zA-Z0-9_]', '_');

    // Ensure it doesn't start with a number
    if (recordName.substring(0, 1).isNumeric()) {
      recordName = 'Field_' + recordName;
    }

    return recordName;
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
