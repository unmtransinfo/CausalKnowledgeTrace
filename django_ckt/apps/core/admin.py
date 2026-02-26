"""
Admin configuration for core app.
"""
from django.contrib import admin
from .models import GraphFile


@admin.register(GraphFile)
class GraphFileAdmin(admin.ModelAdmin):
    list_display = ('name', 'file_type', 'node_count', 'edge_count', 'uploaded_at')
    list_filter = ('file_type', 'uploaded_at')
    search_fields = ('name', 'description')
    readonly_fields = ('uploaded_at',)
    ordering = ('-uploaded_at',)

