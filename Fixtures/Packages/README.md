# Signed package fixtures

These original controlled CRX3 fixtures are signed with ephemeral test keys using Python cryptography 50.0.0. Private keys are discarded and never stored. Public keys and signatures are embedded in CRX3; there are no third-party packages or publisher endorsements.

- `signed-fixture.crx`: version 1.0 with storage and local fixture access.
- `signed-update.crx`: version 1.1, same developer key, adds tabs permission.
- `signed-update-disabled.crx`: version 1.2, same developer key and permissions.
- `signed-update-unsupported.crx`: same-key version 2.0 requiring unavailable downloads permission; must be rejected.
- `wrong-developer.crx`: independently signed by a different key; must not update the RSA fixture.

The content script reports runtime ID/version and writes a stable storage marker to verify preservation across updates. The matching independently generated RSA/P-256, tampering and invalid-proof unit fixtures are embedded in `CRXPackageTests.swift`.

To regenerate in the cloud development environment, run `python3 script/generate_signed_fixtures.py` from the repository root with Python cryptography installed. Regeneration changes test keys/identities and all related bytes together. Building the checked-in application does not require Python cryptography or any fixture generation.
