@IsTest
private class EmailFieldScannerControllerTest {
  private static EmailFieldScannerController.CachedEmailField buildField(
    String objectName,
    String fieldName,
    Boolean selected
  ) {
    EmailFieldScannerController.CachedEmailField field = new EmailFieldScannerController.CachedEmailField();
    field.objectName = objectName;
    field.fieldName = fieldName;
    field.fieldLabel = fieldName + ' Label';
    field.selected = selected;
    return field;
  }

  @IsTest
  static void testStartEmailFieldScanAuraSuccess() {
    Test.startTest();
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.startEmailFieldScanAura();
    Test.stopTest();

    Assert.isTrue(response.success, 'Expected success to be true');
    Assert.isTrue(
      response.message.contains(
        'Email field scanning batch job started successfully'
      ),
      'Expected success message'
    );
    Assert.areEqual(
      1,
      response.jobs.size(),
      'Expected the started job in the response'
    );
    Assert.areEqual(
      'All Objects',
      response.jobs.values()[0],
      'Expected the job to be labelled as scanning all objects'
    );

    List<AsyncApexJob> jobs = [
      SELECT Id
      FROM AsyncApexJob
      WHERE ApexClass.Name = 'EmailFieldScannerBatch'
    ];
    Assert.areEqual(1, jobs.size(), 'Expected one batch job to be started');
    Assert.isTrue(
      response.jobs.containsKey(jobs[0].Id),
      'Expected the response to return the started job Id'
    );
  }

  @IsTest
  static void testGetCachedScanResultsMatchesCacheRecord() {
    // Tests can't insert custom metadata, so check against whatever the org has
    List<Email_Invalidator_Cache__mdt> cacheRecords = [
      SELECT Cached_Value__c
      FROM Email_Invalidator_Cache__mdt
      WHERE DeveloperName = 'Field_Scan'
    ];

    Test.startTest();
    EmailFieldScannerController.CachedResultsResponse response = EmailFieldScannerController.getCachedScanResults();
    Test.stopTest();

    if (cacheRecords.isEmpty()) {
      Assert.isFalse(response.success, 'Expected failure without a cache');
      Assert.areEqual(
        'No cached scan results found. Please run a scan first.',
        response.message,
        'Expected the no cache message rather than a query error'
      );
    } else {
      Assert.areEqual(
        String.isNotBlank(cacheRecords[0].Cached_Value__c),
        response.success,
        'Expected success only when the cache has data'
      );
    }
  }

  @IsTest
  static void testParseCachedScanResults() {
    DateTime lastModified = DateTime.newInstanceGmt(2026, 1, 15, 12, 0, 0);
    String cachedValue = JSON.serialize(
      new Map<String, Object>{
        'scanDate' => '2026-01-15',
        'totalObjectsScanned' => 12,
        'totalEmailFieldsFound' => 7,
        'existingFieldsSkipped' => 3,
        'newEmailFields' => new List<Object>{
          new Map<String, Object>{
            'objectName' => 'Lead',
            'fieldName' => 'Alt_Email__c',
            'fieldLabel' => 'Alternate Email',
            'discoveredDate' => '2026-01-15'
          },
          new Map<String, Object>{
            'objectName' => 'Account',
            'fieldName' => 'Billing_Email__c',
            'fieldLabel' => 'Billing Email',
            'discoveredDate' => '2026-01-15'
          }
        }
      }
    );

    Test.startTest();
    EmailFieldScannerController.CachedResultsResponse response = EmailFieldScannerController.parseCachedScanResults(
      cachedValue,
      lastModified
    );
    Test.stopTest();

    Assert.isTrue(response.success, 'Expected the payload to parse');
    Assert.areEqual(
      'Cached scan results loaded successfully',
      response.message,
      'Expected the success message'
    );
    Assert.areEqual('2026-01-15', response.scanDate, 'Wrong scan date');
    Assert.areEqual(
      lastModified,
      response.lastModifiedDate,
      'Expected the cache record timestamp'
    );
    Assert.areEqual(12, response.totalObjectsScanned, 'Wrong object total');
    Assert.areEqual(7, response.totalEmailFieldsFound, 'Wrong field total');
    Assert.areEqual(3, response.existingFieldsSkipped, 'Wrong skipped total');
    Assert.areEqual(2, response.newEmailFields.size(), 'Expected two fields');

    EmailFieldScannerController.CachedEmailField first = response.newEmailFields[0];
    Assert.areEqual('Lead', first.objectName, 'Wrong object name');
    Assert.areEqual('Alt_Email__c', first.fieldName, 'Wrong field name');
    Assert.areEqual('Alternate Email', first.fieldLabel, 'Wrong field label');
    Assert.areEqual('2026-01-15', first.discoveredDate, 'Wrong discovery date');
    Assert.isFalse(first.selected, 'Fields should start unselected');
    Assert.areEqual('Lead.Alt_Email__c', first.uniqueKey, 'Wrong unique key');
  }

  @IsTest
  static void testParseCachedScanResultsBlank() {
    EmailFieldScannerController.CachedResultsResponse response = EmailFieldScannerController.parseCachedScanResults(
      '',
      DateTime.now()
    );

    Assert.isFalse(response.success, 'Expected failure for a blank cache');
    Assert.areEqual(
      'Cache record exists but contains no data',
      response.message,
      'Expected the empty cache message'
    );
  }

