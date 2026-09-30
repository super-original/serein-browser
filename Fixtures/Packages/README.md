# Signed package fixture

`signed-fixture.crx` contains only a minimal MV3 manifest. Its original RSA-2048
CRX3 signature was generated with Python cryptography 50.0.0 using an ephemeral
key that was discarded. The public key and signature are embedded in CRX3; no
private key or third-party package is included. Identical bytes are embedded in
`CRXPackageTests.swift` alongside independent P-256, incorrect-ID and extra-bad-proof
fixtures. The key identity is a test identity, not a store publisher endorsement.

Tests mutate signed bytes without resigning and require rejection. Runtime checks
install the bundled original through Serein's actual consent/load/persistence path.
