"""URL configuration for www app."""

from django.urls import path

from myproject.apps.www.views.health import health_check
from myproject.apps.www.views.home import home

urlpatterns = [
    path("", home, name="home"),
    path("health/", health_check, name="health_check"),
]
