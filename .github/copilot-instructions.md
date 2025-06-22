<!-- Use this file to provide workspace-specific custom instructions to Copilot. For more details, visit https://code.visualstudio.com/docs/copilot/copilot-customization#_use-a-githubcopilotinstructionsmd-file -->

# Plant Tracker - Copilot Instructions

## Project Overview
This is a Flask web application for plant care tracking and management with PostgreSQL database featuring temporal and active database concepts.

## Technology Stack
- **Backend**: Python Flask
- **Database**: PostgreSQL with temporal features
- **ORM**: SQLAlchemy with Flask-SQLAlchemy
- **Frontend**: Bootstrap 5, HTML, CSS, JavaScript
- **Forms**: Flask-WTF and WTForms
- **File Upload**: Werkzeug for image handling

## Key Features
- Plant management with detailed tracking
- Event scheduling (watering, fertilizing, etc.)
- Automatic reminders system
- Image gallery with timestamp tracking
- Growth measurements and statistics
- Temporal database queries (track changes over time)
- Active database features (triggers, procedures, views)

## Database Architecture
### Core Tables
- `plants` - Main plant records with temporal columns
- `plant_types` - Plant species/varieties
- `events` - Care events (watering, fertilizing, etc.)
- `measurements` - Growth tracking data
- `plant_images` - Photo gallery
- `reminders` - Automated notifications
- `plants_history` - Temporal audit trail

### Active Database Features
- **Triggers**: Automatic timestamp updates, reminder creation, recurring events
- **Stored Procedures**: Complex operations for plant care management
- **Views**: Simplified data access patterns
- **Functions**: Utility functions for statistics and reporting

## Code Style Guidelines
- Follow PEP 8 for Python code
- Use descriptive variable and function names in Croatian/English
- Comment complex database operations
- Maintain consistent error handling
- Use Flask best practices for routing and templates

## Database Best Practices
- Use SQLAlchemy ORM for most operations
- Raw SQL for complex temporal queries and stored procedures
- Properly handle database connections and transactions
- Use database constraints and foreign keys
- Implement proper indexing for performance

## UI/UX Guidelines
- Bootstrap 5 components for consistent styling
- Mobile-responsive design
- Croatian language for user interface
- Green color scheme (plant-themed)
- Intuitive navigation and user-friendly interface

## File Organization
```
TBD projekt/
├── app.py              # Main Flask application
├── models.py           # SQLAlchemy models
├── forms.py            # WTForms definitions
├── database/           # SQL scripts
├── templates/          # Jinja2 templates
├── static/            # CSS, JS, images
├── uploads/           # User uploaded images
└── migrations/        # Database migrations
```

## Special Considerations
- Handle image uploads securely
- Implement proper error handling for database operations
- Use temporal queries for historical data access
- Maintain database triggers and procedures
- Ensure responsive design for mobile devices
- Follow Croatian naming conventions for UI elements
