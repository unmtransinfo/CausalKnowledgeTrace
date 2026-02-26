"""
URL configuration for graph_config app.
"""
from django.urls import path
from . import views

app_name = 'graph_config'

urlpatterns = [
    path('', views.GraphConfigView.as_view(), name='config'),
    path('api/search-cui/', views.search_cui, name='search_cui'),
    path('api/generate/', views.generate_graph, name='generate'),
    path('api/status/<str:task_id>/', views.check_generation_status, name='status'),
]

