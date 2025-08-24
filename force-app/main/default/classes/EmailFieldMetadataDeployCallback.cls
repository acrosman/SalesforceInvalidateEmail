public class EmailFieldMetadataDeployCallback implements Metadata.DeployCallback {
  public void handleResult(
    Metadata.DeployResult result,
    Metadata.DeployCallbackContext context
  ) {
    if (result.success) {
      System.debug(
        'Email field metadata deployment succeeded. Number of components deployed: ' +
        result.numberComponentsDeployed
      );

      // Log successful deployments
      if (result.details != null && result.details.componentSuccesses != null) {
        for (Object successObj : result.details.componentSuccesses) {
          System.debug('Successfully deployed component: ' + successObj);
        }
      }

      // Send success notification
      sendDeploymentNotification(result, true);
    } else {
      System.debug(
        'Email field metadata deployment failed. Number of errors: ' +
        result.numberComponentErrors
      );

      // Log deployment failures
      if (result.details != null && result.details.componentFailures != null) {
        for (Object failureObj : result.details.componentFailures) {
          System.debug('Failed to deploy component: ' + failureObj);
        }
      }

      // Send failure notification
      sendDeploymentNotification(result, false);
    }
  }

  private void sendDeploymentNotification(
    Metadata.DeployResult result,
    Boolean success
  ) {
    try {
      // Get the current user's email for notification
      User currentUser = [
        SELECT Email
        FROM User
        WHERE Id = :UserInfo.getUserId()
        LIMIT 1
      ];

      if (String.isNotBlank(currentUser.Email)) {
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new List<String>{ currentUser.Email });

        if (success) {
          email.setSubject('Email Field Metadata Deployment Successful');

          String emailBody = 'The email field metadata deployment has completed successfully.\n\n';
          emailBody +=
            'Components Deployed: ' +
            result.numberComponentsDeployed +
            '\n';
          emailBody +=
            'Components with Errors: ' +
            result.numberComponentErrors +
            '\n';
          emailBody += 'Deployment ID: ' + result.id + '\n\n';

          if (
            result.details != null &&
            result.details.componentSuccesses != null
          ) {
            emailBody += 'Successfully deployed components:\n';
            for (Object componentSuccess : result.details.componentSuccesses) {
              emailBody += '- ' + componentSuccess + '\n';
            }
          }

          email.setPlainTextBody(emailBody);
        } else {
          email.setSubject('Email Field Metadata Deployment Failed');

          String emailBody = 'The email field metadata deployment has failed.\n\n';
          emailBody += 'Deployment ID: ' + result.id + '\n';
          emailBody +=
            'Components with Errors: ' +
            result.numberComponentErrors +
            '\n\n';

          if (
            result.details != null &&
            result.details.componentFailures != null
          ) {
            emailBody += 'Failed components:\n';
            for (Object failure : result.details.componentFailures) {
              emailBody += '- ' + failure + '\n';
            }
          }

          System.debug(emailBody);
          email.setPlainTextBody(emailBody);
        }

        Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });
      }
    } catch (Exception e) {
      System.debug(
        'Error sending deployment notification email: ' + e.getMessage()
      );
    }
  }
}
