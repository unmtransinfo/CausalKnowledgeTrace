"""
Management command to copy R modules from shiny_app to django_ckt.
"""
from django.core.management.base import BaseCommand
from django.conf import settings
import shutil
from pathlib import Path


class Command(BaseCommand):
    help = 'Copy R modules from shiny_app/modules to django_ckt/r_modules'

    def handle(self, *args, **options):
        # Source directory (shiny_app/modules)
        source_dir = settings.BASE_DIR.parent / 'shiny_app' / 'modules'
        
        # Destination directory (django_ckt/r_modules)
        dest_dir = settings.R_MODULES_PATH
        
        if not source_dir.exists():
            self.stdout.write(
                self.style.ERROR(f'Source directory not found: {source_dir}')
            )
            return
        
        # Create destination directory if it doesn't exist
        dest_dir.mkdir(parents=True, exist_ok=True)
        
        # Copy all .R files
        copied_count = 0
        for r_file in source_dir.glob('*.R'):
            dest_file = dest_dir / r_file.name
            shutil.copy2(r_file, dest_file)
            self.stdout.write(
                self.style.SUCCESS(f'Copied: {r_file.name}')
            )
            copied_count += 1
        
        self.stdout.write(
            self.style.SUCCESS(
                f'\nSuccessfully copied {copied_count} R modules to {dest_dir}'
            )
        )

