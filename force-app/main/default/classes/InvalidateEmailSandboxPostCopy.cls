global without sharing class InvalidateEmailSandboxPostCopy implements SandboxPostCopy {
  global InvalidateEmailSandboxPostCopy() {
    // Implementations of SandboxPostCopy must have a no-arg constructor.
    // This constructor is used during the sandbox copy process.
    // You can also implement constructors with arguments, but be aware that
    // they won’t be used by the sandbox copy process (unless as part of the
    // no-arg constructor).
  }

  global void runApexClass(SandboxContext context) {
    System.debug('Invalidating All Emails In ' + context.sandboxName());

    InvalidateEmailBatch.invalidateAllConfiguredEmails();
  }
}
