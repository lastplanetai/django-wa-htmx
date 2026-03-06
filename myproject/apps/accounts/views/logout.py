"""Logout view."""

from django.contrib.auth import logout as auth_logout
from django.http import HttpRequest, HttpResponse
from django.shortcuts import redirect
from django.views.decorators.http import require_POST


@require_POST
def logout(request: HttpRequest) -> HttpResponse:
    """Log the user out and redirect to home."""
    auth_logout(request)
    return redirect("home")
