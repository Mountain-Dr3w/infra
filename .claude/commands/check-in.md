Give a project status update and sync the primer.

## Steps

1. Read `docs/primer.md` to get the last known state.

2. Fetch the current issues from the GitHub project board:
   ```
   gh issue list --repo Mountain-Dr3w/infra --state all --json number,title,state,labels
   ```

3. Compare the board state against the primer. Identify:
   - Issues that have been closed since the last update
   - Issues that are now in progress
   - Any new issues not in the primer
   - What's currently unblocked and ready to work on

4. Present a status report to the user:
   - **Phase status** — which phases are complete, in progress, or blocked
   - **Recently completed** — issues closed since last check-in
   - **In progress** — what's actively being worked on
   - **Up next** — unblocked issues ready to pick up
   - **Blocked** — what's waiting and on what

5. Update `docs/primer.md` to reflect the current state:
   - Update the "Last updated" date
   - Move completed issues from Open to Completed
   - Update phase status table
   - Update "What's Ready to Do Now" section
   - Update any other sections that are stale

6. After writing the updated primer, show a short diff summary of what changed.
