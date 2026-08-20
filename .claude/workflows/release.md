# release

<!-- PromptScript 2026-08-20T13:47:14.394Z | source: .promptscript/project.prs | target: claude - do not edit -->

> Verify autonomous upstream release readiness

1. Confirm Renovate update is an upstream image, digest, or repository
   tooling change.

2. Confirm package version and upstream metadata are synchronized.
3. Confirm immutable tag does not already exist.
4. Run repository validation and changed add-on architecture builds.
5. Verify SBOM, Cosign, manifest digest, release notes, and artifacts.
6. Let the publish workflow create tags and GitHub Releases.
7. Never bypass failed validation or manually reuse a changed version.
