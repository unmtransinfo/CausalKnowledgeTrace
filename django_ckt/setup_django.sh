#!/bin/bash
# Django CausalKnowledgeTrace Setup Script

set -e  # Exit on error

echo "========================================="
echo "🚀 Django CausalKnowledgeTrace Setup"
echo "========================================="

# Check if we're in the right directory
if [ ! -f "manage.py" ]; then
    echo "❌ Error: manage.py not found. Please run this script from django_ckt directory."
    exit 1
fi

# Step 1: Create .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "📝 Creating .env file from .env.example..."
    cp .env.example .env
    echo "✅ .env file created. Please edit it with your configuration."
else
    echo "✅ .env file already exists"
fi

# Step 2: Upgrade pip
echo "📦 Upgrading pip..."
pip install --upgrade pip

# Step 3: Install Python dependencies
echo "📦 Installing Python dependencies..."
pip install -r requirements.txt

# Step 4: Copy R modules
echo "📋 Copying R modules from shiny_app..."
python manage.py copy_r_modules

# Step 5: Create necessary directories
echo "📁 Creating necessary directories..."
mkdir -p static/css static/js static/images
mkdir -p media/graphs
mkdir -p staticfiles
mkdir -p ../logs

# Step 6: Copy static assets
echo "🖼️  Copying static assets..."
if [ -f "../shiny_app/www/hsclogo.png" ]; then
    cp ../shiny_app/www/hsclogo.png static/images/
    echo "✅ Logo copied"
fi

# Step 7: Run migrations
echo "🗄️  Running database migrations..."
python manage.py migrate

# Step 8: Collect static files
echo "📦 Collecting static files..."
python manage.py collectstatic --noinput

# Step 9: Create superuser (optional)
echo ""
echo "========================================="
echo "Would you like to create a superuser? (y/n)"
read -r response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
    python manage.py createsuperuser
fi

echo ""
echo "========================================="
echo "✅ Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Edit .env file with your database credentials"
echo "2. Ensure PostgreSQL is running"
echo "3. Run the application:"
echo "   ./run_django.sh"
echo ""
echo "Or run with specific server:"
echo "   python manage.py runserver 0.0.0.0:3838"
echo "   daphne -b 0.0.0.0 -p 3838 config.asgi:application"
echo "   uvicorn config.asgi:application --host 0.0.0.0 --port 3838"
echo ""
echo "========================================="

