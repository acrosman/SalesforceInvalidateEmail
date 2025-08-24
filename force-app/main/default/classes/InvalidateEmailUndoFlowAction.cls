public with sharing class InvalidateEmailUndoFlowAction {
  @AuraEnabled
  public static EmailRestorationResponse restoreAllConfiguredEmailsAura() {
    return executeEmailRestoration();
  }

  @InvocableMethod(
    label='Restore All Configured Emails'
    description='Triggers batch jobs to restore all email fields configured in custom metadata by removing .invalid suffix. This is meant to be called once from a screen flow or LWC not in a bulk context.'
  )
  public static List<EmailRestorationResponse> restoreAllConfiguredEmailsAction() {
    List<EmailRestorationResponse> responses = new List<EmailRestorationResponse>();
    responses.add(executeEmailRestoration());
    return responses;
  }

  @TestVisible
  private static EmailRestorationResponse executeEmailRestoration() {
    EmailRestorationResponse response = new EmailRestorationResponse();

    try {
      InvalidateEmailUndoBatch.restoreAllConfiguredEmails();

      response.success = true;
      response.message = 'Email restoration batch jobs started for all configured email fields.';
    } catch (Exception e) {
      response.success = false;
      response.message = 'Error starting batch jobs: ' + e.getMessage();
      System.debug(
        'Error in InvalidateEmailUndoFlowAction.executeEmailRestoration: ' +
        e.getMessage()
      );
    }

    return response;
  }

  // Response class for both invocable methods
  public class EmailRestorationResponse {
    @InvocableVariable(
      label='Success'
      description='Indicates if the batch job was started successfully'
    )
    @AuraEnabled
    public Boolean success;

    @InvocableVariable(label='Message' description='Success or error message')
    @AuraEnabled
    public String message;
  }
}
