public with sharing class InvalidateEmailJobStatusController {
  // Batch classes started by this app, mapped to a friendly job label.
  @TestVisible
  private static final Map<String, String> TRACKED_CLASSES = new Map<String, String>{
    'InvalidateEmailBatch' => 'Invalidate',
    'InvalidateEmailUndoBatch' => 'Restore',
    'EmailFieldScannerBatch' => 'Field Scan'
  };

  // Status groups the LWC uses for display and to decide when to poll.
  public static final String GROUP_QUEUED = 'Queued';
  public static final String GROUP_RUNNING = 'Running';
  public static final String GROUP_COMPLETED = 'Completed';
  public static final String GROUP_COMPLETED_WITH_ERRORS = 'Completed with Errors';
  public static final String GROUP_FAILED = 'Failed';
  public static final String GROUP_ABORTED = 'Aborted';

  private static final Integer MAX_JOBS = 50;

  /**
   * Gets this app's batch jobs from the last 7 days, newest first.
   * Not cacheable because the component polls it for live status.
   * @return JobStatusResponse containing the recent jobs
   */
  @AuraEnabled
  public static JobStatusResponse getRecentJobs() {
    JobStatusResponse response = new JobStatusResponse();
    response.jobs = new List<JobInfo>();

    try {
      Set<String> classNames = TRACKED_CLASSES.keySet();
      for (AsyncApexJob job : [
        SELECT
          Id,
          ApexClass.Name,
          Status,
          ExtendedStatus,
          JobItemsProcessed,
          TotalJobItems,
          NumberOfErrors,
          CreatedDate,
          CompletedDate,
          CreatedBy.Name
        FROM AsyncApexJob
        WHERE
          JobType = 'BatchApex'
          AND ApexClass.Name IN :classNames
          AND CreatedDate = LAST_N_DAYS:7
        ORDER BY CreatedDate DESC
        LIMIT :MAX_JOBS
      ]) {
        response.jobs.add(new JobInfo(job));
      }

      response.success = true;
      response.message = 'Found ' + response.jobs.size() + ' recent jobs.';
    } catch (Exception e) {
      response.success = false;
      response.message = 'Error loading batch job status: ' + e.getMessage();
      System.debug(
        'Error in InvalidateEmailJobStatusController.getRecentJobs: ' +
        e.getMessage()
      );
    }

    return response;
  }

  // Collapses AsyncApexJob.Status values into the groups shown in the UI.
  @TestVisible
  private static String getStatusGroup(String status, Integer numberOfErrors) {
    switch on status {
      when 'Holding', 'Queued', 'Preparing' {
        return GROUP_QUEUED;
      }
      when 'Processing' {
        return GROUP_RUNNING;
      }
      when 'Completed' {
        return (numberOfErrors != null &&
          numberOfErrors > 0)
          ? GROUP_COMPLETED_WITH_ERRORS
          : GROUP_COMPLETED;
      }
      when 'Aborted' {
        return GROUP_ABORTED;
      }
      when else {
        return GROUP_FAILED;
      }
    }
  }

  // Response class for the AuraEnabled method
  public class JobStatusResponse {
    @AuraEnabled
    public Boolean success;

    @AuraEnabled
    public String message;

    @AuraEnabled
    public List<JobInfo> jobs;
  }

  // Display-ready details for a single batch job
  public class JobInfo {
    @AuraEnabled
    public Id jobId;

    @AuraEnabled
    public String jobType;

    @AuraEnabled
    public String status;

    @AuraEnabled
    public String statusGroup;

    @AuraEnabled
    public Integer itemsProcessed;

    @AuraEnabled
    public Integer totalItems;

    @AuraEnabled
    public Integer errors;

    @AuraEnabled
    public String extendedStatus;

    @AuraEnabled
    public Datetime createdDate;

    @AuraEnabled
    public Datetime completedDate;

    @AuraEnabled
    public String submittedBy;

    public JobInfo(AsyncApexJob job) {
      this.jobId = job.Id;
      this.jobType = TRACKED_CLASSES.get(job.ApexClass.Name);
      this.status = job.Status;
      this.statusGroup = getStatusGroup(job.Status, job.NumberOfErrors);
      this.itemsProcessed = job.JobItemsProcessed;
      this.totalItems = job.TotalJobItems;
      this.errors = job.NumberOfErrors;
      this.extendedStatus = job.ExtendedStatus;
      this.createdDate = job.CreatedDate;
      this.completedDate = job.CompletedDate;
      this.submittedBy = job.CreatedBy?.Name;
    }
  }
}
