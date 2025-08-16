import { createElement } from '@lwc/engine-dom';
import InvalidateEmailFieldsList from 'c/invalidateEmailFieldsList';
import getInvalidateEmailFields from '@salesforce/apex/InvalidateEmailFieldsController.getInvalidateEmailFields';

// Mock the Apex method
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

describe('c-invalidate-email-fields-list', () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    // Clear all mocks
    jest.clearAllMocks();
  });

  it('renders the component with loading spinner initially', () => {
    // Arrange
    const element = createElement('c-invalidate-email-fields-list', {
      is: InvalidateEmailFieldsList
    });

    // Act
    document.body.appendChild(element);

    // Assert
    const card = element.shadowRoot.querySelector('lightning-card');
    expect(card).not.toBeNull();
    expect(card.title).toBe('Invalidate Email Fields Configuration');

    const spinner = element.shadowRoot.querySelector('lightning-spinner');
    expect(spinner).not.toBeNull();
  });

  it('displays data table when records are loaded', async () => {
    // Arrange
    const mockData = [
      {
        Id: 'test1',
        Label: 'Contact Email',
        DeveloperName: 'Contact_Email',
        Object__c: 'Contact',
        Field_Name__c: 'Email'
      },
      {
        Id: 'test2',
        Label: 'Lead Email',
        DeveloperName: 'Lead_Email',
        Object__c: 'Lead',
        Field_Name__c: 'Email'
      }
    ];

    const element = createElement('c-invalidate-email-fields-list', {
      is: InvalidateEmailFieldsList
    });
    document.body.appendChild(element);

    // Act
    getInvalidateEmailFields.emit(mockData);

    // Wait for async operations
    await Promise.resolve();

    // Assert
    const datatable = element.shadowRoot.querySelector('lightning-datatable');
    expect(datatable).not.toBeNull();
    expect(datatable.data).toEqual(mockData);

    const spinner = element.shadowRoot.querySelector('lightning-spinner');
    expect(spinner).toBeNull();
  });

  it('displays error message when data loading fails', async () => {
    // Arrange
    const mockError = {
      body: { message: 'Test error message' }
    };

    const element = createElement('c-invalidate-email-fields-list', {
      is: InvalidateEmailFieldsList
    });
    document.body.appendChild(element);

    // Act
    getInvalidateEmailFields.error(mockError);

    // Wait for async operations
    await Promise.resolve();

    // Assert
    const errorDiv = element.shadowRoot.querySelector('.slds-theme_error');
    expect(errorDiv).not.toBeNull();
    expect(errorDiv.textContent).toContain('Test error message');

    const datatable = element.shadowRoot.querySelector('lightning-datatable');
    expect(datatable).toBeNull();

    const spinner = element.shadowRoot.querySelector('lightning-spinner');
    expect(spinner).toBeNull();
  });

  it('displays no data message when no records exist', async () => {
    // Arrange
    const element = createElement('c-invalidate-email-fields-list', {
      is: InvalidateEmailFieldsList
    });
    document.body.appendChild(element);

    // Act
    getInvalidateEmailFields.emit([]);

    // Wait for async operations
    await Promise.resolve();

    // Assert
    const noDataMessage = element.shadowRoot.querySelector('.slds-text-color_weak');
    expect(noDataMessage).not.toBeNull();
    expect(noDataMessage.textContent).toBe('No Invalidate Email Fields configured.');

    const datatable = element.shadowRoot.querySelector('lightning-datatable');
    expect(datatable).toBeNull();

    const spinner = element.shadowRoot.querySelector('lightning-spinner');
    expect(spinner).toBeNull();
  });

  it('has correct column configuration', () => {
    // Arrange
    const element = createElement('c-invalidate-email-fields-list', {
      is: InvalidateEmailFieldsList
    });

    // Act
    document.body.appendChild(element);

    // Assert
    expect(element.columns).toHaveLength(4);
    expect(element.columns[0].label).toBe('Label');
    expect(element.columns[1].label).toBe('Developer Name');
    expect(element.columns[2].label).toBe('Object');
    expect(element.columns[3].label).toBe('Field Name');
  });
});
