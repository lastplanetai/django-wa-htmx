"""URL configuration."""

from django.contrib import admin
from django.urls import include, path

urlpatterns = [
    path("", include("myproject.apps.www.urls")),
    path("admin/", admin.site.urls),
    path("accounts/", include("myproject.apps.accounts.urls")),
]
