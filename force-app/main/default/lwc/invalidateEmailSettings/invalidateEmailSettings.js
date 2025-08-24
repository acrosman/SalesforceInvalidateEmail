import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import getCurrentSettings from '@salesforce/apex/InvalidateEmailSettingsController.getCurrentSettings';
import saveSettings from '@salesforce/apex/InvalidateEmailSettingsController.saveSettings';

export default class InvalidateEmailSettings extends LightningElement {
  @track settings = [];
  @track isLoading = false;
  @track isSaving = false;
  @track hasModifications = false;

  // Wire the getCurrentSettings method
  @wire(getCurrentSettings)
  wiredSettings({ error, data }) {
    if (data) {
      if (data.success) {
        this.settings = data.settings.map(setting => ({
          ...setting,
          isModified: false
        }));
        this.hasModifications = false;
      } else {
        this.showToast('Error', data.message, 'error');
      }
    } else if (error) {
      this.showToast('Error', 'Failed to load settings: ' + error.body.message, 'error');
    }
  }

  // Handle input changes
  handleInputChange(event) {
    const settingName = event.target.dataset.setting;
    const newValue = event.target.value;

    this.settings = this.settings.map(setting => {
      if (setting.name === settingName) {
        return {
          ...setting,
          value: newValue,
          isModified: true
        };
      }
      return setting;
    });

    this.hasModifications = this.settings.some(setting => setting.isModified);
  }

  // Handle save button click
  async handleSave() {
    this.isSaving = true;

    try {
      const settingsJson = JSON.stringify(this.settings);
      const result = await saveSettings({ settingsJson });

      if (result.success) {
        this.showToast('Success', result.message, 'success');

        // Reset modification flags
        this.settings = this.settings.map(setting => ({
          ...setting,
          isModified: false
        }));
        this.hasModifications = false;

        // Refresh the wire service to get updated values
        refreshApex(this.wiredSettings);
      } else {
        this.showToast('Error', result.message, 'error');
      }
    } catch (error) {
      this.showToast('Error', 'Failed to save settings: ' + error.body.message, 'error');
    } finally {
      this.isSaving = false;
    }
  }

  // Handle reset button click
  handleReset() {
    // Reset all settings to their original values
    this.settings = this.settings.map(setting => ({
      ...setting,
      isModified: false
    }));
    this.hasModifications = false;

    // Refresh the component to reload original values
    refreshApex(this.wiredSettings);
  }

  // Show toast message
  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }

  // Computed properties
  get saveButtonDisabled() {
    return !this.hasModifications || this.isSaving;
  }

  get resetButtonDisabled() {
    return !this.hasModifications || this.isSaving;
  }

  get statusMessage() {
    if (this.isSaving) {
      return 'Deploying settings...';
    }
    return '';
  }
}
