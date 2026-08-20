# feature

<!-- PromptScript 2026-08-20T13:47:14.394Z | source: .promptscript/project.prs | target: claude - do not edit -->

> Implement a focused add-on adapter change

1. Read the affected add-on config, Dockerfile, upstream metadata,
   entrypoint, tests, documentation, translations, changelog, license,
   addons.yaml, and current workflows.

2. Keep changes in the Home Assistant adapter layer. Do not modify
   upstream application source.

3. Validate every new option. Quote shell values, avoid command
   construction, redact secrets, persist mutable state under /config,
   and preserve final exec behavior.

4. Update focused fixtures for valid, invalid, omitted, persistence, and
   secret-handling paths.

5. Update English and Polish translations and documentation when
   configuration or behavior changes.

6. Run make check, yamllint, actionlint, ShellCheck, PromptScript checks,
   and the changed add-on architecture build gate.

7. Stop before commit, push, release, or publication unless authorized.
