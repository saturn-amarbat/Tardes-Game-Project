---
name: Engineering Task
about: Scoped Luau, Rojo, gameplay, multiplayer, AI, or QA task for the Engineering Lead
title: "[ENG] "
labels: engineering
assignees: saturn-amarbat
---

## Owner & Baseline
- **Owner:** Engineering Lead (`@saturn-amarbat`)
- **Base Commit / Branch:** <!-- e.g. `origin/main` @ `<sha>` -->
- **Dependencies / Related:** <!-- e.g. blocked by / depends on #... -->

## Scope & Permitted Files
<!-- List exact `src/` files, Rojo configs, or isolated Studio copies in scope. -->
- <list files or instances>

## Acceptance Criteria
- <measurable outcome>

## Required Verification
- [ ] `stylua --check src`
- [ ] `selene src`
- [ ] `rojo build` (isolated output)
- [ ] Isolated Studio runtime / Playtest check (note exact scope or `UNVERIFIED`)
- [ ] Update relevant docs (`MILESTONES_AND_CHECKINS.md`, `DECISIONS_AND_CHANGELOG.md`, etc.) only if behavior or approved decisions changed
