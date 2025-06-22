#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_step() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

echo "========================================"
echo "🌱 GROW - COMPLETE SETUP AND INITIALIZATION"
echo "========================================"
echo ""
echo "This script will:"
echo "- Check prerequisites (Python, PostgreSQL)"
echo "- Create Python virtual environment"
echo "- Install all requirements"
echo "- Create and configure .env file"
echo "- Create database and load schema"
echo "- Start the application"
echo ""
echo "Prerequisites:"
echo "- Python 3.8+ installed"
echo "- PostgreSQL 10+ installed and running"
echo ""
read -p "Press Enter to continue..."

# ===========================================
# STEP 1: CHECK PREREQUISITES
# ===========================================
echo ""
print_step "[STEP 1/8] Checking prerequisites..."

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | cut -d ' ' -f 2)
    print_success "Python found: $PYTHON_VERSION"
    PYTHON_CMD="python3"
elif command -v python &> /dev/null; then
    PYTHON_VERSION=$(python --version 2>&1 | cut -d ' ' -f 2)
    # Check if it's Python 3
    if [[ $PYTHON_VERSION == 3.* ]]; then
        print_success "Python found: $PYTHON_VERSION"
        PYTHON_CMD="python"
    else
        print_error "Python 3.8+ required, found Python $PYTHON_VERSION"
        exit 1
    fi
else
    print_error "Python not found. Please install Python 3.8+"
    echo "Ubuntu/Debian: sudo apt update && sudo apt install python3 python3-pip python3-venv"
    echo "CentOS/RHEL: sudo yum install python3 python3-pip"
    echo "Fedora: sudo dnf install python3 python3-pip"
    exit 1
fi

# Check pip
if command -v pip3 &> /dev/null; then
    PIP_CMD="pip3"
elif command -v pip &> /dev/null; then
    PIP_CMD="pip"
else
    print_error "pip not found. Please install pip"
    exit 1
fi

# Check PostgreSQL
if command -v psql &> /dev/null; then
    PSQL_VERSION=$(psql --version | cut -d ' ' -f 3)
    print_success "PostgreSQL found: $PSQL_VERSION"
else
    print_error "PostgreSQL not found. Please install PostgreSQL"
    echo "Ubuntu/Debian: sudo apt update && sudo apt install postgresql postgresql-contrib"
    echo "CentOS/RHEL: sudo yum install postgresql-server postgresql-contrib"
    echo "Fedora: sudo dnf install postgresql-server postgresql-contrib"
    echo ""
    echo "After installation, start PostgreSQL:"
    echo "sudo systemctl start postgresql"
    echo "sudo systemctl enable postgresql"
    exit 1
fi

# Check if PostgreSQL is running
if ! systemctl is-active --quiet postgresql; then
    print_warning "PostgreSQL service is not running"
    echo "Starting PostgreSQL service..."
    sudo systemctl start postgresql
    if [ $? -ne 0 ]; then
        print_error "Failed to start PostgreSQL service"
        echo "Please start PostgreSQL manually: sudo systemctl start postgresql"
        exit 1
    fi
    print_success "PostgreSQL service started"
fi

# ===========================================
# STEP 2: CREATE VIRTUAL ENVIRONMENT
# ===========================================
echo ""
print_step "[STEP 2/8] Setting up Python virtual environment..."

if [ -d "venv" ]; then
    print_success "Virtual environment already exists"
else
    echo "Creating virtual environment..."
    $PYTHON_CMD -m venv venv
    if [ $? -ne 0 ]; then
        print_error "Failed to create virtual environment"
        echo "Make sure python3-venv is installed:"
        echo "Ubuntu/Debian: sudo apt install python3-venv"
        exit 1
    fi
    print_success "Virtual environment created"
fi

# ===========================================
# STEP 3: ACTIVATE VIRTUAL ENVIRONMENT
# ===========================================
echo ""
print_step "[STEP 3/8] Activating virtual environment..."

source venv/bin/activate
if [ $? -ne 0 ]; then
    print_error "Failed to activate virtual environment"
    exit 1
fi
print_success "Virtual environment activated"

