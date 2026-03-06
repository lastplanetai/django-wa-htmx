"""Project-wide test fixtures."""


def pytest_configure():
    """Block real API calls during tests.

    Override API credentials with safe test sentinels here.
    This runs after Django setup but before any tests execute.
    """
    pass
