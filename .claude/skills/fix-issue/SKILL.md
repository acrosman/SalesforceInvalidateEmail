---
name: fix-issue
description: Work on a GitHub issue end to end — read it carefully, clarify open questions, branch, implement, and (after asking) open a PR. Use when the user runs /fix-issue <number> or asks to fix/address/work on a GitHub issue by number.
argument-hint: <issue-number>
disable-model-invocation: false
---

# Fix GitHub issue #$ARGUMENTS

If no issue number was provided, ask for one before doing anything else.

## 1. Review the issue carefully

- Read the full issue, including all comments: `gh issue view $ARGUMENTS --comments`
- Note labels, linked issues/PRs, and any referenced files, screenshots, or error messages. Follow links to related issues or PRs when they add context.
- Explore the relevant code so you understand the current behavior before proposing a change.
- Summarize for the user, briefly: what the issue asks for, what you found in the code, and how you plan to address it.

## 2. Ask follow-up questions as needed

- If requirements are ambiguous, acceptance criteria are missing, or there are several reasonable approaches with real trade-offs, ask before writing code.
- Don't ask about things you can answer from the issue, the code, or project conventions — decide those yourself and mention the choice.
- If the issue looks already fixed, out of date, or a duplicate, say so and stop until the user decides.

## 3. Open a new branch

- Start from an up-to-date default branch: `git checkout main && git pull`
- If the working tree has uncommitted changes, stop and ask how to handle them.
- Name the branch by issue type, following the repo's existing pattern:
  - `bug/<short-slug>-<number>` for bugs
  - `feature/<short-slug>-<number>` for features and enhancements
- Check `git branch -a` for an existing branch for this issue first; if one exists, ask whether to reuse it.

## 4. Do the work

- Keep changes focused on the issue. Note unrelated problems you spot instead of fixing them.
  - Ask if you should create new issues for them.
- Match the surrounding code style and conventions.
- Add or update tests where appropriate, and run the relevant tests/linters before calling the work done. Report failures honestly.
- Commit with clear messages that reference the issue (e.g. `Fix X (#$ARGUMENTS)`). End each commit message with a `Co-Authored-By:` trailer naming the AI model, so the commit is marked as AI-generated. This is not GPG signing; don't use `git commit -S`.

## 5. Ask before opening a PR

- When the work is done, summarize what changed and how it was verified, then **ask the user whether to push and open a PR**. Do not push or open a PR without explicit approval.
- Once approved, push the branch and open the PR with `gh pr create`, targeting `main`.
- **PR description: no more than 200 words**, unless the user said otherwise while doing the work. Include:
  - A short summary of the change
  - `Fixes #$ARGUMENTS` so the issue closes on merge
  - How it was tested
  - An attribution line at the end saying the PR was generated with Claude Code. Don't sign the user's name.
- Share the PR link when done.

## Marking AI-generated work

Everything you write on the user's behalf must say it was AI-generated, so reviewers know what to look at closely:

- **Commits:** `Co-Authored-By:` trailer (step 4).
- **PR descriptions:** attribution line at the end (step 5).
- **Issue and PR comments:** start or end the comment with a short note that Claude wrote it, e.g. `_Comment by Claude Code._`

"Sign" here never means cryptographic signing with GPG or SSH.