  @IsTest
  static void testParseCachedScanResultsCleared() {
    // clearCachedResults stores an empty JSON object
    EmailFieldScannerController.CachedResultsResponse response = EmailFieldScannerController.parseCachedScanResults(
      '{}',
      DateTime.now()
    );

    Assert.isTrue(response.success, 'A cleared cache should still load');
    Assert.isTrue(
      response.newEmailFields.isEmpty(),
      'A cleared cache should have no fields'
    );
    Assert.isNull(response.totalObjectsScanned, 'Expected no object total');
  }

  @IsTest
  static void testParseCachedScanResultsInvalidJson() {
    try {
      EmailFieldScannerController.parseCachedScanResults(
        'not json',
        DateTime.now()
      );
      Assert.fail('Expected invalid JSON to throw');
    } catch (JSONException e) {
      Assert.isNotNull(e.getMessage(), 'Expected a JSON parsing error');
    }
  }

  @IsTest
  static void testDeploySelectedFieldsDeploysOnlySelected() {
    List<EmailFieldScannerController.CachedEmailField> fields = new List<EmailFieldScannerController.CachedEmailField>{
      buildField('Lead', 'Alt_Email__c', true),
      buildField('Account', 'Billing_Email__c', false),
      buildField('Case', 'Notify_Email__c', true)
    };

    Test.startTest();
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.deploySelectedFields(
      JSON.serialize(fields)
    );
    Test.stopTest();

    Assert.isTrue(response.success, 'Expected the deployment to start');
    Assert.areEqual(
      'Successfully initiated deployment of 2 email field(s)',
      response.message,
      'Expected only the selected fields to be counted'
    );
  }

  @IsTest
  static void testDeploySelectedFieldsNoneMarkedSelected() {
    List<EmailFieldScannerController.CachedEmailField> fields = new List<EmailFieldScannerController.CachedEmailField>{
      buildField('Lead', 'Alt_Email__c', false)
    };

    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.deploySelectedFields(
      JSON.serialize(fields)
    );

    Assert.isFalse(response.success, 'Nothing should deploy');
    Assert.areEqual(
      'No fields were marked as selected for deployment',
      response.message,
      'Expected the none selected message'
    );
  }

  @IsTest
  static void testDeploySelectedFieldsEmptyList() {
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.deploySelectedFields(
      '[]'
    );

    Assert.isFalse(response.success, 'Nothing should deploy');
    Assert.areEqual(
      'No fields selected for deployment',
      response.message,
      'Expected the empty list message'
    );
  }

  @IsTest
  static void testDeploySelectedFieldsInvalidJson() {
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.deploySelectedFields(
      'not json'
    );

    Assert.isFalse(response.success, 'Invalid input should fail');
    Assert.isTrue(
      response.message.startsWith('Error deploying selected fields: '),
      'Expected the deployment error message'
    );
  }

  @IsTest
  static void testClearCachedResults() {
    Test.startTest();
    EmailFieldScannerController.EmailScanResponse response = EmailFieldScannerController.clearCachedResults();
    Test.stopTest();

    Assert.isTrue(response.success, 'Expected the cache clear to start');
    Assert.areEqual(
      'Cache cleared successfully',
      response.message,
      'Expected the cache cleared message'
    );
  }

  @IsTest
  static void testGenerateUniqueMetadataRecordName() {
    Set<String> usedNames = new Set<String>();

    String name = EmailFieldScannerController.generateUniqueMetadataRecordName(
      'Account',
      'Billing_Email__c',
      usedNames
    );

    Assert.areEqual('Account_Billing_Email', name, 'Wrong record name');
    Assert.isTrue(usedNames.contains(name), 'Name should be marked as used');
  }

  @IsTest
  static void testGenerateUniqueMetadataRecordNameCleansCharacters() {
    String name = EmailFieldScannerController.generateUniqueMetadataRecordName(
      '1Object__c',
      'Email-Field__c',
      new Set<String>()
    );

    Assert.areEqual(
      'Field_1Object_Email_Field',
      name,
      'Expected invalid characters replaced and a letter prefix'
    );
  }

  @IsTest
  static void testGenerateUniqueMetadataRecordNameAddsSuffix() {
    Set<String> usedNames = new Set<String>{ 'Lead_Email', 'Lead_Email_1' };

    String name = EmailFieldScannerController.generateUniqueMetadataRecordName(
      'Lead',
      'Email',
      usedNames
    );

    Assert.areEqual('Lead_Email_2', name, 'Expected the next free suffix');
    Assert.areEqual(3, usedNames.size(), 'New name should be marked as used');
  }

  @IsTest
  static void testGenerateUniqueMetadataRecordNameTruncates() {
    String longObject = 'Very_Long_Object_Name_For_Testing__c';
    String longField = 'Secondary_Email_Address__c';
    Set<String> usedNames = new Set<String>();

    String first = EmailFieldScannerController.generateUniqueMetadataRecordName(
      longObject,
      longField,
      usedNames
    );
    String second = EmailFieldScannerController.generateUniqueMetadataRecordName(
      longObject,
      longField,
      usedNames
    );

    Assert.areEqual(
      'Very_Long_Object_Name_For_Testing_Second',
      first,
      'Expected the name cut to 40 characters'
    );
    Assert.areEqual(
      'Very_Long_Object_Name_For_Testing_Seco_1',
      second,
      'Expected the suffix to fit within 40 characters'
    );
  }
}
