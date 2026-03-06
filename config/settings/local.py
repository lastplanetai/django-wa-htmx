"""
Django settings for local development.

Usage: DJANGO_SETTINGS_MODULE=config.settings.local
"""

from .base import *  # noqa: F401, F403

DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

# Use SQLite locally by default (DATABASE_URL can override)
# PostgreSQL: DATABASE_URL=postgres://postgres:postgres@localhost:5433/myproject

# Email: print to console in development
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
