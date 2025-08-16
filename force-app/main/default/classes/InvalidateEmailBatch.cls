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

  // Default constructor that processes all configured email fields
  public InvalidateEmailBatch() {
    // This will be handled in start() method by processing metadata
  }

  public Database.QueryLocator start(Database.BatchableContext context) {
    String query;

    // Create a comma spliced string of fields.
    String preppedFields = 'Id';
    String whereClause = ' WHERE Id!=\'\' AND (';
    for (String f : fields) {
      preppedFields = preppedFields + ',' + f;
      whereClause = whereClause + ' ' + f + '=\'\' OR';
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
          String currentEmail = (String) record.get(emailField);
          if (String.isNotBlank(currentEmail)) {
            // Invalidate the email by appending .invalid
            String invalidatedEmail = currentEmail + '.invalid';

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
    Map<String, Email_Invalidator_Fields__mdt> emailFields = Email_Invalidator_Fields__mdt.getAll();
    Map<String, Set<String>> objectFields = new Map<String, Set<String>>();
    Email_Invalidator_Fields__mdt currentField;

    // Create a collection of email fields by object.
    for (String invalidatorKey : emailFields.keySet()) {
      currentField = emailFields.get(invalidatorKey);
      // Ensure the current object is on the list.
      if (!objectFields.containsKey(currentField.Object__c)) {
        objectFields.put(currentField.Object__c, new Set<String>());
      }
      objectFields.get(currentField.Object__c).add(currentField.Field_Name__c);
    }

    // Now create batches for each object
    for (String objectName : objectFields.keySet()) {
      InvalidateEmailBatch batch = new InvalidateEmailBatch(
        objectName,
        objectFields.get(objectName)
      );
      Database.executeBatch(batch, 200);
    }
  }
}
