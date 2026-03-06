"""
Base test case for Playwright e2e tests.

Provides automatic browser lifecycle management and common helpers.

Usage:
    from myproject.testing.playwright_e2e_testcase import PlaywrightE2ETestCase

    class TestHomePage(PlaywrightE2ETestCase):
        def test_displays_welcome(self, page):
            page.goto(self.live_server_url)
            expect(page).to_have_title("My Project")
"""

import time
from functools import wraps

from django.contrib.staticfiles.testing import StaticLiveServerTestCase
from playwright.sync_api import Browser, Page, sync_playwright


def wait_for_wa_component(page: Page, selector: str, timeout: int = 10000) -> None:
    """Wait for a Web Awesome custom element's Shadow DOM to hydrate.

    Under parallel test load, WA components may not have upgraded yet
    when Playwright tries to interact with them. This waits for the
    Shadow DOM to exist before proceeding.
    """
    page.wait_for_function(
        f"document.querySelector('{selector}')?.shadowRoot !== null",
        timeout=timeout,
    )


def _add_wa_load_listener(page: Page) -> None:
    """Wait for Web Awesome after every page navigation.

    Web Awesome removes the 'wa-cloak' class from <html> once loaded.
    Under parallel test load, CDN latency can delay this, causing flaky
    tests when asserting on wa-* custom elements.
    """

    def _on_load():
        try:
            page.wait_for_function(
                "!document.documentElement.classList.contains('wa-cloak')",
                timeout=10000,
            )
        except Exception:
            pass  # Pages without wa-cloak (e.g. admin) are fine

    page.on("load", _on_load)


def run_playwright(func):
    """Decorator that provides a Playwright page to test methods."""

    @wraps(func)
    def wrapper(*args, **kwargs):
        playwright_instance = sync_playwright().start()
        browser: Browser = playwright_instance.chromium.launch(headless=True)
        page: Page = browser.new_page()
        _add_wa_load_listener(page)

        try:
            kwargs["page"] = page
            return func(*args, **kwargs)
        finally:
            browser.close()
            playwright_instance.stop()

    return wrapper


class PlaywrightE2ETestCase(StaticLiveServerTestCase):
    """
    Base class for Playwright e2e tests.

    Features:
    - Automatically injects a `page` parameter into test methods
    - Handles browser lifecycle (launch, cleanup)
    - Properly closes database connections to prevent flush errors

    Example:
        class TestHomePage(PlaywrightE2ETestCase):
            def test_displays_welcome(self, page):
                page.goto(self.live_server_url)
                expect(page).to_have_title("My Project")
    """

    def tearDown(self):
        # Close all database connections before the parent's tearDown runs flush.
        # This prevents "Database couldn't be flushed" errors when the live server
        # thread still holds connections from async views.
        time.sleep(0.1)

        from django.db import connections

        for conn in connections.all():
            conn.close()

        super().tearDown()

    def __getattribute__(self, name):
        attr = super().__getattribute__(name)

        # Auto-decorate test_ methods with run_playwright
        if name.startswith("test_") and callable(attr):
            return run_playwright(attr)

        return attr
