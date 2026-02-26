"""
URL configuration for visualization app.
"""
from django.urls import path
from . import views

app_name = 'visualization'

urlpatterns = [
    path('', views.GraphVisualizationView.as_view(), name='graph'),
    path('api/remove-node/', views.remove_node, name='remove_node'),
    path('api/remove-edge/', views.remove_edge, name='remove_edge'),
    path('api/undo/', views.undo_removal, name='undo'),
    path('api/network-data/', views.get_network_data, name='network_data'),
]

