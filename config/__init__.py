"""Config package - loads Celery when Django starts."""

from config.celery import app as celery_app

__all__ = ("celery_app",)
