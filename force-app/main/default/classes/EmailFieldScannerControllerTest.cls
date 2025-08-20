@IsTest
private class EmailFieldScannerControllerTest {
  @IsTest
  static void testStartEmailFieldScanAuraSuccess() {
    Test.startTest();

    // Call the AuraEnabled method
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.startEmailFieldScanAura();

    Test.stopTest();

    // Verify the response
    System.assertEquals(true, response.success, 'Expected success to be true');
    System.assert(
      response.message.contains(
        'Email field scanning batch job started successfully'
      ),
      'Expected success message'
    );

    // Verify a batch job was started
    List<AsyncApexJob> jobs = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assertEquals(1, jobs.size(), 'Expected one batch job to be started');
  }

  @IsTest
  static void testExecuteEmailFieldScanSuccess() {
    Test.startTest();

    // Call the private method through the public method
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.executeEmailFieldScan();

    Test.stopTest();

    // Verify the response
    System.assertEquals(true, response.success, 'Expected success to be true');
    System.assert(
      response.message.contains(
        'Email field scanning batch job started successfully'
      ),
      'Expected success message'
    );
  }

  @IsTest
  static void testEmailScanResponseClass() {
    // Test the response class
    EmailFieldScannerController.EmailScanResponse response = new EmailFieldScannerController.EmailScanResponse();

    response.success = true;
    response.message = 'Test message';

    System.assertEquals(true, response.success);
    System.assertEquals('Test message', response.message);
  }

  @IsTest
  static void testBatchJobStartedVerification() {
    Test.startTest();

    // Start multiple scans to verify they all work
    EmailFieldScannerController.EmailScanResponse response1 = EmailFieldScannerController.startEmailFieldScanAura();
    EmailFieldScannerController.EmailScanResponse response2 = EmailFieldScannerController.startEmailFieldScanAura();

    Test.stopTest();

    // Both should succeed
    System.assertEquals(true, response1.success);
    System.assertEquals(true, response2.success);

    // Verify batch jobs were started
    List<AsyncApexJob> jobs = [
      SELECT Id, Status
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];

    System.assertEquals(
      2,
      jobs.size(),
      'Expected two batch jobs to be started'
    );
  }
}
