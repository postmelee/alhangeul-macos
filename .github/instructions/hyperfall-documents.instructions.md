---
applyTo: "mydocs/plans/**/*.md,mydocs/working/**/*.md,mydocs/report/**/*.md"
---

# Hyper-waterfall document review rules

Write review comments in Korean. For these paths, prioritize traceability and verification reliability over wording/style preference.

- Plans in `mydocs/plans/**`: check issue number, milestone code, base branch, scope/exclusions, stage plan, validation commands, risks, and approval request. Flag missing or conflicting task metadata, stage boundaries, or validation plans.
- Stage reports in `mydocs/working/**`: check stage purpose, output table, change extent/body-loss note when applicable, actual verification commands and results, residual risk, next-stage impact, and approval request. Flag reports that cite commands not run or omit failed verification.
- Final reports in `mydocs/report/**`: check task summary table, changed-files table, before/after quantitative comparison when applicable, acceptance criteria OK/MISS table, verification results, residual risks/follow-ups, and approval request.
- File naming and location: plans are `task_m{milestone}_{issue}.md` or `_impl.md`; stage reports are `task_m{milestone}_{issue}_stage{N}.md` in `working/`; final reports are `task_m{milestone}_{issue}_report.md` in `report/`. Flag final reports in `working/`, stage reports in `report/`, or missing milestone codes.
- Only leave comments when traceability, folder/naming policy, stage/commit linkage, actual verification, approval boundary, or PR readiness is ambiguous or wrong. Do not leave wording-only review comments.
