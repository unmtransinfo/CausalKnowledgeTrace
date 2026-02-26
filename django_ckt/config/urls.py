"""
URL configuration for CausalKnowledgeTrace project.
"""
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('apps.core.urls')),
    path('visualization/', include('apps.visualization.urls')),
    path('analysis/', include('apps.analysis.urls')),
    path('upload/', include('apps.upload.urls')),
    path('config/', include('apps.graph_config.urls')),
]

# Serve media files in development
if settings.DEBUG:
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

