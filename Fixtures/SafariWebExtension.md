# Original Safari Web Extension fixture

Original Serein MV3 fixture, version 1.0, for testing the public app-extension-bundle initializer. No third-party package is redistributed.

`script/build.sh` adds a copy of the original NativeEcho helper as the bundle executable and ad-hoc signs the complete `.appex` for macOS 27 ARM64. The fixture never requests native messaging and the browser never explicitly loads that executable. It exists to make the controlled bundle signable; this is not a Safari native-handler compatibility test.

Runtime scenarios review/cancel installation, load the options resource, message the background worker, retain storage across disable/reload, reject a changed signed manifest, and remove the package. Ad-hoc integrity is not publisher trust or notarization.
