"""HTMX error handling middleware.

Intercepts error responses and formats them appropriately:
- HTMX requests: Returns HTML fragment for #page-errors container
- Non-HTMX requests: Returns full error page
"""

from django.http import HttpRequest, HttpResponse
from django.shortcuts import render


class UserFacingError(Exception):
    """Raise this to show a specific message to the user.

    Example:
        raise UserFacingError("You've exceeded your daily limit.", status_code=429)
    """

    def __init__(self, message: str, status_code: int = 400):
        self.message = message
        self.status_code = status_code
        super().__init__(message)


DEFAULT_ERROR_MESSAGES = {
    400: "Invalid request. Please check your input and try again.",
    401: "Please log in to continue.",
    403: "You don't have permission to do that.",
    404: "The requested item was not found.",
    500: "Something went wrong. Please try again later.",
}


def htmx_error_middleware(get_response):
    """Middleware that formats error responses for HTMX and non-HTMX requests."""

    def middleware(request: HttpRequest) -> HttpResponse:
        try:
            response = get_response(request)
        except UserFacingError as e:
            if getattr(request, "htmx", False):
                return render(
                    request,
                    "partials/error_callout.html",
                    {"message": e.message},
                    status=e.status_code,
                )
            else:
                return render(
                    request,
                    "errors/generic.html",
                    {"message": e.message, "status_code": e.status_code},
                    status=e.status_code,
                )

        if response.status_code < 400:
            return response

        if getattr(request, "htmx", False):
            message = DEFAULT_ERROR_MESSAGES.get(
                response.status_code,
                "An unexpected error occurred.",
            )
            return render(
                request,
                "partials/error_callout.html",
                {"message": message},
                status=response.status_code,
            )

        return response

    return middleware
