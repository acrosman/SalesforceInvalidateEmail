public without sharing class InvalidateEmailBatch implements Database.Batchable<SObject>, Database.Stateful {
  private String objectName;
  private Set<String> fields;
  private Integer recordsProcessed = 0;
  private Integer recordsUpdated = 0;
  private List<String> errors = new List<String>();

  // Constructor for processing a specific object and field
  public InvalidateEmailBatch(String objectName, Set<String> fields) {
    this.objectName = objectName;
    this.fields = fields;
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    String query;

    // Create a comma spliced string of fields.
    String preppedFields = 'Id';
    String whereClause = ' WHERE Id!=\'\' AND (';
    for (String f : fields) {
      preppedFields = preppedFields + ',' + f;
      whereClause = whereClause + ' ' + f + '<>\'\' OR';
    }
    whereClause = whereClause + ' Id=\'\')';

    if (String.isNotBlank(objectName) && preppedFields != 'Id') {
      // Process specific object and field
      query = 'SELECT ' + preppedFields + ' FROM ' + objectName + whereClause;
    }

    System.debug('InvalidateEmailBatch query: ' + query);
    return Database.getQueryLocator(query);
  }

  public void execute(Database.BatchableContext context, List<SObject> scope) {
    List<SObject> recordsToUpdate = new List<SObject>();

    for (SObject record : scope) {
      for (String emailField : fields) {
        try {
          System.debug('Processing record: ' + record);
          String currentEmail = (String) record.get(emailField);
          String invalidationText = InvalidateEmailSettings.getInvalidationText();
          if (
            String.isNotBlank(currentEmail) &&
            !currentEmail.endsWith(invalidationText)
          ) {
            // Invalidate the email by appending the configured invalidation text
            String invalidatedEmail = currentEmail + invalidationText;

            record.put(emailField, invalidatedEmail);
            recordsToUpdate.add(record);
            recordsProcessed++;
          }
        } catch (Exception e) {
          errors.add(
            'Error processing record ' + record.Id + ': ' + e.getMessage()
          );
          System.debug('Error processing record: ' + e.getMessage());
        }
      }
    }

    if (!recordsToUpdate.isEmpty()) {
      try {
        Database.SaveResult[] results = Database.update(recordsToUpdate, false);

        for (Integer i = 0; i < results.size(); i++) {
          if (results[i].isSuccess()) {
            recordsUpdated++;
          } else {
            for (Database.Error error : results[i].getErrors()) {
              errors.add(
                'Error updating record ' +
                  recordsToUpdate[i].Id +
                  ': ' +
                  error.getMessage()
              );
            }
          }
        }
      } catch (Exception e) {
        errors.add('Batch update error: ' + e.getMessage());
        System.debug('Batch update error: ' + e.getMessage());
      }
    }
  }

  public void finish(Database.BatchableContext context) {
    System.debug('InvalidateEmailBatch completed');
    System.debug('Records processed: ' + recordsProcessed);
    System.debug('Records updated: ' + recordsUpdated);

    if (!errors.isEmpty()) {
      System.debug('Errors encountered: ' + errors.size());
      for (String error : errors) {
        System.debug('Error: ' + error);
      }
    }

    // Send completion email to the user who started the batch
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
        email.setSubject('Email Invalidation Batch Job Completed');

        String emailBody = 'The email invalidation batch job has completed.\n\n';
        emailBody += 'Job Status: ' + job.Status + '\n';
        emailBody += 'Total Job Items: ' + job.TotalJobItems + '\n';
        emailBody += 'Job Items Processed: ' + job.JobItemsProcessed + '\n';
        emailBody += 'Records Updated: ' + recordsUpdated + '\n';

        if (job.NumberOfErrors > 0 || !errors.isEmpty()) {
          emailBody += 'Number of Errors: ' + job.NumberOfErrors + '\n';
          if (!errors.isEmpty()) {
            emailBody += '\nDetailed Errors:\n';
            for (String error : errors) {
              emailBody += '- ' + error + '\n';
            }
          }
        }

        email.setPlainTextBody(emailBody);
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
      } catch (Exception e) {
        System.debug('Error sending completion email: ' + e.getMessage());
      }
    }
  }

  // Static method to process all configured email fields from custom metadata
  public static void invalidateAllConfiguredEmails() {
    // Fetch the metadata and extract the field information.
    Map<String, Email_Invalidator_Fields__mdt> emailFields = Email_Invalidator_Fields__mdt.getAll();
    Map<String, Set<String>> objectsWithFields = getFieldDetails(emailFields);

    // Create batches for each object
    // TODO: Protect against the 60 batch limit.
    for (String objectName : objectsWithFields.keySet()) {
      InvalidateEmailBatch batch = new InvalidateEmailBatch(
        objectName,
        objectsWithFields.get(objectName)
      );
      Database.executeBatch(batch, 200);
    }
  }

  // Helper method to extract the object and field information
  // from the metadata in a consistent form. The records use
  // 'DurableIds' which are names for standard fields, and Ids
  // for custom fields. We need names for everything.
  public static Map<String, Set<String>> getFieldDetails(
    Map<String, Email_Invalidator_Fields__mdt> fieldMetaList
  ) {
    Map<String, Set<String>> objectFields = new Map<String, Set<String>>();
    Email_Invalidator_Fields__mdt currentField;
    String objectApiName;
    List<String> fieldDurableIds = new List<String>();

    // Prep the map we'll return with object names as keys, and extra
    // the Durableids from the metadata to query in one shot.
    for (String invalidatorKey : fieldMetaList.keySet()) {
      currentField = fieldMetaList.get(invalidatorKey);

      fieldDurableIds.add(currentField.Field_Name__c);
    }

    // Now get all the EntityParticles based on the list of DurableIds
    for (EntityParticle ep : [
      SELECT
        QualifiedApiName,
        DataType,
        EntityDefinition.QualifiedApiName,
        DurableId
      FROM EntityParticle
      WHERE DurableId IN :fieldDurableIds
    ]) {
      System.debug(ep);
      objectApiName = ep.EntityDefinition.QualifiedApiName;
      if (!objectFields.containsKey(objectApiName)) {
        objectFields.put(objectApiName, new Set<String>());
      }

      objectFields.get(objectApiName).add(ep.QualifiedApiName);
    }

    return objectFields;
  }
}
