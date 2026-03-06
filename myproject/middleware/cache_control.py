"""Cache-Control middleware for browser caching.

Enables the htmx preload extension to work by allowing browsers to cache
GET responses briefly. Preloaded pages appear instant when clicked.
"""

from django.http import HttpRequest, HttpResponse


def cache_control_middleware(get_response):
    """Add Cache-Control headers to enable browser caching for preload."""

    def middleware(request: HttpRequest) -> HttpResponse:
        response = get_response(request)

        if request.method != "GET":
            return response

        if response.status_code < 200 or response.status_code >= 300:
            return response

        if response.get("Cache-Control"):
            return response

        # private = only browser caches, not CDNs or proxies
        response["Cache-Control"] = "private, max-age=60"

        # Vary on Cookie since authenticated users see different content
        existing_vary = response.get("Vary", "")
        if "Cookie" not in existing_vary:
            if existing_vary:
                response["Vary"] = f"{existing_vary}, Cookie"
            else:
                response["Vary"] = "Cookie"

        return response

    return middleware
