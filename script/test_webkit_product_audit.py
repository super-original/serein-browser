import json
import pathlib
import plistlib
import subprocess
import tempfile
import unittest
from unittest.mock import patch
from audit_webkit_products import audit_products


class ProductAuditTests(unittest.TestCase):
    def test_failed_signature_is_preserved_without_repair_or_approval(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            bundle = root / 'products/Release/Test.framework'
            (bundle / 'Resources').mkdir(parents=True)
            (bundle / 'Resources/Info.plist').write_bytes(plistlib.dumps({'CFBundleExecutable': 'Test', 'CFBundleIdentifier': 'owned.fixture'}))
            (bundle / 'Test').write_bytes(b'fixture executable bytes')
            commands = []
            def run(args, **kwargs):
                commands.append(args)
                return subprocess.CompletedProcess(args, 1 if '--verify' in args else 0, '', 'sealed resource invalid' if '--verify' in args else '')
            with patch('audit_webkit_products.subprocess.run', side_effect=run):
                result = audit_products(root / 'products', root, root, {})
            self.assertTrue(result['complete'])
            self.assertFalse(result['all_signatures_verify'])
            self.assertFalse(result['production_approved'])
            self.assertEqual(result['records'][0]['verification']['stderr'], 'sealed resource invalid')
            self.assertTrue(all('--sign' not in command and '--force' not in command for command in commands))
            self.assertEqual((bundle / 'Test').read_bytes(), b'fixture executable bytes')

    def test_product_symlink_cannot_escape_owned_root(self):
        with tempfile.TemporaryDirectory() as directory:
            parent = pathlib.Path(directory)
            root = parent / 'owned'; release = root / 'products/Release'; release.mkdir(parents=True)
            outside = parent / 'outside.framework'; outside.mkdir()
            (release / 'outside.framework').symlink_to(outside, target_is_directory=True)
            with patch('audit_webkit_products.subprocess.run') as run:
                result = audit_products(root / 'products', root, root, {})
            run.assert_not_called()
            self.assertFalse(result['complete'])
            self.assertIn('outside owned build root', result['error'])

    def test_timeout_retains_partial_diagnostic_report(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / 'products/Release/Owned.xpc').mkdir(parents=True)
            with patch('audit_webkit_products.subprocess.run', side_effect=subprocess.TimeoutExpired('codesign', 30)):
                result = audit_products(root / 'products', root, root, {})
            self.assertFalse(result['complete'])
            self.assertIn('timed out', result['error'])
            self.assertEqual(json.loads((root / 'product-security-audit.json').read_text()), result)


if __name__ == '__main__':
    unittest.main()
