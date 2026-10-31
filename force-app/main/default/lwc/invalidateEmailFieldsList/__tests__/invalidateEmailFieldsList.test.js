import { createElement } from '@lwc/engine-dom';
import InvalidateEmailFieldsList from 'c/invalidateEmailFieldsList';
import getInvalidateEmailFields from '@salesforce/apex/InvalidateEmailFieldsController.getInvalidateEmailFields';
import getCustomMetadataObjectPrefix from '@salesforce/apex/InvalidateEmailFieldsController.getCustomMetadataObjectPrefix';
import { mockNavigate } from 'lightning/navigation';

// Mock the Apex methods
jest.mock(
  '@salesforce/apex/InvalidateEmailFieldsController.getInvalidateEmailFields',
  () => {
    const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

jest.mock(
  '@salesforce/apex/InvalidateEmailFieldsController.getCustomMetadataObjectPrefix',
  () => ({ default: jest.fn() }),
  { virtual: true }
);

// The default navigation stub ignores calls, so record them instead
jest.mock('lightning/navigation', () => {
  const Navigate = Symbol('Navigate');
  const navigate = jest.fn();
  const NavigationMixin = (Base) =>
    class extends Base {
      [Navigate](pageReference) {
        navigate(pageReference);
      }
    };
  NavigationMixin.Navigate = Navigate;
  return { NavigationMixin, mockNavigate: navigate };
});

// The controller returns a map of records keyed by developer name
const MOCK_FIELDS = {
  Contact_Email: {
    Id: 'm00000000000001',
    Label: 'Contact Email',
    DeveloperName: 'Contact_Email',
    Object__c: 'Contact',
    Field_Name__c: 'Email'
  },
  Lead_Email: {
    Id: 'm00000000000002',
    Label: 'Lead Email',
    DeveloperName: 'Lead_Email',
    Object__c: 'Lead',
    Field_Name__c: 'Email'
  }
};

// Resolve pending promises so async handlers finish and the DOM re-renders
const flushPromises = async () => {
  for (let i = 0; i < 5; i++) {
    // eslint-disable-next-line no-await-in-loop
    await Promise.resolve();
  }
};

const createComponent = () => {
  const element = createElement('c-invalidate-email-fields-list', {
    is: InvalidateEmailFieldsList
  });
  document.body.appendChild(element);
  return element;
};

describe('c-invalidate-email-fields-list', () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it('shows the loading spinner until the wire provisions', () => {
    const element = createComponent();

    const card = element.shadowRoot.querySelector('lightning-card');
    expect(card.title).toBe('Invalidate Email Fields Configuration');
    expect(element.shadowRoot.querySelector('lightning-spinner')).not.toBeNull();
    expect(element.shadowRoot.querySelector('.slds-text-color_weak')).toBeNull();
  });

  it('displays each configured field in the data table', async () => {
    const element = createComponent();

    getInvalidateEmailFields.emit(MOCK_FIELDS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector('lightning-datatable');
    expect(datatable.data).toEqual(Object.values(MOCK_FIELDS));
    expect(datatable.columns.map((column) => column.label)).toEqual([
      'Label',
      'Developer Name',
      'Object',
      'Field Name',
      undefined
    ]);
    expect(datatable.columns[4].type).toBe('action');
    expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
  });

  it('displays the Apex error message when data loading fails', async () => {
    const element = createComponent();

    getInvalidateEmailFields.error({ message: 'Test error message' });
    await flushPromises();

    const errorDiv = element.shadowRoot.querySelector('.slds-theme_error');
    expect(errorDiv.textContent).toContain('Test error message');
    expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
    expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
    expect(element.shadowRoot.querySelector('.slds-text-color_weak')).toBeNull();
  });

  it('displays the no data message when no fields are configured', async () => {
    const element = createComponent();

    getInvalidateEmailFields.emit({});
    await flushPromises();

    const noDataMessage = element.shadowRoot.querySelector('.slds-text-color_weak');
    expect(noDataMessage.textContent).toBe('No Invalidate Email Fields configured.');
    expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
    expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
  });

  it('navigates to the record edit page from the edit row action', async () => {
    const element = createComponent();
    getInvalidateEmailFields.emit(MOCK_FIELDS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector('lightning-datatable');
    datatable.dispatchEvent(
      new CustomEvent('rowaction', {
        detail: { action: { name: 'edit' }, row: MOCK_FIELDS.Lead_Email }
      })
    );

    expect(mockNavigate).toHaveBeenCalledWith({
      type: 'standard__recordPage',
      attributes: {
        recordId: 'm00000000000002',
        objectApiName: 'Email_Invalidator_Fields__mdt',
        actionName: 'edit'
      }
    });
  });

  it('ignores unknown row actions', async () => {
    const element = createComponent();
    getInvalidateEmailFields.emit(MOCK_FIELDS);
    await flushPromises();

    const datatable = element.shadowRoot.querySelector('lightning-datatable');
    datatable.dispatchEvent(
      new CustomEvent('rowaction', {
        detail: { action: { name: 'delete' }, row: MOCK_FIELDS.Lead_Email }
      })
    );

    expect(mockNavigate).not.toHaveBeenCalled();
  });

  it('navigates to the custom metadata setup page from the Manage button', async () => {
    getCustomMetadataObjectPrefix.mockResolvedValue('m01');
    const element = createComponent();

    element.shadowRoot.querySelector('lightning-button').click();
    await flushPromises();

    expect(getCustomMetadataObjectPrefix).toHaveBeenCalledTimes(1);
    expect(mockNavigate).toHaveBeenCalledWith({
      type: 'standard__webPage',
      attributes: {
        url: '/lightning/setup/CustomMetadata/page?address=%2Fm01%3Fsetupid%3DCustomMetadata'
      }
    });
  });
});
