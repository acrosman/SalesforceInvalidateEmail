public with sharing class InvalidateEmailFieldsController {
  @AuraEnabled(cacheable=true)
  public static Map<String, Email_Invalidator_Fields__mdt> getInvalidateEmailFields() {
    Map<String, Email_Invalidator_Fields__mdt> emailFieldsMap = Email_Invalidator_Fields__mdt.getAll();
    return emailFieldsMap;
  }
}
