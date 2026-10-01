import unittest
from sample_owned_processes import parse_rows, classify, identity, interval_cpu

class ProcessAttributionTests(unittest.TestCase):
    def test_exact_responsible_identity(self):
        app = {'pid': 42, 'executable': '/Applications/Serein.app/Contents/MacOS/Serein'}
        fields = ' responsible pid = 42\n responsible path = '+app['executable']+'\n'
        self.assertEqual(classify(fields, 0, app), 'confirmed')
        self.assertEqual(classify(fields.replace('= 42', '= 43'), 0, app), 'foreign')
        self.assertEqual(classify(fields.replace('Serein.app', 'Other.app'), 0, app), 'foreign')
        self.assertEqual(classify(fields, 1, app), 'unresolved')
        self.assertEqual(classify('responsible pid = 42', 0, app), 'unresolved')

    def test_interval_excludes_reused_and_unresolved_processes(self):
        row = dict(pid=42, started='one', executable='/Serein', cpu_seconds=1.0, ownership='confirmed')
        before = dict(monotonic_seconds=10, processes=[row])
        after = dict(monotonic_seconds=12, processes=[dict(row, cpu_seconds=1.5)])
        self.assertEqual(interval_cpu(before, after)['cpu_interval_percent'], 25)
        after['processes'][0]['started'] = 'two'
        self.assertEqual(interval_cpu(before, after)['common_process_count'], 0)
        after['processes'][0] = dict(row, cpu_seconds=100, ownership='unresolved')
        self.assertIsNone(interval_cpu(before, after)['cpu_interval_percent'])
        self.assertIsNone(interval_cpu(before, before))

    def test_start_time_and_paths_with_spaces(self):
        rows = parse_rows('42 1 2048 0.1 1:02.50 Thu Oct  1 05:06:07 2026 /Test App/Serein\nmalformed\n')
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0]['cpu_seconds'], 62.5)
        self.assertEqual(rows[0]['executable'], '/Test App/Serein')
        other = dict(rows[0], started='Thu Oct 1 05:06:08 2026')
        self.assertNotEqual(identity(rows[0]), identity(other))

if __name__ == '__main__':
    unittest.main()
