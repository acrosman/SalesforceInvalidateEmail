import { createElement } from '@lwc/engine-dom';
import InvalidateEmailJobStatus from 'c/invalidateEmailJobStatus';
import { subscribe, unsubscribe } from 'lightning/messageService';
import getRecentJobs from '@salesforce/apex/InvalidateEmailJobStatusController.getRecentJobs';

jest.mock(
    '@salesforce/apex/InvalidateEmailJobStatusController.getRecentJobs',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/messageChannel/Email_Invalidator_Jobs__c',
    () => ({ default: 'Email_Invalidator_Jobs__c' }),
    { virtual: true }
);

const RUNNING_JOB = {
    jobId: '707000000000001AAA',
    jobType: 'Invalidate',
    status: 'Processing',
    statusGroup: 'Running',
    itemsProcessed: 3,
    totalItems: 10,
    errors: 0,
    createdDate: '2026-10-29T12:00:00.000Z',
    submittedBy: 'Test User'
};

const QUEUED_JOB = {
    jobId: '707000000000002AAA',
    jobType: 'Invalidate',
    status: 'Holding',
    statusGroup: 'Queued',
    itemsProcessed: 0,
    totalItems: 0,
    errors: 0,
    createdDate: '2026-10-29T12:00:00.000Z',
    submittedBy: 'Test User'
};

const COMPLETED_JOB = {
    jobId: '707000000000003AAA',
    jobType: 'Field Scan',
    status: 'Completed',
    statusGroup: 'Completed',
    itemsProcessed: 5,
    totalItems: 5,
    errors: 0,
    createdDate: '2026-10-28T12:00:00.000Z',
    completedDate: '2026-10-28T12:05:00.000Z',
    submittedBy: 'Test User'
};

// Resolve pending promises so async loads finish and the DOM re-renders
const flushPromises = async () => {
    for (let i = 0; i < 5; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
};

const createComponent = () => {
    const element = createElement('c-invalidate-email-job-status', {
        is: InvalidateEmailJobStatus
    });
    document.body.appendChild(element);
    return element;
};

describe('c-invalidate-email-job-status', () => {
    beforeEach(() => {
        jest.useFakeTimers();
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        jest.useRealTimers();
    });

    it('shows the empty state when there are no jobs', async () => {
        getRecentJobs.mockResolvedValue({ success: true, jobs: [] });

        const element = createComponent();
        await flushPromises();

        expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
        expect(element.shadowRoot.textContent).toContain('No Email Invalidator jobs in the last 7 days.');
    });

    it('shows a summary, active progress and job rows', async () => {
        getRecentJobs.mockResolvedValue({
            success: true,
            jobs: [RUNNING_JOB, QUEUED_JOB, COMPLETED_JOB]
        });

        const element = createComponent();
        await flushPromises();

        const summary = element.shadowRoot.querySelector('.summary');
        expect(summary.textContent).toBe('1 running · 1 queued · 1 completed');

        const progressBar = element.shadowRoot.querySelector('lightning-progress-bar');
        expect(progressBar.value).toBe(30);

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data).toHaveLength(3);
        expect(table.data[0].progressLabel).toBe('3 / 10');
        expect(table.data[0].objectName).toBe('—');
        expect(table.data[0].statusIcon).toBe('utility:sync');
    });

    it('shows an error when the job status cannot be loaded', async () => {
        getRecentJobs.mockResolvedValue({ success: false, message: 'No access' });

        const element = createComponent();
        await flushPromises();

        const alert = element.shadowRoot.querySelector('[role="alert"]');
        expect(alert.textContent).toContain('No access');
    });

    it('polls while jobs are active and stops once they finish', async () => {
        getRecentJobs.mockResolvedValueOnce({ success: true, jobs: [RUNNING_JOB] });

        const element = createComponent();
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(1);

        // The job finishes before the next poll
        getRecentJobs.mockResolvedValue({
            success: true,
            jobs: [{ ...RUNNING_JOB, status: 'Completed', statusGroup: 'Completed', itemsProcessed: 10 }]
        });
        jest.advanceTimersByTime(5000);
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(2);
        expect(element.shadowRoot.querySelector('lightning-progress-bar')).toBeNull();

        // No more polling once nothing is active
        jest.advanceTimersByTime(15000);
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(2);
    });

    it('does not poll when no jobs are active', async () => {
        getRecentJobs.mockResolvedValue({ success: true, jobs: [COMPLETED_JOB] });

        createComponent();
        await flushPromises();

        jest.advanceTimersByTime(15000);
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(1);
    });

    it('refreshes and labels objects when jobs are started', async () => {
        getRecentJobs.mockResolvedValue({ success: true, jobs: [] });

        const element = createComponent();
        await flushPromises();
        expect(subscribe).toHaveBeenCalledTimes(1);

        getRecentJobs.mockResolvedValue({ success: true, jobs: [QUEUED_JOB] });
        const handleMessage = subscribe.mock.calls[0][2];
        handleMessage({ jobs: { [QUEUED_JOB.jobId]: 'Contact' } });
        await flushPromises();

        expect(getRecentJobs).toHaveBeenCalledTimes(2);
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data[0].objectName).toBe('Contact');
    });

    it('refreshes when the refresh button is clicked', async () => {
        getRecentJobs.mockResolvedValue({ success: true, jobs: [] });

        const element = createComponent();
        await flushPromises();

        element.shadowRoot.querySelector('lightning-button-icon').click();
        await flushPromises();

        expect(getRecentJobs).toHaveBeenCalledTimes(2);
    });

    it('stops polling and unsubscribes when removed', async () => {
        getRecentJobs.mockResolvedValue({ success: true, jobs: [RUNNING_JOB] });

        const element = createComponent();
        await flushPromises();
        document.body.removeChild(element);

        jest.advanceTimersByTime(15000);
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(1);
        expect(unsubscribe).toHaveBeenCalledTimes(1);
    });
});
