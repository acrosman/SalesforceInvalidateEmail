import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';
import startEmailFieldScanAura from '@salesforce/apex/EmailFieldScannerController.startEmailFieldScanAura';

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
    // Call the AuraEnabled method to start the email field scanning batch process
    try {
      let response = await startEmailFieldScanAura();

      console.log("Response from email scan function: ");
      console.log(response);
      if (response.success) {
        // Show success toast
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Email Field Scan Started',
            message: response.message,
            variant: 'success'
          })
        );
      } else {
        // Show error toast
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error Starting Email Field Scan',
            message: response.message,
            variant: 'error'
          })
        );
      }
    } catch (err) {
      // Show error toast
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Exception Occurred while Starting Email Field Scan',
          message: 'Resolution by developer is probably required.',
          variant: 'error'
        })
      );
    }
  }
}
