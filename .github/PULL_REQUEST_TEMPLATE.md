## Summary
<!-- Concise description of what changed and why. -->

## Ownership & Scope
- **Owner:** <!-- @saturn-amarbat (Engineering Lead) / @Eyestain (Creative Lead) -->
- **Area:** <!-- Engineering (`src/`) / Creative (`assets/`, `Opening.rbxmx`) / Docs & Governance -->
- **Baseline Commit:** <!-- e.g. `origin/main` @ `3878e6d3` -->
- **Related Issue / Task:** <!-- #... -->

## Verification Evidence
Distinguish static source verification from Studio runtime verification. Mark unrun checks as `UNVERIFIED`.

- [ ] `stylua --check src`
- [ ] `selene src`
- [ ] `rojo build` (`default.project.json`, `lobby.project.json`, `forest-preview.project.json` to temp output)
- [ ] Isolated Studio / Playtest runtime verified *(record place/copy, player count, seed, and `0` console errors; otherwise mark `UNVERIFIED`)*

## Boundaries & Approvals
- [ ] No Rojo-managed `.luau` scripts were edited directly inside Roblox Studio.
- [ ] No unintended changes to Studio-only assets, Rojo project mappings, or unrelated systems.
- [ ] **Joint Approval Check:** Structural changes, shared-place recovery, tracked asset replacements, milestone exit, and publishing require approval from both `@saturn-amarbat` and `@Eyestain`.
