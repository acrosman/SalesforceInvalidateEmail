/**
 * Test class for InvalidateEmailJobStatusController
 * Tests loading this app's batch jobs and grouping their statuses
 */
@isTest
private class InvalidateEmailJobStatusControllerTest {
  private static Integer contactCount = 10;

  @testSetup
  static void setupTestData() {
    InvalidateEmailTestDataFactory.createTestContacts(contactCount);
  }

  // Use a known field configuration so results don't depend on the
  // Email_Invalidator_Fields__mdt records in the org.
  private static void useContactEmailConfig() {
    InvalidateEmailBatch.configuredFieldsOverride = new Map<String, Set<String>>{
      'Contact' => new Set<String>{ 'Email' }
    };
  }

  @isTest
  static void testNoJobs() {
    Test.startTest();
    InvalidateEmailJobStatusController.JobStatusResponse response = InvalidateEmailJobStatusController.getRecentJobs();
    Test.stopTest();

    Assert.isTrue(response.success, 'Should be successful');
    Assert.areEqual(0, response.jobs.size(), 'Should find no jobs');
  }

  @isTest
  static void testQueuedJobIsReturned() {
    useContactEmailConfig();

    Test.startTest();
    Map<Id, String> started = InvalidateEmailBatch.invalidateAllConfiguredEmails();
    InvalidateEmailJobStatusController.JobStatusResponse response = InvalidateEmailJobStatusController.getRecentJobs();
    Test.stopTest();

    Assert.isTrue(response.success, 'Should be successful');
    Assert.areEqual(1, response.jobs.size(), 'Should find the started job');

    InvalidateEmailJobStatusController.JobInfo job = response.jobs[0];
    Assert.isTrue(
      started.containsKey(job.jobId),
      'Returned job should be the one that was started'
    );
    Assert.areEqual('Invalidate', job.jobType, 'Job label is wrong');
    Assert.areEqual(
      InvalidateEmailJobStatusController.GROUP_QUEUED,
      job.statusGroup,
      'Job should not have run yet'
    );
  }

  @isTest
  static void testCompletedJobsAreReturned() {
    useContactEmailConfig();

    Test.startTest();
    InvalidateEmailBatch.invalidateAllConfiguredEmails();
    InvalidateEmailUndoBatch.restoreAllConfiguredEmails();
    Test.stopTest();

    InvalidateEmailJobStatusController.JobStatusResponse response = InvalidateEmailJobStatusController.getRecentJobs();

    Assert.isTrue(response.success, 'Should be successful');
    Assert.areEqual(2, response.jobs.size(), 'Should find both jobs');

    Set<String> jobTypes = new Set<String>();
    for (InvalidateEmailJobStatusController.JobInfo job : response.jobs) {
      jobTypes.add(job.jobType);
      Assert.areEqual(
        InvalidateEmailJobStatusController.GROUP_COMPLETED,
        job.statusGroup,
        'Job should have completed'
      );
      Assert.areEqual(0, job.errors, 'Job should have no errors');
      Assert.areEqual(
        job.totalItems,
        job.itemsProcessed,
        'All batches should be processed'
      );
      Assert.isNotNull(job.completedDate, 'Completed date should be set');
      Assert.isNotNull(job.submittedBy, 'Submitter should be set');
    }
    Assert.areEqual(
      new Set<String>{ 'Invalidate', 'Restore' },
      jobTypes,
      'Both job types should be labelled'
    );
  }

  @isTest
  static void testStatusGroups() {
    Map<String, String> expected = new Map<String, String>{
      'Holding' => InvalidateEmailJobStatusController.GROUP_QUEUED,
      'Queued' => InvalidateEmailJobStatusController.GROUP_QUEUED,
      'Preparing' => InvalidateEmailJobStatusController.GROUP_QUEUED,
      'Processing' => InvalidateEmailJobStatusController.GROUP_RUNNING,
      'Completed' => InvalidateEmailJobStatusController.GROUP_COMPLETED,
      'Aborted' => InvalidateEmailJobStatusController.GROUP_ABORTED,
      'Failed' => InvalidateEmailJobStatusController.GROUP_FAILED
    };

    for (String status : expected.keySet()) {
      Assert.areEqual(
        expected.get(status),
        InvalidateEmailJobStatusController.getStatusGroup(status, 0),
        'Wrong group for status ' + status
      );
    }

    Assert.areEqual(
      InvalidateEmailJobStatusController.GROUP_COMPLETED_WITH_ERRORS,
      InvalidateEmailJobStatusController.getStatusGroup('Completed', 2),
      'Completed jobs with errors should be flagged'
    );
    Assert.areEqual(
      InvalidateEmailJobStatusController.GROUP_COMPLETED,
      InvalidateEmailJobStatusController.getStatusGroup('Completed', null),
      'Null error count should be treated as no errors'
    );
  }
}
