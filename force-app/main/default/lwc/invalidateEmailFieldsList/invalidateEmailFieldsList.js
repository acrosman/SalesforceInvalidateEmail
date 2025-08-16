import { LightningElement, wire } from 'lwc';
import getInvalidateEmailFields from '@salesforce/apex/InvalidateEmailFieldsController.getInvalidateEmailFields';

const COLUMNS = [
  {
    label: 'Label',
    fieldName: 'Label',
    type: 'text',
    sortable: true
  },
  {
    label: 'Developer Name',
    fieldName: 'DeveloperName',
    type: 'text',
    sortable: true
  },
  {
    label: 'Object',
    fieldName: 'Object__c',
    type: 'text',
    sortable: true
  },
  {
    label: 'Field Name',
    fieldName: 'Field_Name__c',
    type: 'text',
    sortable: true
  }
];

export default class InvalidateEmailFieldsList extends LightningElement {
  columns = COLUMNS;
  invalidateEmailFields = [];
  error;
  isLoading = true;

  @wire(getInvalidateEmailFields)
  wiredInvalidateEmailFields({ error, data }) {
    this.isLoading = false;
    if (data) {
      // Convert map to list
      const fieldList = [];
      const recordNames = Object.getOwnPropertyNames(data);
      for (let i = 0; i < recordNames.length; i++) {
        fieldList.push(data[recordNames[i]]);
      }
      this.invalidateEmailFields = fieldList;
      this.error = undefined;
    } else if (error) {
      this.error = error.body?.message || 'Unknown error occurred';
      this.invalidateEmailFields = [];
    }
  }

  get hasData() {
    return this.invalidateEmailFields && this.invalidateEmailFields.length > 0;
  }
}
