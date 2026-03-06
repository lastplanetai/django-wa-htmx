"""Health check endpoint for load balancer."""

from django.db import connection
from django.http import JsonResponse


def health_check(request):
    """Return 200 OK if the application is healthy."""
    with connection.cursor() as cursor:
        cursor.execute("SELECT 1")

    return JsonResponse({"status": "ok"})
