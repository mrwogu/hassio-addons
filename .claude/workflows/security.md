# security

<!-- PromptScript 2026-08-20T13:47:14.394Z | source: .promptscript/project.prs | target: claude - do not edit -->

> Review wrapper and distribution security

1. Identify whether the issue belongs to wrapper code, workflows,
   artifacts, or upstream application code.

2. Check secrets, shell input, capabilities, devices, AppArmor, image
   digests, downloaded bootstrap artifacts, and workflow permissions.

3. Keep upstream application vulnerabilities routed to upstream maintainers.
4. Use private vulnerability reporting for wrapper and supply-chain issues.
5. Add a focused regression test or validator rule.
