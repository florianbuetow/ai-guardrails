import unittest


class SkippedTest(unittest.TestCase):
    @unittest.skip("disabled")
    def test_greeting(self):
        self.assertEqual(1, 2)
