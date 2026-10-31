import { LightningElement, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import JOBS_CHANNEL from '@salesforce/messageChannel/Email_Invalidator_Jobs__c';
import getConfiguredFields from '@salesforce/apex/InvalidateEmailFieldStatusController.getConfiguredFields';
import getFieldStatus from '@salesforce/apex/InvalidateEmailFieldStatusController.getFieldStatus';
import getRecentJobs from '@salesforce/apex/InvalidateEmailJobStatusController.getRecentJobs';

const POLL_INTERVAL_MS = 5000;
const ACTIVE_GROUPS = ['Queued', 'Running'];

export default class InvalidateEmailFieldStatus extends LightningElement {
  fields = [];
  error;
  isLoading = true;

  // Ids of queued or running jobs. The counts are reloaded when one finishes.
  watchedJobIds = new Set();

  // Incremented on each load so responses from an older load are ignored.
  loadId = 0;

  subscription;
  pollTimer;

  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    this.subscription = subscribe(this.messageContext, JOBS_CHANNEL, (message) =>
      this.handleJobsStarted(message)
    );
    this.loadStatus();
    this.checkJobs();
  }

  disconnectedCallback() {
    unsubscribe(this.subscription);
    this.subscription = null;
    this.stopPolling();
  }

  handleJobsStarted(message) {
    // Watch the new jobs right away so a job that finishes before the next
    // check still triggers a reload.
    Object.keys(message?.jobs || {}).forEach((jobId) => this.watchedJobIds.add(jobId));
    this.checkJobs();
  }

  handleRefreshClick() {
    this.loadStatus();
  }

  async loadStatus() {
    const loadId = ++this.loadId;
    this.isLoading = true;

    try {
      const response = await getConfiguredFields();
      if (loadId !== this.loadId) {
        return;
      }
      if (!response.success) {
        this.error = response.message;
        this.fields = [];
        return;
      }

      this.error = undefined;
      this.fields = response.fields.map((field) => ({
        key: `${field.objectName}.${field.fieldName}`,
        objectName: field.objectName,
        fieldName: field.fieldName,
        isCounting: true
      }));

      // Count each field in its own request so each gets its own query row
      // limit, and fill in rows as they return.
      this.fields.forEach((field) => this.loadFieldStatus(field, loadId));
    } catch (err) {
      if (loadId === this.loadId) {
        this.error = err.body?.message || 'Unknown error occurred';
        this.fields = [];
      }
    } finally {
      if (loadId === this.loadId) {
        this.isLoading = false;
      }
    }
  }

  async loadFieldStatus(field, loadId) {
    let update;
    try {
      const status = await getFieldStatus({
        objectName: field.objectName,
        fieldName: field.fieldName
      });
      update = status.success
        ? {
            hasCounts: true,
            nonBlankCount: status.nonBlankCount,
            percentInvalidated: status.percentInvalidated
          }
        : { rowError: status.message };
    } catch (err) {
      update = { rowError: err.body?.message || 'Unknown error occurred' };
    }

    if (loadId === this.loadId) {
      this.fields = this.fields.map((row) =>
        (row.key === field.key ? { ...row, ...update, isCounting: false } : row)
      );
    }
  }

  // Reloads the counts when a watched job has finished, and polls while any
  // job is still queued or running.
  async checkJobs() {
    try {
      const response = await getRecentJobs();
      if (!response.success) {
        return;
      }

      const activeJobIds = new Set(
        response.jobs
          .filter((job) => ACTIVE_GROUPS.includes(job.statusGroup))
          .map((job) => job.jobId)
      );
      const jobFinished = [...this.watchedJobIds].some((jobId) => !activeJobIds.has(jobId));
      this.watchedJobIds = activeJobIds;

      if (jobFinished) {
        this.loadStatus();
      }
    } catch (err) {
      // Job status is only used to trigger reloads; the refresh button still works.
    } finally {
      this.updatePolling();
    }
  }

  updatePolling() {
    if (this.watchedJobIds.size > 0) {
      if (!this.pollTimer) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.pollTimer = setInterval(() => this.checkJobs(), POLL_INTERVAL_MS);
      }
    } else {
      this.stopPolling();
    }
  }

  stopPolling() {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  get hasData() {
    return this.fields.length > 0;
  }

  get showEmptyState() {
    return !this.isLoading && !this.error && !this.hasData;
  }
}
