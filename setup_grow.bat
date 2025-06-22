@echo off
chcp 65001 >nul 2>&1
setlocal EnableDelayedExpansion

echo ========================================
echo 🌱 GROW - COMPLETE SETUP AND INITIALIZATION
echo ========================================
echo.
echo This script will:
echo - Check prerequisites (Python, PostgreSQL)
echo - Create Python virtual environment
echo - Install all requirements
echo - Create and configure .env file
echo - Create database and load schema
echo - Start the application
echo.
echo Prerequisites:
echo - Python 3.8+ installed
echo - PostgreSQL 10+ installed and running
echo.
pause

:: ===========================================
:: STEP 1: CHECK PREREQUISITES
:: ===========================================
echo.
echo [STEP 1/8] Checking prerequisites...

:: Check Python
python --version >nul 2>&1
if errorlevel 1 (
    echo ❌ ERROR: Python not found in PATH
    echo Please install Python 3.8+ from https://python.org
    echo Make sure to check "Add Python to PATH" during installation
    pause
    exit /b 1
) else (
    for /f "tokens=2" %%a in ('python --version 2^>^&1') do echo ✅ Python found: %%a
)

:: Check PostgreSQL
echo Searching for PostgreSQL...
psql --version >nul 2>&1
if errorlevel 1 (
    echo PostgreSQL not in PATH, searching standard locations...
    
    set "PSQL_PATH="
    
    :: Search versions 10-17 in Program Files
    for %%d in (17 16 15 14 13 12 11 10) do (
        if exist "C:\Program Files\PostgreSQL\%%d\bin\psql.exe" (
            set "PSQL_PATH=C:\Program Files\PostgreSQL\%%d\bin"
            goto :found_psql
        )
    )
    
    :: Search versions 10-17 in Program Files (x86)
    for %%d in (17 16 15 14 13 12 11 10) do (
        if exist "C:\Program Files (x86)\PostgreSQL\%%d\bin\psql.exe" (
            set "PSQL_PATH=C:\Program Files (x86)\PostgreSQL\%%d\bin"
            goto :found_psql
        )
    )
    
    echo ❌ ERROR: PostgreSQL not found
    echo Please install PostgreSQL from https://postgresql.org
    echo Or ensure it's running and accessible
    pause
    exit /b 1
      :found_psql
    echo ✅ PostgreSQL found in: !PSQL_PATH!
    echo Adding to PATH for this session...
    set "PATH=!PSQL_PATH!;!PATH!"
    
    :: Test if psql is now accessible
    "!PSQL_PATH!\psql.exe" --version >nul 2>&1
    if errorlevel 1 (
        echo ❌ ERROR: Still cannot access PostgreSQL
        pause
        exit /b 1
    )
) else (
    for /f "tokens=3" %%a in ('psql --version 2^>^&1') do echo ✅ PostgreSQL found: %%a
)

:: ===========================================
:: STEP 2: CREATE VIRTUAL ENVIRONMENT
:: ===========================================
echo.
echo [STEP 2/8] Setting up Python virtual environment...

if exist "venv" (
    echo ✅ Virtual environment already exists
) else (
    echo Creating virtual environment...
    python -m venv venv
    if errorlevel 1 (
        echo ❌ ERROR: Failed to create virtual environment
        pause
        exit /b 1
    )
    echo ✅ Virtual environment created
)

:: ===========================================
:: STEP 3: ACTIVATE VIRTUAL ENVIRONMENT
:: ===========================================
echo.
echo [STEP 3/8] Activating virtual environment...

call venv\Scripts\activate.bat
if errorlevel 1 (
    echo ❌ ERROR: Failed to activate virtual environment
    pause
    exit /b 1
)
echo ✅ Virtual environment activated

:: ===========================================
:: STEP 4: INSTALL REQUIREMENTS
:: ===========================================
echo.
echo [STEP 4/8] Installing Python requirements...

