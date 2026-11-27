# Team ownership and agent workflow

Status: proposed repository record of the shared project operating agreement, 2026-11-26.

| Owner | Responsibilities |
| --- | --- |
| Engineering Lead | Luau, Git/Rojo, gameplay systems, procedural generation, multiplayer, NPC AI, integration, technical QA and recovery |
| Creative Lead | Environment art, furnishing, Blender sources, character appearance, textures, animation, lighting, audio, cinematics and visual presentation |
| Antigravity | Primary daily implementation agent, operating within each lead's scope |
| Codex | Precision engineering, high-risk changes and independent technical review |
| ChatGPT | Planning, coordination, research and independent review; no unilateral approval |

## Source of truth

Use current repository code, GAME_SPEC.md, AGENTS.md, approved issues/PRs, milestone records and actual Studio evidence. Resolve discrepancies explicitly. A conversation is not proof of implementation or runtime success. Distinguish reported, source-verified, runtime-verified, proposed and jointly approved states.

## Boundaries

- Engineering owns all Luau edits on disk. No edits to Rojo-managed scripts via Studio or Studio MCP. Preserve existing Rojo mappings and ignore-unknown settings; do not assume they protect every descendant or tracked model.
- Creative work on tracked models requires coordinated export and integration; the Creative Lead does not independently replace gameplay-critical models in the shared place.
- The Engineering Lead approved independent offline creative production in an isolated workspace; explicit Creative Lead agreement was requested and is not evidenced in the available handoff excerpt. Record joint confirmation before treating this exception as jointly approved.
- Preserve exported models and Blender sources; no extensive archiving of disposable artwork is required. Keep existing gameplay-critical assets until replacements are integrated and verified.
- Both leads approve structural changes, final integration, milestone exit and publishing. During Phase 0, do not authorize shared-place changes, repository restructuring, asset replacement or new gameplay work through this document.

## Task and handoff protocol

Before implementing or assigning work, inspect the latest repository state (`origin/main`), active branches, teammate changes, existing modules, dependencies, and ownership—do not duplicate existing work or re-read unrelated documents when `AGENTS.md` and task-specific specs suffice. Use narrowly scoped tasks containing owner, baseline, permitted files/instances, acceptance criteria, dependencies and required evidence. Update relevant milestone, ADR, or asset-contract docs only when implementation or approved decisions actually change, avoiding redundant documentation and excessive administrative overhead. Report actual test evidence, failures, blockers, integration dependencies, and next actions, distinguishing source implementation from Studio runtime verification. Raise technical dependencies, art decisions affecting gameplay, or integration approvals to the other lead.

Engineering supplies current NPC/room contracts before integration (rig hierarchy, pivot, dimensions, collision, markers, animation/audio interfaces as applicable). Creative supplies export provenance, version, preview and contract compliance. Validate in isolation, then coordinate shared-place integration and runtime tests. Existing [Studio asset specification](STUDIO_ASSET_SPEC.md) remains the starting contract, not proof of current instances.
