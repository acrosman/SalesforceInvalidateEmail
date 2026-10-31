import { createElement } from '@lwc/engine-dom';
import InvalidateEmailFieldStatus from 'c/invalidateEmailFieldStatus';
import { subscribe, unsubscribe } from 'lightning/messageService';
import getConfiguredFields from '@salesforce/apex/InvalidateEmailFieldStatusController.getConfiguredFields';
import getFieldStatus from '@salesforce/apex/InvalidateEmailFieldStatusController.getFieldStatus';
import getRecentJobs from '@salesforce/apex/InvalidateEmailJobStatusController.getRecentJobs';

jest.mock(
    '@salesforce/apex/InvalidateEmailFieldStatusController.getConfiguredFields',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/InvalidateEmailFieldStatusController.getFieldStatus',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

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

const CONTACT_EMAIL = { objectName: 'Contact', fieldName: 'Email' };
const LEAD_EMAIL = { objectName: 'Lead', fieldName: 'Email' };

const CONTACT_STATUS = {
    success: true,
    ...CONTACT_EMAIL,
    nonBlankCount: 1200,
    invalidatedCount: 300,
    percentInvalidated: 0.25
};

const RUNNING_JOB = {
    jobId: '707000000000001AAA',
    jobType: 'Invalidate',
    statusGroup: 'Running'
};

// Resolve pending promises so async loads finish and the DOM re-renders
const flushPromises = async () => {
    for (let i = 0; i < 10; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
};

const createComponent = () => {
    const element = createElement('c-invalidate-email-field-status', {
        is: InvalidateEmailFieldStatus
    });
    document.body.appendChild(element);
    return element;
};

const getRow = (element, key) => element.shadowRoot.querySelector(`tr[data-key="${key}"]`);

describe('c-invalidate-email-field-status', () => {
    beforeEach(() => {
        jest.useFakeTimers();
        getRecentJobs.mockResolvedValue({ success: true, jobs: [] });
    });

    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        jest.useRealTimers();
    });

    it('shows the empty state when no fields are configured', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [] });

        const element = createComponent();
        await flushPromises();

        expect(element.shadowRoot.querySelector('table')).toBeNull();
        expect(element.shadowRoot.textContent).toContain('No Invalidate Email Fields configured.');
        expect(getFieldStatus).not.toHaveBeenCalled();
    });

    it('shows a row per field with its counts', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [CONTACT_EMAIL, LEAD_EMAIL] });
        getFieldStatus.mockImplementation(({ objectName }) =>
            Promise.resolve(
                objectName === 'Contact'
                    ? CONTACT_STATUS
                    : { success: true, ...LEAD_EMAIL, nonBlankCount: 0, percentInvalidated: 0 }
            )
        );

        const element = createComponent();
        await flushPromises();

        expect(getFieldStatus).toHaveBeenCalledTimes(2);
        expect(getFieldStatus).toHaveBeenCalledWith(CONTACT_EMAIL);
        expect(getFieldStatus).toHaveBeenCalledWith(LEAD_EMAIL);

        const row = getRow(element, 'Contact.Email');
        expect(row.textContent).toContain('Contact');
        expect(row.querySelector('.non-blank lightning-formatted-number').value).toBe(1200);
        const percent = row.querySelector('.percent lightning-formatted-number');
        expect(percent.value).toBe(0.25);
        expect(percent.formatStyle).toBe('percent');

        expect(getRow(element, 'Lead.Email').querySelector('.non-blank lightning-formatted-number').value).toBe(0);
    });

    it('shows rows as counting until their status returns', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [CONTACT_EMAIL] });
        let resolveStatus;
        getFieldStatus.mockReturnValue(
            new Promise((resolve) => {
                resolveStatus = resolve;
            })
        );

        const element = createComponent();
        await flushPromises();
        expect(getRow(element, 'Contact.Email').querySelector('.counting')).not.toBeNull();

        resolveStatus(CONTACT_STATUS);
        await flushPromises();
        expect(getRow(element, 'Contact.Email').querySelector('.counting')).toBeNull();
        expect(getRow(element, 'Contact.Email').querySelector('.percent')).not.toBeNull();
    });

    it('shows an error on the row when a field cannot be counted', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [CONTACT_EMAIL, LEAD_EMAIL] });
        getFieldStatus.mockImplementation(({ objectName }) =>
            (objectName === 'Contact'
                ? Promise.resolve({ success: false, message: 'Too many records to count.' })
                : Promise.reject({ body: { message: 'No access' } }))
        );

        const element = createComponent();
        await flushPromises();

        expect(getRow(element, 'Contact.Email').querySelector('.row-error').textContent).toContain(
            'Too many records to count.'
        );
        expect(getRow(element, 'Lead.Email').querySelector('.row-error').textContent).toContain('No access');
        expect(element.shadowRoot.querySelector('[role="alert"]')).toBeNull();
    });

    it('shows an error when the configured fields cannot be loaded', async () => {
        getConfiguredFields.mockResolvedValue({ success: false, message: 'Metadata error' });

        const element = createComponent();
        await flushPromises();

        const alert = element.shadowRoot.querySelector('[role="alert"]');
        expect(alert.textContent).toContain('Metadata error');
        expect(element.shadowRoot.textContent).not.toContain('No Invalidate Email Fields configured.');
    });

    it('reloads when the refresh button is clicked', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [CONTACT_EMAIL] });
        getFieldStatus.mockResolvedValue(CONTACT_STATUS);

        const element = createComponent();
        await flushPromises();

        element.shadowRoot.querySelector('lightning-button-icon').click();
        await flushPromises();

        expect(getConfiguredFields).toHaveBeenCalledTimes(2);
        expect(getFieldStatus).toHaveBeenCalledTimes(2);
    });

    it('ignores counts from an older load', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [CONTACT_EMAIL] });
        let resolveOld;
        getFieldStatus.mockReturnValueOnce(
            new Promise((resolve) => {
                resolveOld = resolve;
            })
        );

        const element = createComponent();
        await flushPromises();

        getFieldStatus.mockResolvedValue(CONTACT_STATUS);
        element.shadowRoot.querySelector('lightning-button-icon').click();
        await flushPromises();

        resolveOld({ ...CONTACT_STATUS, nonBlankCount: 1 });
        await flushPromises();

        expect(getRow(element, 'Contact.Email').querySelector('.non-blank lightning-formatted-number').value).toBe(
            1200
        );
    });

    it('polls while jobs run and reloads the counts when one finishes', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [CONTACT_EMAIL] });
        getFieldStatus.mockResolvedValue(CONTACT_STATUS);
        getRecentJobs.mockResolvedValue({ success: true, jobs: [RUNNING_JOB] });

        createComponent();
        await flushPromises();
        expect(getFieldStatus).toHaveBeenCalledTimes(1);

        // Still running: poll again but don't recount
        jest.advanceTimersByTime(5000);
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(2);
        expect(getFieldStatus).toHaveBeenCalledTimes(1);

        // The job finishes
        getRecentJobs.mockResolvedValue({
            success: true,
            jobs: [{ ...RUNNING_JOB, statusGroup: 'Completed' }]
        });
        jest.advanceTimersByTime(5000);
        await flushPromises();
        expect(getFieldStatus).toHaveBeenCalledTimes(2);

        // No more polling once nothing is active
        jest.advanceTimersByTime(15000);
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(3);
        expect(getFieldStatus).toHaveBeenCalledTimes(2);
    });

    it('does not poll when no jobs are active', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [] });

        createComponent();
        await flushPromises();

        jest.advanceTimersByTime(15000);
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(1);
        expect(getConfiguredFields).toHaveBeenCalledTimes(1);
    });

    it('reloads when a job started from the page has already finished', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [CONTACT_EMAIL] });
        getFieldStatus.mockResolvedValue(CONTACT_STATUS);

        createComponent();
        await flushPromises();
        expect(subscribe).toHaveBeenCalledTimes(1);

        // The job is already complete by the time the component checks
        getRecentJobs.mockResolvedValue({
            success: true,
            jobs: [{ ...RUNNING_JOB, statusGroup: 'Completed' }]
        });
        const handleMessage = subscribe.mock.calls[0][2];
        handleMessage({ jobs: { [RUNNING_JOB.jobId]: 'Contact' } });
        await flushPromises();

        expect(getRecentJobs).toHaveBeenCalledTimes(2);
        expect(getConfiguredFields).toHaveBeenCalledTimes(2);
        expect(getFieldStatus).toHaveBeenCalledTimes(2);
    });

    it('starts polling when a job is started from the page', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [] });

        createComponent();
        await flushPromises();

        getRecentJobs.mockResolvedValue({ success: true, jobs: [RUNNING_JOB] });
        subscribe.mock.calls[0][2]({ jobs: { [RUNNING_JOB.jobId]: 'Contact' } });
        await flushPromises();
        expect(getConfiguredFields).toHaveBeenCalledTimes(1);

        jest.advanceTimersByTime(5000);
        await flushPromises();
        expect(getRecentJobs).toHaveBeenCalledTimes(3);
    });

    it('stops polling and unsubscribes when removed', async () => {
        getConfiguredFields.mockResolvedValue({ success: true, fields: [] });
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
