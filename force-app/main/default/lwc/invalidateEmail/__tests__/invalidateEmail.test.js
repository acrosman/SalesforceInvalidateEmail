import { createElement } from '@lwc/engine-dom';
import InvalidateEmail from 'c/invalidateEmail';
import invalidateAllConfiguredEmails from '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura';
import restoreAllConfiguredEmails from '@salesforce/apex/InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAura';
import startEmailFieldScanAura from '@salesforce/apex/EmailFieldScannerController.startEmailFieldScanAura';
import { publish } from 'lightning/messageService';

// Mock the Apex methods
jest.mock(
    '@salesforce/apex/InvalidateEmailFlowAction.invalidateAllConfiguredEmailsAura',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/InvalidateEmailUndoFlowAction.restoreAllConfiguredEmailsAura',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/apex/EmailFieldScannerController.startEmailFieldScanAura',
    () => ({ default: jest.fn() }),
    { virtual: true }
);

jest.mock(
    '@salesforce/messageChannel/Email_Invalidator_Jobs__c',
    () => ({ default: 'Email_Invalidator_Jobs__c' }),
    { virtual: true }
);

// The default toast stub drops its parameters, so keep them on the event detail
jest.mock('lightning/platformShowToastEvent', () => ({
    ShowToastEvent: class extends CustomEvent {
        constructor(params) {
            super('lightning__showtoast', { detail: params, bubbles: true, composed: true });
        }
    }
}));

// Resolve pending promises so async handlers finish
const flushPromises = async () => {
    for (let i = 0; i < 5; i++) {
        // eslint-disable-next-line no-await-in-loop
        await Promise.resolve();
    }
};

const createComponent = () => {
    const element = createElement('c-invalidate-email', {
        is: InvalidateEmail
    });
    document.body.appendChild(element);
    return element;
};

const getButton = (element, label) =>
    Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find(
        (button) => button.label === label
    );

// Click a button and return the toasts it raised
const clickAndCollectToasts = async (element, label) => {
    const toasts = [];
    element.addEventListener('lightning__showtoast', (event) => toasts.push(event.detail));
    getButton(element, label).click();
    await flushPromises();
    return toasts;
};

describe('c-invalidate-email', () => {
    beforeEach(() => {
        // The component logs each Apex response; keep test output readable
        jest.spyOn(console, 'log').mockImplementation(() => {});
    });

    afterEach(() => {
        // The jsdom instance is shared across test cases in a single file so reset the DOM
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
        jest.restoreAllMocks();
    });

    it('renders the component with all three buttons', () => {
        const element = createComponent();

        const card = element.shadowRoot.querySelector('lightning-card');
        expect(card.title).toBe('Email Invalidation');

        expect(element.shadowRoot.querySelectorAll('lightning-button')).toHaveLength(3);
        expect(getButton(element, 'Invalidate Emails').variant).toBe('destructive');
        expect(getButton(element, 'Restore Emails').variant).toBe('success');
        expect(getButton(element, 'Scan For Email Fields').variant).toBe('brand');
    });

    describe.each([
        {
            label: 'Invalidate Emails',
            apexMethod: invalidateAllConfiguredEmails,
            successTitle: 'Email Invalidation Started',
            failureTitle: 'Error Starting Email Invalidation',
            exceptionTitle: 'Exception Occurred while Starting Email Invalidation'
        },
        {
            label: 'Restore Emails',
            apexMethod: restoreAllConfiguredEmails,
            successTitle: 'Email Restoration Started',
            failureTitle: 'Error Starting Email Restoration',
            exceptionTitle: 'Exception Occurred while Starting Email Restoration'
        },
        {
            label: 'Scan For Email Fields',
            apexMethod: startEmailFieldScanAura,
            successTitle: 'Email Field Scan Started',
            failureTitle: 'Error Starting Email Field Scan',
            exceptionTitle: 'Exception Occurred while Starting Email Field Scan'
        }
    ])('$label button', ({ label, apexMethod, successTitle, failureTitle, exceptionTitle }) => {
        it('shows a success toast and publishes the started jobs', async () => {
            const jobs = { '707000000000001AAA': 'Contact' };
            apexMethod.mockResolvedValue({ success: true, message: 'Started', jobs });
            const element = createComponent();

            const toasts = await clickAndCollectToasts(element, label);

            expect(apexMethod).toHaveBeenCalledTimes(1);
            expect(toasts).toEqual([{ title: successTitle, message: 'Started', variant: 'success' }]);
            expect(publish).toHaveBeenCalledTimes(1);
            expect(publish.mock.calls[0][2]).toEqual({ jobs });
        });

        it('publishes an empty job map when the response has no jobs', async () => {
            apexMethod.mockResolvedValue({ success: true, message: 'Started' });
            const element = createComponent();

            await clickAndCollectToasts(element, label);

            expect(publish.mock.calls[0][2]).toEqual({ jobs: {} });
        });

        it('shows an error toast and publishes nothing when Apex reports a failure', async () => {
            apexMethod.mockResolvedValue({ success: false, message: 'No fields configured' });
            const element = createComponent();

            const toasts = await clickAndCollectToasts(element, label);

            expect(toasts).toEqual([
                { title: failureTitle, message: 'No fields configured', variant: 'error' }
            ]);
            expect(publish).not.toHaveBeenCalled();
        });

        it('shows an exception toast when the Apex call throws', async () => {
            apexMethod.mockRejectedValue({ body: { message: 'Boom' } });
            const element = createComponent();

            const toasts = await clickAndCollectToasts(element, label);

            expect(toasts).toHaveLength(1);
            expect(toasts[0].title).toBe(exceptionTitle);
            expect(toasts[0].variant).toBe('error');
            expect(publish).not.toHaveBeenCalled();
        });
    });
});
