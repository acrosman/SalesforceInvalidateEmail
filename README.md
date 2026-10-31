# Salesforce Email Invalidator

[![Jest Tests](https://github.com/acrosman/SalesforceInvalidateEmail/actions/workflows/jest.yml/badge.svg?branch=main)](https://github.com/acrosman/SalesforceInvalidateEmail/actions/workflows/jest.yml?query=branch%3Amain)
[![Apex Tests](https://github.com/acrosman/SalesforceInvalidateEmail/actions/workflows/apex.yml/badge.svg?branch=main)](https://github.com/acrosman/SalesforceInvalidateEmail/actions/workflows/apex.yml?query=branch%3Amain)

A simple tool to invalidate all the email addresses in your Salesforce org. This is meant to be used in Sandboxes to avoid accidentally sending email to everyone in the org (which comes up more than people expect).

Currently this tool consists of unpackaged metadata. At some point I'll work on getting it packaged, but this is still an early draft.

## Installation

This project is loose metadata, not a package, so you install it by deploying the source with the Salesforce CLI.

### Prerequisites

- [Salesforce CLI](https://developer.salesforce.com/tools/salesforcecli) (`sf`).
- [Git](https://git-scm.com/), or download this repository as a zip file.
- A user in the target org who can deploy metadata, such as a System Administrator.

### Choose an org

- **A sandbox** if you only want to invalidate emails in that sandbox.
- **Production** if you want the [Sandbox Post Copy Process](#sandbox-post-copy-process) to run when you create or refresh sandboxes. Sandboxes copy their metadata from production, so the class has to be in production first. Nothing runs in production unless someone starts it.

### Deploy

1. Clone the repository:

   ```sh
   git clone https://github.com/acrosman/SalesforceInvalidateEmail.git
   cd SalesforceInvalidateEmail
   ```

2. Log in to the org and give it an alias. For a sandbox add `--instance-url https://test.salesforce.com`:

   ```sh
   sf org login web --alias invalidator-target
   ```

3. Deploy the source. Production deploys must run the Apex tests, so add `--test-level RunLocalTests` there:

   ```sh
   sf project deploy start --source-dir force-app --target-org invalidator-target
   ```

4. Assign the Invalidate Emails permission set to each user who will run the tool (see [Permission Sets](#permission-sets)):

   ```sh
   sf org assign permset --name Invalidate_Emails --target-org invalidator-target
   ```

   Without `--on-behalf-of` this assigns it to the logged-in user. You can also assign it in Setup under Permission Sets.

The deploy includes a field record for `Contact.Email` and the `Invalidation_Text` setting set to `.invalid`. Deploying again later resets those two records to the values in this repository.

### Set up

1. Open the app launcher and search for `Invalidate Email` to open the Invalidate Email Addresses app.
2. Choose the email fields to invalidate. `Contact.Email` is included. To add more fields, either:
   - Click **Scan For Email Fields**. When the scan job finishes, the Email Field Scanner Results card lists email fields that aren't configured yet. Select the ones you want and click **Include Selected Fields**.
   - Or click **Manage** on the Invalidate Email Fields Configuration card, click **New**, and pick the Object and Field Name.
3. Optionally, change the text added to each address in the Email Invalidator Settings card and click **Save & Deploy**. The default is `.invalid`.

Scanned fields and settings are saved by deploying Custom Metadata, which finishes in the background. They can take a minute to appear. When you include scanned fields, you get an email once their deploy finishes.

### Run it

1. Check Setup > Email > Deliverability. While emails are being invalidated it is safest to set access to **System email only** or **No access**. New sandboxes start at **System email only**.
2. Click **Invalidate Emails**. One batch job starts for each configured object.
3. Follow the jobs in the Email Invalidator Jobs card. When they finish, the Field Invalidation Status card shows how many values in each field are invalidated.

To undo it, click **Restore Emails**, which removes the invalidation text from the configured fields.

## Main App

The project provides an Invalid Email App which shows a list of the fields that are setup to be invalided, and a Lightening Web Component to initiate the process of adding `.invalid` to the end of all values in that field.

You can add Custom Metadata records to list all email fields on any object, so all emails can be disabled.

Email fields are limited to 80 characters, so the invalidated value is kept within the field's limit:

- If the invalidated value fits, `.invalid` is appended as usual.
- If the address is shorter than the limit but the invalidated value is not, the value is cut off at the limit (for example ending in `.inv`). These addresses can still be fully restored.
- If the address is already at the limit, the end of the address is removed to make room for the full `.invalid`. These addresses can NOT be fully restored.

You can find the app in the app switcher by searching for `Invalidate Email`.

![Screenshot of the app's main interface](docs/InvalidatorScreenShot.png)

### Job Status

The Email Invalidator Jobs card on the app page lists the invalidate, restore, and field scan batch jobs from the last 7 days, with their status, progress, and any errors. While jobs are queued or running the card refreshes itself every few seconds, and it stops once they have all finished. The object each job is processing is shown for jobs started from the page during your current visit.

### Field Invalidation Status

The Field Invalidation Status card lists each configured email field with the number of records that have a value in that field and the percentage of those values that currently end with the invalidation text. Each field is counted separately, so if one field can't be counted its row shows the error and the others still load. The card refreshes itself when an Email Invalidator job finishes.

## Permission Sets

Anyone you want to be able to use this process should be assigned the included Invalidate Emails permission set.

Users who only need to build or run flows that use the Invalidate All Configured Emails or Restore All Configured Emails flow actions can instead be assigned the Invalidation Flow Users permission set.

## Sandbox Post Copy Process

There is also a SandboxPostCopy class you can use to have the process run as soon as a Sandbox refresh or create completes. This is only useful in a full or partial copy sandbox.

When you create a sandbox there is a field that allows you to indicate classes you want run after the process completes. Enter `InvalidateEmailSandboxPostCopy` and the process defined here will run.

The class and the field records must be deployed to production for this to work, because the new sandbox gets its metadata from production. It invalidates the fields configured in production when the sandbox was copied.

## Automated Testing

Every pull request to `main` runs two workflows: [Jest Tests](.github/workflows/jest.yml) runs the LWC Jest tests, and [Apex Tests](.github/workflows/apex.yml) runs the Apex tests. The Apex tests run in a new scratch org that is deleted when the run finishes.

The Apex job signs in to the project's Dev Hub using the JWT bearer flow and an External Client App, and needs these repository secrets:

- `SF_CONSUMER_KEY`: the External Client App's consumer key.
- `SF_JWT_KEY`: the private key matching the certificate uploaded to the External Client App.
- `SF_USERNAME`: the Dev Hub user the workflow signs in as.

## Planned Features

- Scan for Email Fields: It would be helpful to have a process that scans the org for email fields and adds custom metadata records for those fields to the system.
- Un-Invalidate Fields: Adding `.invalid` is helpful. It would also be nice to easily remove it again under some conditions.

Suggestions welcome. Please create a new [Issue](https://github.com/acrosman/SalesforceInvalidateEmail/issues) and submit your ideas.
