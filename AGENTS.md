# Allods Addon Workspace

## Purpose

This folder is the local working area for Allods Online addon development,
analysis, packaging, and documentation.

## Workspace Root

The project is stored in Google Drive and can appear under different drive
letters on different PCs, commonly:

- `G:\Мой диск\Аллоды проги`
- `H:\Мой диск\Аллоды проги`

Treat the folder containing this `AGENTS.md` as `<AllodsWorkspace>`. Prefer
paths relative to `<AllodsWorkspace>` in documentation, generated records, and
reports. Use `v2\resolve-allods-workspace.ps1` when a script or agent needs to
print the concrete path for the current machine.
Source projects should live under `projects\<AddonName>`. The Google Drive
`адоны` folder is the user's personal package archive.

## User-Owned Addon Archive

- Do not create, replace, move, or delete files in `<AllodsWorkspace>\адоны`
  or the same Google Drive folder on another drive letter unless the user
  explicitly asks for that exact folder to be changed.
- Codex may freely test and swap addon PAKs only in the game addon folder:
  `C:\VK Play\Аллоды Онлайн\data\Mods\Addons`.
- When building experimental packages, use a temporary workspace/output folder
  or install directly to the game addon folder. Keep Google Drive `адоны`
  as read-only reference material by default.

## First Places To Check

- Read `v2/README.txt` before changing documentation or addon inventories.
- Use `v2/search-v2.ps1` for focused lookup instead of loading the large JSON
  files directly.
- Treat `адоны/*.pak` as user-owned reference packages.
- Treat `v2/allods_addons_knowledge.json` as a generated searchable snapshot
  of that user-owned archive.

## Addon Inventory Rules

- After the user explicitly asks to add, replace, or remove files in `адоны`,
  run:

```powershell
.\v2\update-addons-knowledge.ps1
```

- This updates `v2/allods_addons_knowledge.json`,
  `v2/allods_manifest_index.json`, and `v2/allods_search_index.jsonl`.
- Do not manually edit generated addon inventory JSON unless the generation
  script itself is being fixed.
- Before changing package-related records, or when unsure whether the index is
  current, run:

```powershell
.\v2\check-addons-freshness.ps1
```

- For audit requests, run `.\v2\audit-allods-workspace.ps1` first. Treat its
  duplicate and encoding findings as review signals, not as permission to
  delete or convert files automatically.
- For external code review, use `.\v2\export-review-pack.ps1`
  and share the generated pack, not the full Google Drive workspace.

## API And Runtime Knowledge

- Use `v2/allods_api_core.json` for current documented API.
- Use `v2/allods_runtime_knowledge.json` for verified in-game behavior,
  widget paths, known forms, and failed approaches.
- Use `v2/allods_examples_samples.json` for implementation examples.
- Use `v2/allods_history_changelog.json` only for historical or removed API.
- Record verified in-game findings in runtime knowledge, not in API core.

## Working Style

- Prefer the existing scripts and folder conventions over new tooling.
- Keep changes small and directly tied to the requested addon or record update.
- Preserve package/internal addon names unless the user explicitly asks to
  rename them.
- Do not delete archived or backup material unless the user explicitly asks.
- When a task touches PAK contents, report package names, internal addon names,
  file counts, and the verification command that was run.
- Main agent/subagent routing:
  - Use the main agent for edits, final decisions, and user-facing summaries.
  - Use `explorer` subagents for read-only audits, API searches, package
    inventory checks, and second opinions.
  - Use `worker` subagents only for disjoint file edits with explicit file
    ownership.
  - Game verification still requires the user or a real game run; do not mark
    behavior as verified from static inspection alone.
- Subagent context packets should include: goal, addon/package name, relevant
  paths, search queries to run, a ban on loading huge JSON wholesale, and the
  expected report format.
- Final Allods task reports should state: inspected packages, internal addon
  names, changed files, commands run, index updated yes/no, runtime verified
  yes/no.
- Git is used for local change visibility. Do not stage or commit files unless
  the user explicitly asks. Generated JSON/index files may change after update
  scripts; report those changes clearly.
- For source projects, use the shared pipeline scripts only when their target
  folder matches the user's permission for the task:
  - `v2\build-addon-pak.ps1` builds a store-mode `.pak`.
  - `v2\build-addon-workflow.ps1` builds into `адоны`; use it only when the
    user explicitly allows changing the Google Drive archive.
  - `v2\install-addon-pak.ps1` copies a chosen `.pak` into the game folder.
    The game folder is Codex's addon testing area.

## Game Paths

- Game install: `C:\VK Play\Аллоды Онлайн`
- Game addon install folder: `C:\VK Play\Аллоды Онлайн\data\Mods\Addons`
- Main Lua addon log: `C:\VK Play\Аллоды Онлайн\Personal\Logs\mods.txt`
