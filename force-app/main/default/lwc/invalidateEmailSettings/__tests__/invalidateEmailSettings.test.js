import { createElement } from '@lwc/engine-dom';
import InvalidateEmailSettings from 'c/invalidateEmailSettings';
import { refreshApex } from '@salesforce/apex';
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
  () => ({ default: jest.fn() }),
  { virtual: true }
);

jest.mock(
  '@salesforce/apex',
  () => ({ refreshApex: jest.fn(() => Promise.resolve()) }),
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

const MOCK_SETTINGS = {
  success: true,
  message: 'Settings loaded successfully',
  settings: [
    {
      name: 'Invalidation_Text',
      label: 'Invalidation Text',
      value: '.invalid'
    },
    {
      name: 'Batch_Size',
      label: 'Batch Size',
      value: '200'
    }
  ]
};

// Resolve pending promises so async handlers finish and the DOM re-renders
const flushPromises = async () => {
  for (let i = 0; i < 5; i++) {
    // eslint-disable-next-line no-await-in-loop
    await Promise.resolve();
  }
};

const createComponent = async (settings = MOCK_SETTINGS) => {
  const element = createElement('c-invalidate-email-settings', {
    is: InvalidateEmailSettings
  });
  element.toasts = [];
  element.addEventListener('lightning__showtoast', (event) => element.toasts.push(event.detail));
  document.body.appendChild(element);
  if (settings) {
    getCurrentSettings.emit(settings);
  }
  await flushPromises();
  return element;
};

const getButton = (element, label) =>
  Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find(
    (button) => button.label === label
  );

const getInput = (element, name) =>
  element.shadowRoot.querySelector(`lightning-input[data-setting="${name}"]`);

const changeInput = async (element, name, value) => {
  const input = getInput(element, name);
  input.value = value;
  input.dispatchEvent(new CustomEvent('change'));
  await flushPromises();
};

describe('c-invalidate-email-settings', () => {
  afterEach(() => {
    // The jsdom instance is shared across test cases in a single file so reset the DOM
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it('renders an input for each setting with the buttons disabled', async () => {
    const element = await createComponent();

    const inputs = element.shadowRoot.querySelectorAll('lightning-input');
    expect(Array.from(inputs).map((input) => input.value)).toEqual(['.invalid', '200']);
    expect(getButton(element, 'Save & Deploy').disabled).toBe(true);
    expect(getButton(element, 'Reset').disabled).toBe(true);
    expect(element.shadowRoot.querySelector('.slds-text-color_success')).toBeNull();
  });

  it('shows an error toast when Apex reports the settings could not load', async () => {
    const element = await createComponent({ success: false, message: 'No settings record' });

    expect(element.shadowRoot.querySelectorAll('lightning-input')).toHaveLength(0);
    expect(element.toasts).toEqual([
      { title: 'Error', message: 'No settings record', variant: 'error' }
    ]);
  });

  it('shows an error toast when the wire returns an error', async () => {
    const element = await createComponent(null);

    getCurrentSettings.error({ message: 'Insufficient access' });
    await flushPromises();

    expect(element.toasts).toEqual([
      { title: 'Error', message: 'Failed to load settings: Insufficient access', variant: 'error' }
    ]);
  });

  it('marks an edited setting as modified and enables the buttons', async () => {
    const element = await createComponent();

    await changeInput(element, 'Invalidation_Text', '.test');

    expect(getButton(element, 'Save & Deploy').disabled).toBe(false);
    expect(getButton(element, 'Reset').disabled).toBe(false);
    expect(element.shadowRoot.querySelectorAll('.slds-text-color_success')).toHaveLength(1);
  });

  it('saves the edited settings and refreshes the wire', async () => {
    saveSettings.mockResolvedValue({ success: true, message: 'Settings deployment initiated' });
    const element = await createComponent();
    await changeInput(element, 'Invalidation_Text', '.test');

    getButton(element, 'Save & Deploy').click();
    await flushPromises();

    expect(saveSettings).toHaveBeenCalledTimes(1);
    const saved = JSON.parse(saveSettings.mock.calls[0][0].settingsJson);
    expect(saved).toEqual([
      { ...MOCK_SETTINGS.settings[0], value: '.test', isModified: true },
      { ...MOCK_SETTINGS.settings[1], isModified: false }
    ]);
    expect(element.toasts).toEqual([
      { title: 'Success', message: 'Settings deployment initiated', variant: 'success' }
    ]);
    expect(refreshApex).toHaveBeenCalledWith(
      expect.objectContaining({ data: MOCK_SETTINGS })
    );
    expect(getButton(element, 'Save & Deploy').disabled).toBe(true);
    expect(element.shadowRoot.querySelector('.slds-text-color_success')).toBeNull();
  });

  it('shows the deploying message while the save is in progress', async () => {
    saveSettings.mockReturnValue(new Promise(() => {}));
    const element = await createComponent();
    await changeInput(element, 'Invalidation_Text', '.test');

    getButton(element, 'Save & Deploy').click();
    await flushPromises();

    expect(element.shadowRoot.querySelector('.slds-alert_info').textContent).toContain(
      'Deploying settings...'
    );
    expect(getButton(element, 'Save & Deploy').disabled).toBe(true);
    expect(getButton(element, 'Reset').disabled).toBe(true);
  });

  it('keeps the edits when Apex reports the save failed', async () => {
    saveSettings.mockResolvedValue({ success: false, message: 'Value is required' });
    const element = await createComponent();
    await changeInput(element, 'Invalidation_Text', '.test');

    getButton(element, 'Save & Deploy').click();
    await flushPromises();

    expect(element.toasts).toEqual([
      { title: 'Error', message: 'Value is required', variant: 'error' }
    ]);
    expect(refreshApex).not.toHaveBeenCalled();
    expect(getButton(element, 'Save & Deploy').disabled).toBe(false);
  });

  it('shows an error toast when the save call throws', async () => {
    saveSettings.mockRejectedValue({ body: { message: 'Metadata API disabled' } });
    const element = await createComponent();
    await changeInput(element, 'Invalidation_Text', '.test');

    getButton(element, 'Save & Deploy').click();
    await flushPromises();

    expect(element.toasts).toEqual([
      {
        title: 'Error',
        message: 'Failed to save settings: Metadata API disabled',
        variant: 'error'
      }
    ]);
    expect(getButton(element, 'Save & Deploy').disabled).toBe(false);
  });

  it('restores the loaded values on reset', async () => {
    const element = await createComponent();
    await changeInput(element, 'Invalidation_Text', '.test');

    getButton(element, 'Reset').click();
    await flushPromises();

    expect(getInput(element, 'Invalidation_Text').value).toBe('.invalid');
    expect(getButton(element, 'Save & Deploy').disabled).toBe(true);
    expect(getButton(element, 'Reset').disabled).toBe(true);
    expect(element.shadowRoot.querySelector('.slds-text-color_success')).toBeNull();
  });
});
