import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getInvalidateEmailFields from '@salesforce/apex/InvalidateEmailFieldsController.getInvalidateEmailFields';
import getInvalidateEmailMetadataPrefix from '@salesforce/apex/InvalidateEmailFieldsController.getCustomMetadataObjectPrefix';


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
  },
  {
    type: 'action',
    typeAttributes: {
      rowActions: [
        {
          label: 'Edit',
          name: 'edit'
        }
      ]
    }
  }
];

export default class InvalidateEmailFieldsList extends NavigationMixin(LightningElement) {
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

  handleRowAction(event) {
    const actionName = event.detail.action.name;
    const row = event.detail.row;

    if (actionName === 'edit') {
      // Navigate to the record page for editing
      this[NavigationMixin.Navigate]({
        type: 'standard__recordPage',
        attributes: {
          recordId: row.Id,
          objectApiName: 'Email_Invalidator_Fields__mdt',
          actionName: 'edit'
        }
      });
    }
  }

  async handleNewRecord() {
    const metadataPrefix = await getInvalidateEmailMetadataPrefix();
    // Navigate to the Custom Metadata Type management page
    this[NavigationMixin.Navigate]({
      type: 'standard__webPage',
      attributes: {
        url: '/lightning/setup/CustomMetadata/page?address=%2F' + metadataPrefix + '%3Fsetupid%3DCustomMetadata'
      }
    });
  }
}
