/**
 * Reports how much of the data in each configured email field has already
 * been invalidated. The LWC requests each field separately so a slow count on
 * a large object only affects that field's row.
 * Runs without sharing so the counts cover every record the batch jobs
 * process, not just those the current user can see. Only counts are returned.
 */
public without sharing class InvalidateEmailFieldStatusController {
  /**
   * Gets the configured email fields, sorted by object and field name.
   * Not cacheable so a refresh picks up newly configured fields.
   * @return ConfiguredFieldsResponse containing the fields to report on
   */
  @AuraEnabled
  public static ConfiguredFieldsResponse getConfiguredFields() {
    ConfiguredFieldsResponse response = new ConfiguredFieldsResponse();
    response.fields = new List<FieldRef>();

    try {
      Map<String, Set<String>> objectFields = InvalidateEmailBatch.getConfiguredFields();
      List<String> objectNames = new List<String>(objectFields.keySet());
      objectNames.sort();
      for (String objectName : objectNames) {
        List<String> fieldNames = new List<String>(
          objectFields.get(objectName)
        );
        fieldNames.sort();
        for (String fieldName : fieldNames) {
          response.fields.add(new FieldRef(objectName, fieldName));
        }
      }

      response.success = true;
      response.message =
        'Found ' +
        response.fields.size() +
        ' configured fields.';
    } catch (Exception e) {
      response.success = false;
      response.message = 'Error loading configured fields: ' + e.getMessage();
      System.debug(
        'Error in InvalidateEmailFieldStatusController.getConfiguredFields: ' +
        e.getMessage()
      );
    }

    return response;
  }

  /**
   * Counts the non-blank and invalidated values in one configured field.
   * @param objectName API name of the object
   * @param fieldName API name of the email field
   * @return FieldStatus with the counts, or an error message
   */
  @AuraEnabled
  public static FieldStatus getFieldStatus(String objectName, String fieldName) {
    FieldStatus status = new FieldStatus(objectName, fieldName);

    try {
      // Only configured fields may be queried, which also keeps the dynamic
      // SOQL below limited to known object and field names.
      Set<String> configured = InvalidateEmailBatch.getConfiguredFields()
        .get(objectName);
      if (configured == null || !configured.contains(fieldName)) {
        status.success = false;
        status.message = 'Field is not configured for invalidation.';
        return status;
      }

      // COUNT() uses a single query row however many records match.
      String baseQuery =
        'SELECT COUNT() FROM ' +
        objectName +
        ' WHERE ' +
        fieldName +
        ' != null';
      Integer nonBlank = Database.countQuery(baseQuery);

      String invalidPattern =
        '%' + escapeLikePattern(InvalidateEmailSettings.getInvalidationText());
      Integer invalidated = nonBlank == 0
        ? 0
        : Database.countQuery(
            baseQuery + ' AND ' + fieldName + ' LIKE :invalidPattern'
          );

      status.nonBlankCount = nonBlank;
      status.invalidatedCount = invalidated;
      status.percentInvalidated = nonBlank > 0
        ? (Decimal) invalidated / nonBlank
        : 0;
      status.success = true;
      status.message = 'Counted ' + nonBlank + ' records.';
    } catch (Exception e) {
      status.success = false;
      status.message = 'Error counting records: ' + e.getMessage();
      System.debug(
        'Error in InvalidateEmailFieldStatusController.getFieldStatus: ' +
        e.getMessage()
      );
    }

    return status;
  }

  // Escapes LIKE wildcards so the invalidation text is matched literally.
  @TestVisible
  private static String escapeLikePattern(String value) {
    return value.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
  }

  // Response class for the configured fields list
  public class ConfiguredFieldsResponse {
    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String message;

    @AuraEnabled
    public List<FieldRef> fields;
  }

  // An object and field pair that is configured for invalidation
  public class FieldRef {
    @AuraEnabled
    public String objectName;

    @AuraEnabled
    public String fieldName;

    public FieldRef(String objectName, String fieldName) {
      this.objectName = objectName;
      this.fieldName = fieldName;
    }
  }

  // Invalidation counts for a single field
  public class FieldStatus {
    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String message;

    @AuraEnabled
    public String objectName;

    @AuraEnabled
    public String fieldName;

    @AuraEnabled
    public Integer nonBlankCount;

    @AuraEnabled
    public Integer invalidatedCount;

    // Fraction from 0 to 1, as lightning-formatted-number expects for percent
    @AuraEnabled
    public Decimal percentInvalidated;

    public FieldStatus(String objectName, String fieldName) {
      this.objectName = objectName;
      this.fieldName = fieldName;
    }
  }
}
