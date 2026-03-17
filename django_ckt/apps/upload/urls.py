"""
URL configuration for upload app.
"""
from django.urls import path
from . import views

app_name = 'upload'

urlpatterns = [
    path('', views.DataUploadView.as_view(), name='upload'),
    path('api/list-files/', views.list_available_files, name='list_files'),
    path('api/load-file/', views.load_graph_file, name='load_file'),
    path('api/upload-file/', views.upload_graph_file, name='upload_file'),
]

