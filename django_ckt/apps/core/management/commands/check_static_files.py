"""
Django management command to check static files configuration and status.
"""
import os
from django.core.management.base import BaseCommand
from django.conf import settings
from django.contrib.staticfiles.finders import get_finders


class Command(BaseCommand):
    help = 'Check static files configuration and status'

    def handle(self, *args, **options):
        self.stdout.write(self.style.SUCCESS('=== Static Files Configuration Check ==='))
        
        # Basic settings
        self.stdout.write(f'STATIC_URL: {settings.STATIC_URL}')
        self.stdout.write(f'STATIC_ROOT: {settings.STATIC_ROOT}')
        self.stdout.write(f'STATICFILES_DIRS: {settings.STATICFILES_DIRS}')
        
        # Check if using new STORAGES or old STATICFILES_STORAGE
        if hasattr(settings, 'STORAGES'):
            storage_backend = settings.STORAGES.get('staticfiles', {}).get('BACKEND', 'Not set')
            self.stdout.write(f'STORAGES[staticfiles][BACKEND]: {storage_backend}')
        
        if hasattr(settings, 'STATICFILES_STORAGE'):
            self.stdout.write(f'STATICFILES_STORAGE: {settings.STATICFILES_STORAGE}')
        
        # Check if static root exists and has files
        if os.path.exists(settings.STATIC_ROOT):
            try:
                files = os.listdir(settings.STATIC_ROOT)
                self.stdout.write(f'STATIC_ROOT exists with {len(files)} items: {files[:10]}')
                
                # Check for CSS files specifically
                css_dir = os.path.join(settings.STATIC_ROOT, 'css')
                if os.path.exists(css_dir):
                    css_files = os.listdir(css_dir)
                    self.stdout.write(f'CSS files found: {css_files}')
                else:
                    self.stdout.write(self.style.WARNING('No CSS directory found in STATIC_ROOT'))
                    
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'Error reading STATIC_ROOT: {e}'))
        else:
            self.stdout.write(self.style.WARNING('STATIC_ROOT does not exist'))
        
        # Check staticfiles dirs
        for i, static_dir in enumerate(settings.STATICFILES_DIRS):
            if os.path.exists(static_dir):
                files = os.listdir(static_dir)
                self.stdout.write(f'STATICFILES_DIRS[{i}] exists with {len(files)} items: {files[:10]}')
            else:
                self.stdout.write(self.style.WARNING(f'STATICFILES_DIRS[{i}] does not exist: {static_dir}'))
        
        # Check finders
        self.stdout.write('\n=== Static Files Finders ===')
        for finder in get_finders():
            self.stdout.write(f'Finder: {finder.__class__.__name__}')
            try:
                files = list(finder.list([]))
                self.stdout.write(f'  Found {len(files)} files')
                # Show first few CSS files
                css_files = [f for f in files if f[0].endswith('.css')][:5]
                if css_files:
                    self.stdout.write(f'  Sample CSS files: {[f[0] for f in css_files]}')
            except Exception as e:
                self.stdout.write(self.style.ERROR(f'  Error: {e}'))
        
        self.stdout.write(self.style.SUCCESS('\n=== Check Complete ==='))