pip install --upgrade pip
pip install -r requirements.txt
if errorlevel 1 (
    echo ❌ ERROR: Failed to install requirements
    pause
    exit /b 1
)
echo ✅ All requirements installed successfully

:: ===========================================
:: STEP 5: CREATE .ENV CONFIGURATION
:: ===========================================
echo.
echo [STEP 5/8] Creating .env configuration file...

if exist ".env" (
    echo ⚠️  .env file already exists
    set /p overwrite="Do you want to overwrite it? (y/n): "
    if /i not "!overwrite!"=="y" goto :skip_env
)

:: Get database password
set /p db_password="Enter PostgreSQL password for user 'postgres': "

:: Create .env file
(
echo # GROW Application Configuration
echo SECRET_KEY=your-secret-key-change-in-production
echo DATABASE_URL=postgresql://postgres:!db_password!@localhost/grow_app
echo FLASK_ENV=development
echo FLASK_DEBUG=True
echo UPLOAD_FOLDER=uploads
echo MAX_CONTENT_LENGTH=16777216
) > .env

echo ✅ .env file created successfully

:skip_env

:: ===========================================
:: STEP 6: CREATE DATABASE
:: ===========================================
echo.
echo [STEP 6/8] Creating database...

echo Creating database 'grow_app'...
set PGCLIENTENCODING=UTF8
"!PSQL_PATH!\psql.exe" -U postgres -c "DROP DATABASE IF EXISTS grow_app;" 2>nul
"!PSQL_PATH!\psql.exe" -U postgres -c "CREATE DATABASE grow_app WITH TEMPLATE=template0 ENCODING='UTF8';"
if errorlevel 1 (
    echo ❌ ERROR: Failed to create database
    echo Make sure PostgreSQL is running and you have the correct password
    pause
    exit /b 1
)
echo ✅ Database 'grow_app' created successfully

:: ===========================================
:: STEP 7: INITIALIZE DATABASE SCHEMA
:: ===========================================
echo.
echo [STEP 7/8] Initializing database schema...

echo Loading database schema...
set PGCLIENTENCODING=UTF8
"!PSQL_PATH!\psql.exe" -U postgres -d grow_app -f "database\schema.sql"
if errorlevel 1 (
    echo ❌ ERROR: Failed to load schema
    pause
    exit /b 1
)

echo Loading triggers...
"!PSQL_PATH!\psql.exe" -U postgres -d grow_app -f "database\triggers.sql"
if errorlevel 1 (
    echo ❌ ERROR: Failed to load triggers
    pause
    exit /b 1
)

echo Loading procedures...
"!PSQL_PATH!\psql.exe" -U postgres -d grow_app -f "database\procedures.sql"
if errorlevel 1 (
    echo ❌ ERROR: Failed to load procedures
    pause
    exit /b 1
)

echo Loading views...
"!PSQL_PATH!\psql.exe" -U postgres -d grow_app -f "database\views.sql"
if errorlevel 1 (
    echo ❌ WARNING: Some views failed to load (this is usually not critical)
)

echo ✅ Database schema initialized successfully

:: Create uploads directory
if not exist "uploads" (
    mkdir uploads
    echo ✅ Created uploads directory
)

:: ===========================================
:: STEP 8: START APPLICATION
:: ===========================================
echo.
echo [STEP 8/8] Starting GROW application...
echo.
echo ========================================
echo 🎉 SETUP COMPLETE!
echo ========================================
echo.
echo The GROW application will now start at:
echo URL: http://localhost:5000
echo.
echo Demo data included:
echo - 3 demo plants with care history
echo - Multiple events and measurements
echo - Reminders and care schedules
echo.
echo To stop the application, press Ctrl+C
echo.
pause

echo Starting Flask server...
python app.py

echo.
echo ========================================
echo 🌱 GROW APPLICATION STOPPED
echo ========================================
echo.
echo To restart the application later, use:
echo   start.bat
echo.
pause
