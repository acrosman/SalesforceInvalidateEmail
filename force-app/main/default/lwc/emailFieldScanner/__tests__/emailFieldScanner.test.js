import { createElement } from '@lwc/engine-dom';
import EmailFieldScanner from 'c/emailFieldScanner';
import getCachedScanResults from '@salesforce/apex/EmailFieldScannerController.getCachedScanResults';
import deploySelectedFields from '@salesforce/apex/EmailFieldScannerController.deploySelectedFields';

// Mock the Apex methods
jest.mock(
  '@salesforce/apex/EmailFieldScannerController.getCachedScanResults',
  () => {
    const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

jest.mock(
  '@salesforce/apex/EmailFieldScannerController.deploySelectedFields',
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

describe('c-email-field-scanner', () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    // Clear all mocks
    jest.clearAllMocks();
  });

  it('displays loading spinner initially', () => {
    const element = createElement('c-email-field-scanner', {
      is: EmailFieldScanner
    });
    document.body.appendChild(element);

    const spinner = element.shadowRoot.querySelector('lightning-spinner');
    expect(spinner).toBeTruthy();
  });

  it('displays error message when wire service returns error', async () => {
    const element = createElement('c-email-field-scanner', {
      is: EmailFieldScanner
    });
    document.body.appendChild(element);

    // Emit error from wire service
    getCachedScanResults.error({ body: { message: 'Test error' } });

    await Promise.resolve();

    const errorDiv = element.shadowRoot.querySelector('.slds-theme_error');
    expect(errorDiv).toBeTruthy();
    expect(errorDiv.textContent).toContain('Test error');
  });

  it('displays scan data when wire service returns success', async () => {
    const mockData = {
      success: true,
      lastModifiedDate: '2023-01-01T12:00:00.000Z',
      totalObjectsScanned: 5,
      totalEmailFieldsFound: 10,
      newEmailFields: [
        {
          objectName: 'Contact',
          fieldName: 'Email',
          fieldLabel: 'Email Address'
        }
      ]
    };

    const element = createElement('c-email-field-scanner', {
      is: EmailFieldScanner
    });
    document.body.appendChild(element);

    // Emit data from wire service
    getCachedScanResults.emit(mockData);

    await Promise.resolve();

    // Check status fields are displayed
    const statusLabels = element.shadowRoot.querySelectorAll('.slds-form-element__label');
    expect(statusLabels.length).toBeGreaterThan(0);

    // Check datatable is displayed
    const datatable = element.shadowRoot.querySelector('lightning-datatable');
    expect(datatable).toBeTruthy();
  });

  it('displays no data message when no email fields found', async () => {
    const mockData = {
      success: true,
      lastModifiedDate: '2023-01-01T12:00:00.000Z',
      totalObjectsScanned: 5,
      totalEmailFieldsFound: 0,
      newEmailFields: []
    };

    const element = createElement('c-email-field-scanner', {
      is: EmailFieldScanner
    });
    document.body.appendChild(element);

    // Emit data from wire service
    getCachedScanResults.emit(mockData);

    await Promise.resolve();

    const noDataMessage = element.shadowRoot.querySelector('.slds-text-body_regular');
    expect(noDataMessage.textContent).toContain('No new email fields found');
  });

  it('handles deploy selected fields successfully', async () => {
    const mockData = {
      success: true,
      lastModifiedDate: '2023-01-01T12:00:00.000Z',
      totalObjectsScanned: 5,
      totalEmailFieldsFound: 1,
      newEmailFields: [
        {
          objectName: 'Contact',
          fieldName: 'Email',
          fieldLabel: 'Email Address'
        }
      ]
    };

    deploySelectedFields.mockResolvedValue({
      success: true,
      message: 'Successfully deployed fields'
    });

    const element = createElement('c-email-field-scanner', {
      is: EmailFieldScanner
    });
    document.body.appendChild(element);

    // Emit data from wire service
    getCachedScanResults.emit(mockData);

    await Promise.resolve();

    // Simulate row selection
    const datatable = element.shadowRoot.querySelector('lightning-datatable');
    datatable.dispatchEvent(
      new CustomEvent('rowselection', {
        detail: {
          selectedRows: [
            {
              objectName: 'Contact',
              fieldName: 'Email',
              fieldLabel: 'Email Address',
              uniqueKey: 'Contact_Email_0'
            }
          ]
        }
      })
    );

    await Promise.resolve();

    // Click the deploy button
    const deployButton = element.shadowRoot.querySelector('lightning-button');
    deployButton.click();

    await Promise.resolve();

    expect(deploySelectedFields).toHaveBeenCalled();
  });
});
