/**
 * Callback class for handling the deployment of cached email field results
 */
public class EmailFieldCacheDeployCallback implements Metadata.DeployCallback {
  public void handleResult(
    Metadata.DeployResult result,
    Metadata.DeployCallbackContext context
  ) {
    if (result.done) {
      if (result.success) {
        System.debug('Email field cache deployment completed successfully');

        // Log successful caching
        System.debug(
          'Cached email field scan results have been stored and are ready for user review'
        );
      } else {
        System.debug('Email field cache deployment failed: ' + result);

        // Log deployment failures
        if (
          result.details != null &&
          result.details.componentFailures != null
        ) {
          for (
            Metadata.DeployMessage failure : result.details.componentFailures
          ) {
            System.debug('Cache deployment failure: ' + failure.problem);
          }
        }
      }
    }
  }
}
