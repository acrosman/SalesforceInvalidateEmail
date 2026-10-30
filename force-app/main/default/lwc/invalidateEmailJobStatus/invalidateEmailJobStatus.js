import { LightningElement, wire } from 'lwc';
import { subscribe, unsubscribe, MessageContext } from 'lightning/messageService';
import JOBS_CHANNEL from '@salesforce/messageChannel/Email_Invalidator_Jobs__c';
import getRecentJobs from '@salesforce/apex/InvalidateEmailJobStatusController.getRecentJobs';

const POLL_INTERVAL_MS = 5000;

// Status groups returned by InvalidateEmailJobStatusController, in display order.
const STATUS_GROUPS = {
  'Running': { icon: 'utility:sync', textClass: '' },
  'Queued': { icon: 'utility:clock', textClass: 'slds-text-color_weak' },
  'Completed': { icon: 'utility:success', textClass: 'slds-text-color_success' },
  'Completed with Errors': { icon: 'utility:warning', textClass: 'slds-text-color_error' },
  'Failed': { icon: 'utility:error', textClass: 'slds-text-color_error' },
  'Aborted': { icon: 'utility:ban', textClass: 'slds-text-color_weak' }
};
const ACTIVE_GROUPS = ['Queued', 'Running'];

const COLUMNS = [
  {
    label: 'Job',
    fieldName: 'jobType',
    type: 'text',
    initialWidth: 110
  },
  {
    label: 'Object',
    fieldName: 'objectName',
    type: 'text'
  },
  {
    label: 'Status',
    fieldName: 'statusGroup',
    type: 'text',
    cellAttributes: {
      iconName: { fieldName: 'statusIcon' },
      class: { fieldName: 'statusClass' }
    }
  },
  {
    label: 'Progress',
    fieldName: 'progressLabel',
    type: 'text',
    initialWidth: 100
  },
  {
    label: 'Errors',
    fieldName: 'errors',
    type: 'number',
    initialWidth: 80
  },
  {
    label: 'Submitted',
    fieldName: 'createdDate',
    type: 'date',
    typeAttributes: {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit'
    }
  },
  {
    label: 'Submitted By',
    fieldName: 'submittedBy',
    type: 'text'
  },
  {
    label: 'Details',
    fieldName: 'extendedStatus',
    type: 'text',
    wrapText: true
  }
];

export default class InvalidateEmailJobStatus extends LightningElement {
  columns = COLUMNS;
  jobs = [];
  error;
  isLoading = true;

  // Job Ids started from this page, mapped to the object each job processes.
  // AsyncApexJob doesn't record the object, so this only lasts for the session.
  jobObjects = {};

  subscription;
  pollTimer;

  @wire(MessageContext)
  messageContext;

  connectedCallback() {
    this.subscription = subscribe(this.messageContext, JOBS_CHANNEL, (message) =>
      this.handleJobsStarted(message)
    );
    this.loadJobs();
  }

  disconnectedCallback() {
    unsubscribe(this.subscription);
    this.subscription = null;
    this.stopPolling();
  }

  handleJobsStarted(message) {
    if (message && message.jobs) {
      this.jobObjects = { ...this.jobObjects, ...message.jobs };
    }
    this.loadJobs();
  }

  handleRefreshClick() {
    this.loadJobs();
  }

  async loadJobs() {
    try {
      const response = await getRecentJobs();
      if (response.success) {
        this.jobs = response.jobs.map((job) => this.toRow(job));
        this.error = undefined;
      } else {
        this.error = response.message;
      }
    } catch (err) {
      this.error = err.body?.message || 'Unknown error occurred';
    } finally {
      this.isLoading = false;
      this.updatePolling();
    }
  }

  toRow(job) {
    const group = STATUS_GROUPS[job.statusGroup] || STATUS_GROUPS.Failed;
    return {
      ...job,
      objectName: this.jobObjects[job.jobId] || '—',
      progressLabel: `${job.itemsProcessed} / ${job.totalItems}`,
      statusIcon: group.icon,
      statusClass: group.textClass
    };
  }

  // Poll while any job is queued or running; stop once they have all finished.
  updatePolling() {
    if (this.hasActiveJobs) {
      if (!this.pollTimer) {
        // eslint-disable-next-line @lwc/lwc/no-async-operation
        this.pollTimer = setInterval(() => this.loadJobs(), POLL_INTERVAL_MS);
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

  get activeJobs() {
    return this.jobs.filter((job) => ACTIVE_GROUPS.includes(job.statusGroup));
  }

  get hasActiveJobs() {
    return this.activeJobs.length > 0;
  }

  get hasData() {
    return this.jobs.length > 0;
  }

  get showEmptyState() {
    return !this.isLoading && !this.error && !this.hasData;
  }

  // e.g. "2 running · 1 queued · 4 completed"
  get summary() {
    return Object.keys(STATUS_GROUPS)
      .map((groupName) => {
        const count = this.jobs.filter((job) => job.statusGroup === groupName).length;
        return count > 0 ? `${count} ${groupName.toLowerCase()}` : null;
      })
      .filter((part) => part)
      .join(' · ');
  }

  get activeItemsProcessed() {
    return this.activeJobs.reduce((sum, job) => sum + (job.itemsProcessed || 0), 0);
  }

  get activeTotalItems() {
    return this.activeJobs.reduce((sum, job) => sum + (job.totalItems || 0), 0);
  }

  get activeProgress() {
    const total = this.activeTotalItems;
    return total > 0 ? Math.round((this.activeItemsProcessed / total) * 100) : 0;
  }
}
