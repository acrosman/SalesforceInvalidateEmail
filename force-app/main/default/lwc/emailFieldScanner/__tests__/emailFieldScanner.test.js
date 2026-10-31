import { createElement } from '@lwc/engine-dom';
import EmailFieldScanner from 'c/emailFieldScanner';
import getCachedScanResults from '@salesforce/apex/EmailFieldScannerController.getCachedScanResults';
import deploySelectedFields from '@salesforce/apex/EmailFieldScannerController.deploySelectedFields';

// Mock the Apex methods; both are called imperatively by the component
jest.mock(
  '@salesforce/apex/EmailFieldScannerController.getCachedScanResults',
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  '@salesforce/apex/EmailFieldScannerController.deploySelectedFields',
  () => ({ default: jest.fn() }),
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

const CONTACT_FIELD = {
  objectName: 'Contact',
  fieldName: 'Work_Email__c',
  fieldLabel: 'Work Email'
};
const LEAD_FIELD = {
  objectName: 'Lead',
  fieldName: 'Alt_Email__c',
  fieldLabel: 'Alternate Email'
};
// User is an object custom metadata can't reference
const USER_FIELD = {
  objectName: 'User',
  fieldName: 'SenderEmail',
  fieldLabel: 'Sender Email'
};

const scanResults = (newEmailFields) => ({
  success: true,
  message: 'Cached scan results loaded successfully',
  lastModifiedDate: '2026-01-01T12:00:00.000Z',
  totalObjectsScanned: 5,
  totalEmailFieldsFound: 10,
  newEmailFields
});

// Resolve pending promises so async handlers finish and the DOM re-renders
const flushPromises = async () => {
  for (let i = 0; i < 5; i++) {
    // eslint-disable-next-line no-await-in-loop
    await Promise.resolve();
  }
};

const createComponent = async () => {
  const element = createElement('c-email-field-scanner', {
    is: EmailFieldScanner
  });
  element.toasts = [];
  element.addEventListener('lightning__showtoast', (event) => element.toasts.push(event.detail));
  document.body.appendChild(element);
  await flushPromises();
  return element;
};

const getStatusValues = (element) =>
  Array.from(element.shadowRoot.querySelectorAll('.slds-form-element__static')).map(
    (span) => span.textContent
  );

const getMessages = (element) =>
  Array.from(element.shadowRoot.querySelectorAll('.slds-text-body_regular')).map(
    (p) => p.textContent
  );

const selectRows = async (element, rows) => {
  const datatable = element.shadowRoot.querySelector('lightning-datatable');
  datatable.dispatchEvent(new CustomEvent('rowselection', { detail: { selectedRows: rows } }));
  await flushPromises();
};

const clickInclude = async (element) => {
  element.shadowRoot.querySelector('lightning-button').click();
  await flushPromises();
};

describe('c-email-field-scanner', () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  describe('loading cached results', () => {
    it('shows the loading spinner while results load', async () => {
      // Never resolve so the component stays loading
      getCachedScanResults.mockReturnValue(new Promise(() => {}));
      const element = await createComponent();

      expect(element.shadowRoot.querySelector('lightning-spinner')).not.toBeNull();
      expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
    });

    it('displays the scan status and the new fields', async () => {
      getCachedScanResults.mockResolvedValue(scanResults([CONTACT_FIELD, LEAD_FIELD]));
      const element = await createComponent();

      expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
      expect(getStatusValues(element)).toEqual([
        new Date('2026-01-01T12:00:00.000Z').toLocaleString(),
        '5',
        '10'
      ]);

      const datatable = element.shadowRoot.querySelector('lightning-datatable');
      expect(datatable.data).toEqual([
        { ...CONTACT_FIELD, uniqueKey: 'Contact_Work_Email__c_0' },
        { ...LEAD_FIELD, uniqueKey: 'Lead_Alt_Email__c_1' }
      ]);
    });

    it('shows defaults when the scan has no date or totals', async () => {
      getCachedScanResults.mockResolvedValue({ success: true, newEmailFields: [CONTACT_FIELD] });
      const element = await createComponent();

      expect(getStatusValues(element)).toEqual(['N/A', '0', '0']);
    });

    it('displays the no new fields message when the scan found none', async () => {
      getCachedScanResults.mockResolvedValue(scanResults([]));
      const element = await createComponent();

      expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
      expect(getMessages(element)).toEqual(['No new email fields found in the last scan.']);
    });

    it('displays the no scan data message when nothing is returned', async () => {
      getCachedScanResults.mockResolvedValue(undefined);
      const element = await createComponent();

      expect(element.shadowRoot.querySelector('.slds-theme_error')).toBeNull();
      expect(getMessages(element)).toEqual([
        'No scan data available. Please run a field scan first.'
      ]);
    });

    it('displays the Apex message when loading is unsuccessful', async () => {
      getCachedScanResults.mockResolvedValue({
        success: false,
        message: 'No cached scan results found. Please run a scan first.'
      });
      const element = await createComponent();

      const errorDiv = element.shadowRoot.querySelector('.slds-theme_error');
      expect(errorDiv.textContent).toContain('No cached scan results found.');
      expect(element.shadowRoot.querySelector('.slds-box')).toBeNull();
    });

    it('falls back to a generic message when an unsuccessful load has none', async () => {
      getCachedScanResults.mockResolvedValue({ success: false });
      const element = await createComponent();

      const errorDiv = element.shadowRoot.querySelector('.slds-theme_error');
      expect(errorDiv.textContent).toContain('Failed to load scan results');
    });

    it('displays the error message when the Apex call throws', async () => {
      getCachedScanResults.mockRejectedValue({ body: { message: 'Insufficient access' } });
      const element = await createComponent();

      const errorDiv = element.shadowRoot.querySelector('.slds-theme_error');
      expect(errorDiv.textContent).toContain('Insufficient access');
      expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
    });

    it('falls back to a generic message when the thrown error has no body', async () => {
      getCachedScanResults.mockRejectedValue(new Error('Network down'));
      const element = await createComponent();

      const errorDiv = element.shadowRoot.querySelector('.slds-theme_error');
      expect(errorDiv.textContent).toContain('Unknown error occurred while loading scan results');
    });
  });

  describe('selecting and sorting fields', () => {
    beforeEach(() => {
      getCachedScanResults.mockResolvedValue(scanResults([CONTACT_FIELD, LEAD_FIELD, USER_FIELD]));
    });

    it('selects rows from supported objects without a warning', async () => {
      const element = await createComponent();
      const rows = element.shadowRoot.querySelector('lightning-datatable').data;

      await selectRows(element, [rows[0], rows[1]]);

      expect(element.shadowRoot.querySelector('lightning-datatable').selectedRows).toEqual([
        'Contact_Work_Email__c_0',
        'Lead_Alt_Email__c_1'
      ]);
      expect(element.toasts).toEqual([]);
    });

    it('drops rows from unsupported objects and warns', async () => {
      const element = await createComponent();
      const rows = element.shadowRoot.querySelector('lightning-datatable').data;

      await selectRows(element, [rows[0], rows[2]]);

      expect(element.shadowRoot.querySelector('lightning-datatable').selectedRows).toEqual([
        'Contact_Work_Email__c_0'
      ]);
      expect(element.toasts).toHaveLength(1);
      expect(element.toasts[0].variant).toBe('warning');
    });

    it('sorts rows by the chosen column in either direction', async () => {
      const element = await createComponent();
      const datatable = element.shadowRoot.querySelector('lightning-datatable');

      datatable.dispatchEvent(
        new CustomEvent('sort', { detail: { fieldName: 'fieldLabel', sortDirection: 'asc' } })
      );
      await flushPromises();
      expect(datatable.data.map((row) => row.fieldLabel)).toEqual([
        'Alternate Email',
        'Sender Email',
        'Work Email'
      ]);
      expect(datatable.sortedBy).toBe('fieldLabel');
      expect(datatable.sortedDirection).toBe('asc');

      datatable.dispatchEvent(
        new CustomEvent('sort', { detail: { fieldName: 'fieldLabel', sortDirection: 'desc' } })
      );
      await flushPromises();
      expect(datatable.data.map((row) => row.fieldLabel)).toEqual([
        'Work Email',
        'Sender Email',
        'Alternate Email'
      ]);
    });

    it('sorts missing values first when ascending', async () => {
      getCachedScanResults.mockResolvedValue(
        scanResults([CONTACT_FIELD, { ...LEAD_FIELD, fieldLabel: null }])
      );
      const element = await createComponent();
      const datatable = element.shadowRoot.querySelector('lightning-datatable');

      datatable.dispatchEvent(
        new CustomEvent('sort', { detail: { fieldName: 'fieldLabel', sortDirection: 'asc' } })
      );
      await flushPromises();

      expect(datatable.data.map((row) => row.fieldLabel)).toEqual([null, 'Work Email']);
    });
  });

  describe('including selected fields', () => {
    beforeEach(() => {
      getCachedScanResults.mockResolvedValue(scanResults([CONTACT_FIELD, LEAD_FIELD]));
    });

    it('warns and skips deployment when nothing is selected', async () => {
      const element = await createComponent();

      await clickInclude(element);

      expect(deploySelectedFields).not.toHaveBeenCalled();
      expect(element.toasts).toEqual([
        {
          title: 'Warning',
          message: 'Please select at least one field to include.',
          variant: 'warning'
        }
      ]);
    });

    it('deploys only the selected fields and clears the selection', async () => {
      deploySelectedFields.mockResolvedValue({
        success: true,
        message: 'Successfully initiated deployment of 1 email field(s)'
      });
      const element = await createComponent();
      const rows = element.shadowRoot.querySelector('lightning-datatable').data;
      await selectRows(element, [rows[1]]);

      await clickInclude(element);

      expect(deploySelectedFields).toHaveBeenCalledTimes(1);
      const deployed = JSON.parse(deploySelectedFields.mock.calls[0][0].selectedFieldsJson);
      expect(deployed).toEqual([{ ...LEAD_FIELD, uniqueKey: 'Lead_Alt_Email__c_1', selected: true }]);
      expect(element.toasts).toEqual([
        {
          title: 'Success',
          message: 'Successfully initiated deployment of 1 email field(s)',
          variant: 'success'
        }
      ]);
      expect(element.shadowRoot.querySelector('lightning-datatable').selectedRows).toEqual([]);
      expect(element.shadowRoot.querySelector('lightning-button').disabled).toBe(false);
    });

    it('disables the button while the deployment request is in progress', async () => {
      deploySelectedFields.mockReturnValue(new Promise(() => {}));
      const element = await createComponent();
      const rows = element.shadowRoot.querySelector('lightning-datatable').data;
      await selectRows(element, [rows[0]]);

      await clickInclude(element);

      expect(element.shadowRoot.querySelector('lightning-button').disabled).toBe(true);
    });

    it('shows an error toast and keeps the selection when Apex reports a failure', async () => {
      deploySelectedFields.mockResolvedValue({
        success: false,
        message: 'No fields were marked as selected for deployment'
      });
      const element = await createComponent();
      const rows = element.shadowRoot.querySelector('lightning-datatable').data;
      await selectRows(element, [rows[0]]);

      await clickInclude(element);

      expect(element.toasts).toEqual([
        {
          title: 'Error',
          message: 'No fields were marked as selected for deployment',
          variant: 'error'
        }
      ]);
      expect(element.shadowRoot.querySelector('lightning-datatable').selectedRows).toEqual([
        'Contact_Work_Email__c_0'
      ]);
    });

    it('shows the Apex error message when the deployment call throws', async () => {
      deploySelectedFields.mockRejectedValue({ body: { message: 'Metadata API disabled' } });
      const element = await createComponent();
      const rows = element.shadowRoot.querySelector('lightning-datatable').data;
      await selectRows(element, [rows[0]]);

      await clickInclude(element);

      expect(element.toasts).toEqual([
        {
          title: 'Error',
          message: 'An unexpected error occurred: Metadata API disabled',
          variant: 'error'
        }
      ]);
      expect(element.shadowRoot.querySelector('lightning-button').disabled).toBe(false);
    });

    it('shows the JavaScript error message when the thrown error has no body', async () => {
      deploySelectedFields.mockRejectedValue(new Error('Network down'));
      const element = await createComponent();
      const rows = element.shadowRoot.querySelector('lightning-datatable').data;
      await selectRows(element, [rows[0]]);

      await clickInclude(element);

      expect(element.toasts[0].message).toBe('An unexpected error occurred: Network down');
    });
  });
});
