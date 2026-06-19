# Jules Review Prompt

You are reviewing a clean export of an Allods Online addon workspace. Do not
delete files or rewrite generated JSON. Treat this repository as a review pack,
not the live Google Drive workspace.

Goals:

1. Evaluate the workspace structure for AI/Codex efficiency.
2. Review the `v2/*.ps1` scripts for portability, safety, and maintainability.
3. Review the `projects/AutoVendorHelper_v1` source-to-PAK workflow.
4. Identify token-saving improvements: smaller context packets, better search
   outputs, better audit reporting, and safer generated-data handling.
5. Identify portability issues between Google Drive mounts such as `G:` and
   `H:`.
6. Suggest only safe, reviewable changes. Do not mass-delete duplicates, mass
   convert encodings, rename internal addon names, or replace all absolute paths
   blindly.

Useful commands:

```powershell
.\v2\resolve-allods-workspace.ps1
.\v2\check-addons-freshness.ps1
.\v2\audit-allods-workspace.ps1
.\v2\search-v2.ps1 "LabMap" -Scope Addons
.\v2\build-addon-pak.ps1 -ProjectPath .\projects\AutoVendorHelper_v1
.\v2\search-v2.ps1 "Quest" -Scope Runtime
.\v2\search-v2.ps1 "Button" -Scope Examples
```

Expected output:

- P0/P1/P2 findings with concrete paths.
- A short "do not do" section for risky cleanup ideas.
- A proposed next-step patch plan.
- If making code changes, keep them small and focused.
