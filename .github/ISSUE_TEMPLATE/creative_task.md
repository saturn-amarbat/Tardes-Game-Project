---
name: Creative Task
about: 3D art, environment, Blender, NPC model, audio, animation, or UI task for the Creative Lead
title: "[ART] "
labels: creative
assignees: Eyestain
---

## Owner & Target Environment
- **Owner:** Creative Lead (`@Eyestain`)
- **Workspace / Place:** <!-- e.g. Isolated Blender / Staging Place (`3D Models`) / Shared Team Create (when authorized) -->
- **Target Contract:** <!-- Reference `docs/STUDIO_ASSET_SPEC.md` section or Engineering contract -->

## Scope & Deliverables
<!-- Describe models, rooms, rigs, sounds, or UI updates. Keep exported `.rbxm`/`.rbxmx` and Blender sources preserved. -->
- <models, assets, or Studio containers>

## Technical Constraints & Handoff
- `ModelStreamingMode = Atomic` for procedural rooms; `Shadows = false` on static room/prop lights.
- Preserve existing gameplay-critical instances until replacement passes isolated verification.
- Provide export provenance, dimensions/anchors, and preview screenshot/video before shared integration.

## Approvals Required
- [ ] Isolated contract verification with Engineering Lead (`@saturn-amarbat`) before shared-place replacement or publishing.
