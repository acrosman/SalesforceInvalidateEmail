import { LightningElement, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { publish, MessageContext } from 'lightning/messageService';
import JOBS_CHANNEL from '@salesforce/messageChannel/Email_Invalidator_Jobs__c';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';
import restoreAllConfiguredEmails from '@salesforce/apex/InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAura';
import startEmailFieldScanAura from '@salesforce/apex/EmailFieldScannerController.startEmailFieldScanAura';

export default class InvalidateEmail extends LightningElement {
  @wire(MessageContext)
  messageContext;

  // Let the job status card know which jobs were just started.
  publishJobsStarted(jobs) {
    publish(this.messageContext, JOBS_CHANNEL, { jobs: jobs || {} });
  }

  async handleInvalidateClick() {
    // Call the AuraEnabled method to start the batch process
    try {
      let response = await invalidateAllConfiguredEmails();

      console.log("Response from function: ");
      console.log(response);
      if (response.success) {
        this.publishJobsStarted(response.jobs);

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

  async handleRestoreClick() {
    // Call the AuraEnabled method to start the restore process
    try {
      let response = await restoreAllConfiguredEmails();

      console.log("Response from restore function: ");
      console.log(response);
      if (response.success) {
        this.publishJobsStarted(response.jobs);

        // Show success toast
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Email Restoration Started',
            message: response.message,
            variant: 'success'
          })
        );
      } else {
        // Show error toast
        this.dispatchEvent(
          new ShowToastEvent({
            title: 'Error Starting Email Restoration',
            message: response.message,
            variant: 'error'
          })
        );
      }
    } catch (err) {
      // Show error toast
      this.dispatchEvent(
        new ShowToastEvent({
          title: 'Exception Occurred while Starting Email Restoration',
          message: 'Resolution by developer is probably required.',
          variant: 'error'
        })
      );
    }
  }

  async handleEmailScanClick() {
    // Call the AuraEnabled method to start the email field scanning batch process
    try {
      let response = await startEmailFieldScanAura();

      console.log("Response from email scan function: ");
      console.log(response);
      if (response.success) {
        this.publishJobsStarted(response.jobs);

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
