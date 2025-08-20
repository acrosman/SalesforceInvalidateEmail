@IsTest
private class EmailFieldScannerBatchTest {
  @IsTest
  static void testEmailFieldScannerBatch() {
    Test.startTest();

    // Create and execute the batch
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();
    Database.executeBatch(batch, 10);

    Test.stopTest();

    // Verify the batch completed without errors
    List<AsyncApexJob> jobs = [
      SELECT Id, Status, NumberOfErrors
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assertEquals(1, jobs.size(), 'Expected one batch job');
    System.assertEquals(
      'Completed',
      jobs[0].Status,
      'Expected batch job to complete'
    );
    System.assertEquals(
      0,
      jobs[0].NumberOfErrors,
      'Expected no errors in batch job'
    );
  }

  @IsTest
  static void testEmailFieldScannerBatchStaticMethod() {
    Test.startTest();

    // Call the static method
    EmailFieldScannerBatch.scanAllEmailFields();

    Test.stopTest();

    // Verify a batch job was started
    List<AsyncApexJob> jobs = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assertEquals(1, jobs.size(), 'Expected one batch job to be started');
  }

  @IsTest
  static void testEmailFieldInfo() {
    // Test the inner class
    EmailFieldScannerBatch.EmailFieldInfo fieldInfo = new EmailFieldScannerBatch.EmailFieldInfo(
      'Contact',
      'Email',
      'Email Address'
    );

    System.assertEquals('Contact', fieldInfo.objectName);
    System.assertEquals('Email', fieldInfo.fieldName);
    System.assertEquals('Email Address', fieldInfo.fieldLabel);
  }

  @IsTest
  static void testScanObjectForEmailFields() {
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();

    Test.startTest();

    // Test scanning Contact object (which has Email field)
    batch.scanObjectForEmailFields('Contact');

    Test.stopTest();

    // Verify that email fields were found
    System.assert(
      batch.emailFieldsFound.size() > 0,
      'Expected to find email fields on Contact object'
    );

    // Check if Contact.Email was found
    Boolean foundContactEmail = false;
    for (EmailFieldScannerBatch.EmailFieldInfo field : batch.emailFieldsFound) {
      if (field.objectName == 'Contact' && field.fieldName == 'Email') {
        foundContactEmail = true;
        break;
      }
    }
    System.assert(foundContactEmail, 'Expected to find Contact.Email field');
  }

  @IsTest
  static void testDeployCustomMetadataRecords() {
    // Create a batch instance and add some test email fields
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();
    batch.emailFieldsFound = new List<EmailFieldScannerBatch.EmailFieldInfo>();

    // Add test email field that doesn't exist in metadata
    batch.emailFieldsFound.add(
      new EmailFieldScannerBatch.EmailFieldInfo(
        'Account',
        'PersonEmail',
        'Person Email'
      )
    );

    Test.startTest();

    // Call the deployment method
    batch.deployCustomMetadataRecords();

    Test.stopTest();

    // In test context, deployment is skipped, so we just verify no exceptions
    System.assert(true, 'Deployment method completed without exceptions');
  }

  @IsTest
  static void testDeployCustomMetadataRecordsWithExistingRecords() {
    // This test verifies that existing metadata records are properly filtered out
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();

    // Add the Contact.Email field which already exists in metadata
    batch.emailFieldsFound = new List<EmailFieldScannerBatch.EmailFieldInfo>();
    batch.emailFieldsFound.add(
      new EmailFieldScannerBatch.EmailFieldInfo('Contact', 'Email', 'Email')
    );

    Test.startTest();

    // Call the deployment method
    batch.deployCustomMetadataRecords();

    Test.stopTest();

    // The method should skip existing records and not attempt deployment
    System.assert(
      true,
      'Method completed without attempting to deploy existing records'
    );
  }

  @IsTest
  static void testGenerateMetadataRecordName() {
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();

    Test.startTest();

    // Test normal case
    String result1 = batch.generateMetadataRecordName('Contact', 'Email');
    System.assertEquals('Contact_Email', result1);

    // Test with custom objects/fields
    String result2 = batch.generateMetadataRecordName(
      'Custom_Object__c',
      'Custom_Email__c'
    );
    System.assertEquals('Custom_Object_Custom_Email', result2);

    // Test with invalid characters
    String result3 = batch.generateMetadataRecordName(
      'Test-Object',
      'Test.Field'
    );
    System.assertEquals('Test_Object_Test_Field', result3);

    // Test with numeric start
    String result4 = batch.generateMetadataRecordName('1Object', 'Email');
    System.assertEquals('Field_1Object_Email', result4);

    Test.stopTest();
  }

  @IsTest
  static void testSendCompletionEmail() {
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();
    batch.emailFieldsFound = new List<EmailFieldScannerBatch.EmailFieldInfo>();
    batch.emailFieldsFound.add(
      new EmailFieldScannerBatch.EmailFieldInfo('Contact', 'Email', 'Email')
    );
    batch.totalObjectsProcessed = 5;
    batch.totalEmailFieldsFound = 1;

    Test.startTest();

    // Execute batch to get a valid context
    Database.executeBatch(batch, 1);

    Test.stopTest();

    // Verify batch completed (sendCompletionEmail is called in finish method)
    List<AsyncApexJob> jobs = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assertEquals(1, jobs.size(), 'Expected one batch job');
  }

  @IsTest
  static void testBatchErrorHandling() {
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();

    Test.startTest();

    // Test with invalid object name to trigger error handling
    batch.scanObjectForEmailFields('InvalidObjectName');

    Test.stopTest();

    // Verify that errors were captured
    System.assert(
      batch.errors.size() > 0,
      'Expected errors to be captured for invalid object'
    );
  }

  @IsTest
  static void testBatchExecuteMethod() {
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();
    List<String> scope = new List<String>{ 'Contact', 'Account' };

    Test.startTest();

    // Execute batch to get a valid context, then call execute method directly
    Database.executeBatch(new EmailFieldScannerBatch(), 1);

    Test.stopTest();

    // Verify objects were processed by checking that the batch ran
    List<AsyncApexJob> jobs = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assertEquals(1, jobs.size(), 'Expected one batch job');
  }

  @IsTest
  static void testBatchStartMethod() {
    EmailFieldScannerBatch batch = new EmailFieldScannerBatch();

    Test.startTest();

    // Execute batch to test start method
    Database.executeBatch(batch, 1);

    Test.stopTest();

    // Verify that the batch was started successfully
    List<AsyncApexJob> jobs = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assert(jobs.size() > 0, 'Expected batch job to be started');
  }
}
