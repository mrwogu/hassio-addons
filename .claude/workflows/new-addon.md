# new-addon

<!-- PromptScript 2026-08-20T13:47:14.394Z | source: .promptscript/project.prs | target: claude - do not edit -->

> Add a new upstream application wrapper

1. Confirm upstream license permits redistribution. Preserve exact
   license and notices. Document material restrictions.

2. Choose a lowercase stable slug and ghcr.io/mrwogu/hassio-<slug>.
3. Create required config, Dockerfile, docs, changelog, license, assets,
   upstream metadata, translations, entrypoint, and adapter tests.

4. Add the slug, image, Dockerfile, and test script to addons.yaml.
5. Keep config metadata, Dockerfile arguments, upstream.yaml, and
   changelog synchronized.

6. Add the new path only through manifest-driven validation, Make,
   workflows, and Renovate.

7. Run complete local and CI validation before merge.
