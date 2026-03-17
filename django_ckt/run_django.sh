#!/bin/bash
# Django CausalKnowledgeTrace Run Script

# Load environment variables from .env file if it exists
if [ -f .env ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

# Default port
PORT=${DJANGO_PORT:-3838}

echo "========================================="
echo "🚀 Starting Django CausalKnowledgeTrace"
echo "========================================="
echo "📍 URL: http://0.0.0.0:$PORT"
echo "🔌 Port: $PORT"
echo "========================================="

# Check if we should use ASGI server
if command -v daphne &> /dev/null; then
    echo "Using Daphne ASGI server..."
    daphne -b 0.0.0.0 -p $PORT config.asgi:application
elif command -v uvicorn &> /dev/null; then
    echo "Using Uvicorn ASGI server..."
    uvicorn config.asgi:application --host 0.0.0.0 --port $PORT
else
    echo "Using Django development server..."
    python manage.py runserver 0.0.0.0:$PORT
fi

