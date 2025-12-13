#!/bin/bash

# Setup script for Jobs Sync

echo "========================================"
echo "Jobs Sync Setup"
echo "========================================"
echo ""

# Check Ruby version
echo "Checking Ruby version..."
if ! command -v ruby &> /dev/null; then
    echo "❌ Ruby is not installed"
    echo "   Please install Ruby 3.3.1 or later"
    exit 1
fi

RUBY_VERSION=$(ruby -v | awk '{print $2}')
echo "✅ Ruby $RUBY_VERSION found"
echo ""

# Check if bundle is installed
echo "Checking for Bundler..."
if ! command -v bundle &> /dev/null; then
    echo "Installing Bundler..."
    gem install bundler
fi
echo "✅ Bundler found"
echo ""

# Install dependencies
echo "Installing dependencies..."
bundle install
if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi
echo ""

# Check for .env file
if [ ! -f .env ]; then
    echo "Creating .env file from template..."
    cp env.example .env
    echo "⚠️  Please edit .env with your API credentials"
    echo ""
    echo "Required variables:"
    echo "  - SIMPRO_API_URL"
    echo "  - SIMPRO_API_KEY"
    echo "  - HUBSPOT_ACCESS_TOKEN"
    echo ""
    echo "Run 'nano .env' or 'vim .env' to edit"
else
    echo "✅ .env file already exists"
fi
echo ""

# Make scripts executable
chmod +x sync_jobs.rb
chmod +x test_sync.rb
chmod +x setup.sh
echo "✅ Scripts are executable"
echo ""

echo "========================================"
echo "Setup Complete!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Edit .env with your API credentials"
echo "2. Run test: ./test_sync.rb"
echo "3. Run full sync: ./sync_jobs.rb"
echo ""

