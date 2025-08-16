public with sharing class InvalidateEmailFieldsController {
  @AuraEnabled(cacheable=true)
  public static List<Email_Invalidator_Fields__mdt> getInvalidateEmailFields() {
    Map<String, Email_Invalidator_Fields__mdt> emailFieldsMap = Email_Invalidator_Fields__mdt.getAll();
    List<Email_Invalidator_Fields__mdt> emailFieldsList = new List<Email_Invalidator_Fields__mdt>();

    // Convert map values to list for consistent ordering
    for (Email_Invalidator_Fields__mdt field : emailFieldsMap.values()) {
      emailFieldsList.add(field);
    }

    return emailFieldsList;
  }
}
