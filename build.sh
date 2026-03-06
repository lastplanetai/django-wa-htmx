#!/usr/bin/env bash
# Build script for Render deployment

set -o errexit

echo "Installing dependencies..."
pip install .

echo "Collecting static files..."
python manage.py collectstatic --noinput

echo "Running migrations..."
python manage.py migrate

echo "Build complete!"