# ===========================================
# STEP 4: INSTALL REQUIREMENTS
# ===========================================
echo ""
print_step "[STEP 4/8] Installing Python requirements..."

pip install --upgrade pip
pip install -r requirements.txt
if [ $? -ne 0 ]; then
    print_error "Failed to install requirements"
    exit 1
fi
print_success "All requirements installed successfully"

# ===========================================
# STEP 5: CREATE .ENV CONFIGURATION
# ===========================================
echo ""
print_step "[STEP 5/8] Creating .env configuration file..."

if [ -f ".env" ]; then
    print_warning ".env file already exists"
    read -p "Do you want to overwrite it? (y/n): " overwrite
    if [[ ! $overwrite =~ ^[Yy]$ ]]; then
        echo "Skipping .env creation"
        goto skip_env
    fi
fi

# Get database password
read -s -p "Enter PostgreSQL password for user 'postgres': " db_password
echo ""

# Create .env file
cat > .env << EOF
# GROW Application Configuration
SECRET_KEY=your-secret-key-change-in-production
DATABASE_URL=postgresql://postgres:${db_password}@localhost/grow_app
FLASK_ENV=development
FLASK_DEBUG=True
UPLOAD_FOLDER=uploads
MAX_CONTENT_LENGTH=16777216
EOF

print_success ".env file created successfully"

skip_env:

# ===========================================
# STEP 6: CREATE DATABASE
# ===========================================
echo ""
print_step "[STEP 6/8] Creating database..."

echo "Creating database 'grow_app'..."
export PGCLIENTENCODING=UTF8

# Drop database if exists (ignore errors)
sudo -u postgres psql -c "DROP DATABASE IF EXISTS grow_app;" 2>/dev/null

# Create database
sudo -u postgres psql -c "CREATE DATABASE grow_app WITH TEMPLATE=template0 ENCODING='UTF8';"
if [ $? -ne 0 ]; then
    print_error "Failed to create database"
    echo "Make sure PostgreSQL is running and you have the correct permissions"
    echo "Try: sudo -u postgres createdb grow_app"
    exit 1
fi
print_success "Database 'grow_app' created successfully"

# ===========================================
# STEP 7: INITIALIZE DATABASE SCHEMA
# ===========================================
echo ""
print_step "[STEP 7/8] Initializing database schema..."

echo "Loading database schema..."
export PGCLIENTENCODING=UTF8
sudo -u postgres psql -d grow_app -f "database/schema.sql"
if [ $? -ne 0 ]; then
    print_error "Failed to load schema"
    exit 1
fi

echo "Loading triggers..."
sudo -u postgres psql -d grow_app -f "database/triggers.sql"
if [ $? -ne 0 ]; then
    print_error "Failed to load triggers"
    exit 1
fi

echo "Loading procedures..."
sudo -u postgres psql -d grow_app -f "database/procedures.sql"
if [ $? -ne 0 ]; then
    print_error "Failed to load procedures"
    exit 1
fi

echo "Loading views..."
sudo -u postgres psql -d grow_app -f "database/views.sql"
if [ $? -ne 0 ]; then
    print_warning "Some views failed to load (this is usually not critical)"
fi

print_success "Database schema initialized successfully"

# Create uploads directory
if [ ! -d "uploads" ]; then
    mkdir uploads
    print_success "Created uploads directory"
fi

# ===========================================
# STEP 8: START APPLICATION
# ===========================================
echo ""
print_step "[STEP 8/8] Starting GROW application..."
echo ""
echo "========================================"
echo "🎉 SETUP COMPLETE!"
echo "========================================"
echo ""
echo "The GROW application will now start at:"
echo "URL: http://localhost:5000"
echo ""
echo "Demo data included:"
echo "- 3 demo plants with care history"
echo "- Multiple events and measurements"
echo "- Reminders and care schedules"
echo ""
echo "To stop the application, press Ctrl+C"
echo ""
read -p "Press Enter to start the application..."

echo "Starting Flask server..."
python app.py

echo ""
echo "========================================"
echo "🌱 GROW APPLICATION STOPPED"
echo "========================================"
echo ""
echo "To restart the application later:"
echo "1. Activate virtual environment: source venv/bin/activate"
echo "2. Run: python app.py"
echo ""
