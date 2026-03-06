"""URL configuration for accounts app."""

from django.urls import path

from myproject.apps.accounts.views import logout

app_name = "accounts"

urlpatterns = [
    path("logout/", logout, name="logout"),
]
