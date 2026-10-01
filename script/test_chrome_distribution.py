import io
import pathlib
import stat
import tempfile
import unittest
import zipfile
from chrome_distribution import verify_application_files


class DistributionTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='serein-distribution-test-')
        self.addCleanup(self.temporary.cleanup)
        self.app = pathlib.Path(self.temporary.name) / 'Test.app'
        self.app.mkdir()
        self.archive = io.BytesIO()
        with zipfile.ZipFile(self.archive, 'w') as source:
            for name, mode, data in [('Contents/launcher', stat.S_IFREG | 0o755, b'fixture executable bytes'),
                                     ('Contents/resource', stat.S_IFREG | 0o644, b'fixture resource'),
                                     ('Contents/current', stat.S_IFLNK | 0o777, b'resource')]:
                entry = zipfile.ZipInfo('chrome-mac-arm64/Google Chrome for Testing.app/' + name)
                entry.create_system = 3
                entry.external_attr = mode << 16
                source.writestr(entry, data)
                path = self.app / name
                path.parent.mkdir(parents=True, exist_ok=True)
                if stat.S_ISLNK(mode):
                    path.symlink_to(data.decode())
                else:
                    path.write_bytes(data)
                    path.chmod(stat.S_IMODE(mode))

    def verify(self):
        with zipfile.ZipFile(self.archive) as source:
            return verify_application_files(self.app, source)

    def test_exact_distribution(self):
        self.assertEqual(self.verify(), (2, 1))

    def test_resource_mutation_rejected(self):
        (self.app / 'Contents/resource').write_bytes(b'changed')
        with self.assertRaisesRegex(AssertionError, 'File mismatch'):
            self.verify()

    def test_additional_file_rejected(self):
        (self.app / 'Contents/extra').write_bytes(b'extra')
        with self.assertRaisesRegex(AssertionError, 'Unexpected or missing'):
            self.verify()

    def test_missing_file_rejected(self):
        (self.app / 'Contents/resource').unlink()
        with self.assertRaisesRegex(AssertionError, 'Missing regular file'):
            self.verify()

    def test_redirected_link_rejected(self):
        link = self.app / 'Contents/current'
        link.unlink()
        link.symlink_to('launcher')
        with self.assertRaisesRegex(AssertionError, 'Link mismatch'):
            self.verify()

    def test_changed_executable_mode_rejected(self):
        (self.app / 'Contents/launcher').chmod(0o644)
        with self.assertRaisesRegex(AssertionError, 'Executable mode mismatch'):
            self.verify()


if __name__ == '__main__':
    unittest.main()
