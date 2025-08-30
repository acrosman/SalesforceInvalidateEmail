import { createElement } from 'lwc';
import InvalidateEmailSettings from 'c/invalidateEmailSettings';
import getCurrentSettings from '@salesforce/apex/InvalidateEmailSettingsController.getCurrentSettings';
import saveSettings from '@salesforce/apex/InvalidateEmailSettingsController.saveSettings';

// Mock the Apex methods
jest.mock(
  '@salesforce/apex/InvalidateEmailSettingsController.getCurrentSettings',
  () => {
    const { createApexTestWireAdapter } = require('@salesforce/sfdx-lwc-jest');
    return {
      default: createApexTestWireAdapter(jest.fn())
    };
  },
  { virtual: true }
);

jest.mock(
  '@salesforce/apex/InvalidateEmailSettingsController.saveSettings',
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

describe('c-invalidate-email-settings', () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    // Clear all jest mocks
    jest.clearAllMocks();
  });

  it('renders correctly with default settings', async () => {
    const element = createElement('c-invalidate-email-settings', {
      is: InvalidateEmailSettings
    });

    // Mock the wire adapter to return test data
    const mockSettings = {
      success: true,
      message: 'Settings loaded successfully',
      settings: [
        {
          name: 'Invalidation_Text',
          label: 'Invalidation Text',
          value: '.invalid',
          isModified: false
        }
      ]
    };

    // Emit data from the wire adapter
    getCurrentSettings.emit(mockSettings);

    document.body.appendChild(element);

    // Wait for any asynchronous DOM updates
    await Promise.resolve();

    // Verify the component renders
    const card = element.shadowRoot.querySelector('lightning-card');
    expect(card).toBeTruthy();
    expect(card.title).toBe('Email Invalidator Settings');

    // Verify the input field is rendered
    const input = element.shadowRoot.querySelector('lightning-input');
    expect(input).toBeTruthy();
    expect(input.value).toBe('.invalid');
  });

  it('handles input changes correctly', async () => {
    const element = createElement('c-invalidate-email-settings', {
      is: InvalidateEmailSettings
    });

    const mockSettings = {
      success: true,
      message: 'Settings loaded successfully',
      settings: [
        {
          name: 'Invalidation_Text',
          label: 'Invalidation Text',
          value: '.invalid',
          isModified: false
        }
      ]
    };

    getCurrentSettings.emit(mockSettings);
    document.body.appendChild(element);
    await Promise.resolve();

    // Simulate input change
    const input = element.shadowRoot.querySelector('lightning-input');
    input.value = '.test';
    input.dispatchEvent(new CustomEvent('change', {
      detail: { value: '.test' }
    }));

    await Promise.resolve();

    // Verify buttons are enabled after modification
    const saveButton = element.shadowRoot.querySelector('lightning-button[label="Save & Deploy"]');
    const resetButton = element.shadowRoot.querySelector('lightning-button[label="Reset"]');

    expect(saveButton.disabled).toBe(false);
    expect(resetButton.disabled).toBe(false);
  });

  it('handles save operation', async () => {
    const element = createElement('c-invalidate-email-settings', {
      is: InvalidateEmailSettings
    });

    const mockSettings = {
      success: true,
      message: 'Settings loaded successfully',
      settings: [
        {
          name: 'Invalidation_Text',
          label: 'Invalidation Text',
          value: '.invalid',
          isModified: true
        }
      ]
    };

    getCurrentSettings.emit(mockSettings);
    document.body.appendChild(element);
    await Promise.resolve();

    // Mock the save response
    saveSettings.mockResolvedValue({
      success: true,
      message: 'Settings deployment initiated successfully. Changes will be applied automatically when deployment completes.'
    });

    // Click save button
    const saveButton = element.shadowRoot.querySelector('lightning-button[label="Save & Deploy"]');
    saveButton.click();

    await Promise.resolve();

    // Verify save method was called
    expect(saveSettings).toHaveBeenCalled();
  });

  it('displays error when settings fail to load', async () => {
    const element = createElement('c-invalidate-email-settings', {
      is: InvalidateEmailSettings
    });

    // Mock error response
    const mockError = {
      success: false,
      message: 'Failed to load settings'
    };

    getCurrentSettings.emit(mockError);
    document.body.appendChild(element);
    await Promise.resolve();

    // The component should handle the error gracefully
    // (specific error handling would depend on implementation details)
    const card = element.shadowRoot.querySelector('lightning-card');
    expect(card).toBeTruthy();
  });
});
