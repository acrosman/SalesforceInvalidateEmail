public with sharing class InvalidateEmailFlowAction {
  @InvocableMethod(
    label='Invalidate All Configured Emails'
    description='Triggers batch jobs for all email fields configured in custom metadata. This is meant to be called once from a screen flow or LWC not in a bulk context.'
  )
  public static List<EmailInvalidationResponse> invalidateAllConfiguredEmails() {
    List<EmailInvalidationResponse> responses = new List<EmailInvalidationResponse>();

    EmailInvalidationResponse response = new EmailInvalidationResponse();

    try {
      InvalidateEmailBatch.invalidateAllConfiguredEmails();

      response.success = true;
      response.message = 'Email invalidation batch jobs started for all configured email fields.';
    } catch (Exception e) {
      response.success = false;
      response.message = 'Error starting batch jobs: ' + e.getMessage();
      System.debug(
        'Error in InvalidateEmailFlowAction.invalidateAllConfiguredEmails: ' +
        e.getMessage()
      );
    }

    responses.add(response);

    return responses;
  }

  // Response class for both invocable methods
  public class EmailInvalidationResponse {
    @InvocableVariable(
      label='Success'
      description='Indicates if the batch job was started successfully'
    )
    public Boolean success;

    @InvocableVariable(label='Message' description='Success or error message')
    public String message;
  }
}
