import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';

export default class InvalidateEmail extends LightningElement {

  async startInvalidation() {
    // Call the AuraEnabled method to start the batch process
    try {
      let response = await invalidateAllConfiguredEmails();

      console.log("Response from function: ");
      console.log(response);
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
    } catch (err) {
      // Show error toast
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Exception Occurred while Starting Email Invalidation',
          message: 'Resolution by developer is probably required.',
          variant: 'error'
        })
      );
    }
  }

  async startEmailScan() {

  }
}
