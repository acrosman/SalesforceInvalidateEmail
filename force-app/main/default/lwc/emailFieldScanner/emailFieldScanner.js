import { LightningElement } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCachedScanResults from '@salesforce/apex/EmailFieldScannerController.getCachedScanResults';
import deploySelectedFields from '@salesforce/apex/EmailFieldScannerController.deploySelectedFields';

const COLUMNS = [
  {
    label: 'Object Name',
    fieldName: 'objectName',
    type: 'text',
    sortable: true
  },
  {
    label: 'Field Name',
    fieldName: 'fieldName',
    type: 'text',
    sortable: true
  },
  {
    label: 'Field Label',
    fieldName: 'fieldLabel',
    type: 'text',
    sortable: true
  }
];

export default class EmailFieldScanner extends LightningElement {
  columns = COLUMNS;
  emailFieldsData = [];
  selectedRows = [];
  scanData = null;
  error = null;
  isLoading = true;
  isProcessing = false;

  // Sorting properties
  sortedBy = '';
  sortedDirection = 'asc';

  // Status fields
  lastModifiedDate = '';
  totalObjectsScanned = 0;
  totalEmailFieldsFound = 0;

  connectedCallback() {
    this.loadCachedResults();
  }

  async loadCachedResults() {
    this.isLoading = true;
    try {
      const data = await getCachedScanResults();
      this.isLoading = false;

      if (data && data.success) {
        this.scanData = data;
        this.error = null;

        // Set status fields
        this.lastModifiedDate = data.lastModifiedDate ? new Date(data.lastModifiedDate).toLocaleString() : 'N/A';
        this.totalObjectsScanned = data.totalObjectsScanned || 0;
        this.totalEmailFieldsFound = data.totalEmailFieldsFound || 0;

        // Process email fields data for the table
        if (data.newEmailFields && data.newEmailFields.length > 0) {
          this.emailFieldsData = data.newEmailFields.map((field, index) => ({
            ...field,
            uniqueKey: `${field.objectName}_${field.fieldName}_${index}`
          }));
        } else {
          this.emailFieldsData = [];
        }
      } else if (data && !data.success) {
        this.error = data.message || 'Failed to load scan results';
        this.scanData = null;
        this.emailFieldsData = [];
      }
    } catch (error) {
      this.isLoading = false;
      this.error = error.body?.message || 'Unknown error occurred while loading scan results';
      this.scanData = null;
      this.emailFieldsData = [];
    }
  }

  get hasEmailFields() {
    return this.emailFieldsData && this.emailFieldsData.length > 0;
  }

  get hasSelectedFields() {
    return this.selectedRows && this.selectedRows.length > 0;
  }

  handleRowSelection(event) {
    this.selectedRows = event.detail.selectedRows.map(row => row.uniqueKey);
  }

  handleSort(event) {
    const { fieldName: sortedBy, sortDirection } = event.detail;
    const cloneData = [...this.emailFieldsData];

    cloneData.sort(this.sortBy(sortedBy, sortDirection === 'asc' ? 1 : -1));
    this.emailFieldsData = cloneData;
    this.sortedDirection = sortDirection;
    this.sortedBy = sortedBy;
  }

  sortBy(field, reverse) {
    const key = function (x) {
      return x[field];
    };

    return function (a, b) {
      a = key(a);
      b = key(b);

      if (a === null || a === undefined) a = '';
      if (b === null || b === undefined) b = '';

      return reverse * ((a > b) - (b > a));
    };
  }

  async handleIncludeSelectedFields() {
    if (!this.hasSelectedFields) {
      this.showToast('Warning', 'Please select at least one field to include.', 'warning');
      return;
    }

    this.isProcessing = true;

    try {
      // Mark selected fields in the data
      const selectedFieldsData = this.emailFieldsData
        .filter(field => this.selectedRows.includes(field.uniqueKey))
        .map(field => ({
          ...field,
          selected: true
        }));

      // Call the Apex method to deploy selected fields
      const result = await deploySelectedFields({
        selectedFieldsJson: JSON.stringify(selectedFieldsData)
      });

      if (result.success) {
        this.showToast('Success', result.message, 'success');

        // Clear selections after successful deployment
        this.selectedRows = [];

        // Optionally refresh the data
        // You might want to refresh the wire service here if needed
      } else {
        this.showToast('Error', result.message, 'error');
      }
    } catch (error) {
      this.showToast('Error', 'An unexpected error occurred: ' + error.body?.message || error.message, 'error');
    } finally {
      this.isProcessing = false;
    }
  }

  showToast(title, message, variant) {
    const event = new ShowToastEvent({
      title: title,
      message: message,
      variant: variant
    });
    this.dispatchEvent(event);
  }
}
