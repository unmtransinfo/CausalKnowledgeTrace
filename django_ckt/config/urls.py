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

# Serve static and media files
if settings.DEBUG:
    # In development, serve both static and media files
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
else:
    # In production, serve media files (static files are handled by WhiteNoise middleware)
    # But add static route for debugging if needed
    urlpatterns += static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
    # Uncomment the line below if WhiteNoise isn't working properly:
    # urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)

