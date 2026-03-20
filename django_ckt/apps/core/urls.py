"""
URL configuration for core app.
"""
from django.urls import path
from . import views

app_name = 'core'

urlpatterns = [
    # Root path points to AboutView (consolidated home/about page)
    path('', views.AboutView.as_view(), name='home'),
    # Keep 'about' URL for backward compatibility
    path('about/', views.AboutView.as_view(), name='about'),
]

