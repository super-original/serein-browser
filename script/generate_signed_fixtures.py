from pathlib import Path
import io,zipfile,hashlib,struct,base64
from cryptography.hazmat.primitives.asymmetric import rsa,ec,padding
from cryptography.hazmat.primitives import hashes,serialization
import json
script = """(async () => {
  const previous = await browser.storage.local.get('updateSentinel');
  if (!previous.updateSentinel) await browser.storage.local.set({updateSentinel:'preserved-across-update'});
  const current = await browser.storage.local.get('updateSentinel');
  document.documentElement.dataset.sereinCRXIdentity = browser.runtime.id;
  document.documentElement.dataset.sereinCRXState = JSON.stringify({version:browser.runtime.getManifest().version,marker:current.updateSentinel});
})();"""
options_script = """(async () => {
  await browser.storage.local.set({['optionsExecution_'+crypto.randomUUID()]:browser.runtime.getManifest().version});
  document.body.textContent = 'Version ' + browser.runtime.getManifest().version;
})();"""
def build_archive(version='1.0', permissions=None):
 out=io.BytesIO()
 manifest={'manifest_version':3,'name':'Signed fixture','version':version,'description':'Controlled signed update fixture.','permissions':permissions or ['storage'],'host_permissions':['http://127.0.0.1/*'],'content_scripts':[{'matches':['http://127.0.0.1/*'],'js':['identity.js']}],'options_ui':{'page':'options.html','open_in_tab':True}}
 with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
  for name,value in [('manifest.json',json.dumps(manifest)),('identity.js',script),('options.html','<!doctype html><title>Signed extension options</title><body><script src="options.js"></script></body>'),('options.js',options_script)] :
   info=zipfile.ZipInfo(name,(2026,9,30,0,0,0));info.compress_type=8;z.writestr(info,value)
 return out.getvalue()
archive=build_archive()
def varint(n):
 b=[]
 while n>127:b.append((n&127)|128);n>>=7
 return bytes(b+[n])
def field(n,b):return varint(n*8+2)+varint(len(b))+b
fixtures={};ids={}
for name,key,typ in [('rsa',rsa.generate_private_key(public_exponent=65537,key_size=2048),2),('ecdsa',ec.generate_private_key(ec.SECP256R1()),3)]:
 pub=key.public_key().public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo)
 ident=hashlib.sha256(pub).digest()[:16];ids[name]=''.join(chr(97+(v>>4))+chr(97+(v&15)) for v in ident)
 for variant in ['valid','mismatchedID','invalidExtraProof']:
  signed=field(1,bytes(16) if variant=='mismatchedID' else ident)
  msg=b'CRX3 SignedData\0'+struct.pack('<I',len(signed))+signed+archive
  sig=key.sign(msg,padding.PKCS1v15(),hashes.SHA256()) if typ==2 else key.sign(msg,ec.ECDSA(hashes.SHA256()))
  proof=field(1,pub)+field(2,sig)
  header=field(typ,proof)+field(10000,signed)
  if variant=='invalidExtraProof':header+=field(typ,field(1,pub)+field(2,bytes(len(sig))))
  fixtures[name+variant]=b'Cr24'+struct.pack('<II',3,len(header))+header+archive
 if name=='rsa':
  for filename, version, permissions in [('signed-update.crx','1.1',['storage','tabs']),('signed-update-disabled.crx','1.2',['storage','tabs']),('signed-update-unsupported.crx','2.0',['storage','nativeMessaging'])]:
   payload=build_archive(version,permissions);signed=field(1,ident)
   message=b'CRX3 SignedData\0'+struct.pack('<I',len(signed))+signed+payload
   signature=key.sign(message,padding.PKCS1v15(),hashes.SHA256())
   header=field(2,field(1,pub)+field(2,signature))+field(10000,signed)
   Path('Fixtures/Packages/'+filename).write_bytes(b'Cr24'+struct.pack('<II',3,len(header))+header+payload)
Path('Fixtures/Packages/signed-fixture.crx').write_bytes(fixtures['rsavalid'])
Path('Fixtures/Packages/wrong-developer.crx').write_bytes(fixtures['ecdsavalid'])
code='''import XCTest
@testable import SereinCore

// Independently signed using Python cryptography (RSA PKCS1/SHA256 and P-256/SHA256).
// Test keys were ephemeral and discarded; no private key is included.
final class CRXPackageTests: XCTestCase {
'''
for name in ['rsa','ecdsa']:
 code+=f'''    func test{name.title()}SignatureAndIdentity() throws {{
        let package = try CRXPackage.verify(fixture("{name}valid"))
        XCTAssertEqual(package.identity.extensionID, "{ids[name]}")
        XCTAssertEqual(package.identity.format, "CRX3")
        XCTAssertEqual(package.archive.prefix(4), Data([0x50,0x4b,0x03,0x04]))
    }}
'''
code+='''    func testTamperingAndTruncation() throws {
        let valid = try fixture("rsavalid")
        for offset in [0, 8, 15, valid.count - 25] {
            var data = valid; data[offset] ^= 1
            XCTAssertThrowsError(try CRXPackage.verify(data), "Tampering at \\(offset)")
        }
        for size in [0, 11, 30, valid.count - 1] {
            XCTAssertThrowsError(try CRXPackage.verify(Data(valid.prefix(size))))
        }
        var legacy = valid; legacy[4] = 2
        XCTAssertThrowsError(try CRXPackage.verify(legacy))
    }
    func testProofMustMatchIdentityAndEveryProofMustVerify() throws {
        for name in ["rsamismatchedID", "ecdsamismatchedID", "rsainvalidExtraProof", "ecdsainvalidExtraProof"] {
            XCTAssertThrowsError(try CRXPackage.verify(fixture(name)), name)
        }
    }
    private func fixture(_ name: String) throws -> Data { try XCTUnwrap(Data(base64Encoded: Self.fixtures[name]!)) }
    private static let fixtures: [String: String] = [
'''
for n,b in fixtures.items():code+=f'        "{n}": "{base64.b64encode(b).decode()}",\n'
code+='    ]\n}\n';Path('Tests/SereinCoreTests/CRXPackageTests.swift').write_text(code)
