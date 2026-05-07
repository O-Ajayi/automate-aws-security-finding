import unittest

from services.shared.shared_utils import assert_safe_script


class SharedUtilsTests(unittest.TestCase):
    def test_allow_safe_command(self) -> None:
        assert_safe_script("yum update -y openssl")

    def test_block_dangerous_command(self) -> None:
        with self.assertRaises(ValueError):
            assert_safe_script("rm -rf /")


if __name__ == "__main__":
    unittest.main()
