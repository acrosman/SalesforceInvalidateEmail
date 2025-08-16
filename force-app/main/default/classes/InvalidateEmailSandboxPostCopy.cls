public with sharing class InvalidateEmailSandboxPostCopy implements SandboxPostCopy {
    global PrepareMySandbox() {
        // Implementations of SandboxPostCopy must have a no-arg constructor.
        // This constructor is used during the sandbox copy process.
        // You can also implement constructors with arguments, but be aware that
        // they won’t be used by the sandbox copy process (unless as part of the
        // no-arg constructor).
        this(some_args);
    }

    global PrepareMySandbox(String some_args) {
        // Logic for constructor.
    }

    global void runApexClass(SandboxContext context) {
        System.debug('Org ID: ' + context.organizationId());
        System.debug('Sandbox ID: ' + context.sandboxId());
        System.debug('Sandbox Name: ' + context.sandboxName());

        // Insert logic here to prepare the sandbox for use.
    }
}
