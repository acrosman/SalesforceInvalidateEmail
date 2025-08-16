import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';

export default class InvalidateEmail extends LightningElement {
  handleClick() {
    // Call the AuraEnabled method to start the batch process
    invalidateAllConfiguredEmails()
      .then(response => {
        // The AuraEnabled method returns a single response object
        if (response.success) {
          // Show success toast
          this.dispatchEvent(
            new ShowToastEvent({
              title: 'Email Invalidation Started',
              message: response.message,
              variant: 'success'
            })
          );
        } else {
          // Show error toast
          this.dispatchEvent(
            new ShowToastEvent({
              title: 'Error Starting Email Invalidation',
              message: response.message,
              variant: 'error'
            })
          );
        }
      })
      .catch(error => {
        // Handle any unexpected errors
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error',
            message: 'An unexpected error occurred: ' + error.body.message,
            variant: 'error'
          })
        );
      });
  }
}
