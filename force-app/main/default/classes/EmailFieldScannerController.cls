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
      response.message = 'Email field scanning batch job started successfully. You will receive an email notification when the scan is complete and metadata records are deployed.';
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

  // Response class for the AuraEnabled method
  public class EmailScanResponse {
    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String message;
  }
}
