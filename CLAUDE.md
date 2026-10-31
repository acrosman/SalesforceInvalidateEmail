# CLAUDE.md

Salesforce Email Invalidator: unpackaged Salesforce metadata (Apex + LWC + Custom Metadata) that appends `.invalid` to every configured email field in an org, so sandboxes don't email real people. It can also restore the values and scan the org for email fields to configure. See [README.md](README.md) for user-facing behavior.

## Where things are

All deployable source is in `force-app/main/default/` (API version 65.0, no namespace).

### Apex (`classes/`)

Each class has a matching `*Test.cls`. `InvalidateEmailTestDataFactory` builds shared test data.

| Area                       | Classes                                                                                                                           |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| Invalidate                 | `InvalidateEmailBatch` (batch job and the `invalidateValue` / `restoreValue` / `isInvalidated` string logic, 80-char field limit) |
| Restore                    | `InvalidateEmailUndoBatch`                                                                                                        |
| Entry points for the above | `InvalidateEmailFlowAction`, `InvalidateEmailUndoFlowAction` (both `@AuraEnabled` for LWC and `@InvocableMethod` for Flow)        |
| Sandbox refresh hook       | `InvalidateEmailSandboxPostCopy` (`SandboxPostCopy`, runs the invalidate batch)                                                   |
| Field scanning             | `EmailFieldScannerBatch`, `EmailFieldScannerController`, `EmailFieldCacheDeployCallback`, `EmailFieldMetadataDeployCallback`      |
| Settings                   | `InvalidateEmailSettings` (reads the invalidation text, default `.invalid`), `InvalidateEmailSettingsController`                  |
| UI controllers             | `InvalidateEmailFieldsController`, `InvalidateEmailFieldStatusController`, `InvalidateEmailJobStatusController`                   |

The batch classes run `without sharing` so they reach every record; UI controllers are `with sharing` unless they need org-wide counts.

### Custom Metadata (`objects/`, `customMetadata/`, `layouts/`)

- `Email_Invalidator_Fields__mdt`: one record per object/field to invalidate (`Object__c`, `Field_Name__c`).
- `Email_Invalidator_Settings__mdt`: key/value settings (`Setting_Value__c`), e.g. `Invalidation_Text`.
- `Email_Invalidator_Cache__mdt`: stores field scan results as JSON. Records are created at runtime and excluded by `.forceignore`.

Scan results and settings are written back to Custom Metadata through `Metadata.Operations` deploys, which complete asynchronously via the `*DeployCallback` classes.

### LWC (`lwc/`)

Each component has Jest tests in `__tests__/`.

- `invalidateEmail`: buttons to start invalidate, restore, and field scan jobs.
- `invalidateEmailFieldsList`: lists configured fields.
- `emailFieldScanner`: shows cached scan results and deploys selected fields as metadata.
- `invalidateEmailJobStatus`: recent batch jobs, polls while jobs run.
- `invalidateEmailFieldStatus`: per-field counts and percent invalidated.
- `invalidateEmailSettings`: edits the invalidation text.

Components coordinate through the `Email_Invalidator_Jobs` message channel (`messageChannels/`): `invalidateEmail` publishes when it starts a job, and the status cards refresh.

### App shell

`applications/`, `flexipages/`, `tabs/`, and the `Invalidate_Emails` permission set in `permissionsets/`.

### Other

- `config/project-scratch-def.json`: scratch org definition.
- `.github/workflows/tests.yml`: CI that runs Jest and Apex tests (in a throwaway scratch org) on PRs to `main`.
- `.claude/skills/fix-issue/`: the `/fix-issue` workflow for GitHub issues.
- `scripts/`: Salesforce DX template samples, not used.
- `docs/`: README screenshot.

## Test Coverage

Test coverage for Apex code must be above 75% before work is considered ready for a pull request and review. It can be handled in separate commits from the main changes, but unless otherwise instructed coverage must be checked and updated before creating a pull request.

## Commands

```sh
npm run test:unit          # LWC Jest tests
npm run test:unit:coverage
npm run lint               # ESLint on LWC
npm run prettier:verify    # Prettier check (Apex, JS, HTML, XML, etc.)

sf project deploy start --source-dir force-app
sf apex run test --test-level RunLocalTests --code-coverage --result-format human --wait 30
```

Scratch orgs come from the project's Dev Hub, which is set as `target-dev-hub` in the gitignored `.sf/config.json`. Don't change the user's global Dev Hub settings.

## Conventions

- Prettier (with `prettier-plugin-apex` and `@prettier/plugin-xml`, `trailingComma: none`) formats everything. Run `npm run prettier` and `npm run lint` before committing.
- `package-lock.json` is gitignored, so use `npm install`, not `npm ci`.
- Add or update Apex tests and Jest tests with any behavior change. Apex code coverage MUST stay above 75%.
- Branches: `bug/<slug>-<issue>` or `feature/<slug>-<issue>`. Commit messages reference the issue, e.g. `Fix X (#12)`.
- Keep the README up to date when user-facing behavior changes.
- PR Descriptions should be short, no more than 500 words.

## Marking AI-generated work

Mark everything you write so people can tell it was AI-generated: end commit messages with a `Co-Authored-By:` trailer, end PR descriptions with the Claude Code attribution line, and note in GitHub issue or PR comments that the comment was written by Claude. Don't sign the user's name to your work. This is not about cryptographic signing; don't use GPG or `git commit -S`.
