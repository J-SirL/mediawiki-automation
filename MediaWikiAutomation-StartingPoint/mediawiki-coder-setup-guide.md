# MediaWiki Automation System - Complete Coder Setup Guide

## 🚀 Quick Start with Coder

### 1. Create Coder Template

Create a directory with these 3 files:

**📁 Required Files:**
- `main.tf` - From artifact `mediawiki-coder-template`
- `Dockerfile` - From artifact `mediawiki-dockerfile`  
- `README.md` - From artifact `mediawiki-coder-readme`

### 2. Push Template to Coder

```bash
# Option A: CLI
coder templates push --name mediawiki-automation

# Option B: Web UI
# Create zip with the 3 files and upload via Templates → + Template
```

### 3. Create Workspace

```bash
coder create --template mediawiki-automation wiki-dev
```

**Recommended Settings:**
- Python Version: 3.11
- Include Kubernetes Tools: Yes
- Workspace Size: Large (8 CPU, 16GB RAM)

### 4. Connect to Workspace

```bash
coder ssh wiki-dev
cd ~/mediawiki-automation
```

## 📂 Project Structure Created Automatically

```
~/mediawiki-automation/
├── mediawiki_automation/
│   ├── __init__.py
│   ├── main.py
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config_manager.py      # Phase 1
│   │   ├── auth_manager.py        # Phase 1
│   │   ├── logger.py              # Phase 1
│   │   ├── error_handler.py       # Phase 1
│   │   └── site_discovery.py      # Phase 1
│   ├── web/
│   │   ├── __init__.py
│   │   ├── app.py                 # Phase 2
│   │   ├── database.py            # Phase 2
│   │   ├── models.py              # Phase 2
│   │   ├── schemas.py             # Phase 2
│   │   └── auth/
│   │       ├── __init__.py
│   │       ├── jwt_handler.py     # Phase 2
│   │       └── ad_auth.py         # Phase 2
│   └── workers/
│       ├── __init__.py
│       ├── celery_app.py          # Phase 3
│       ├── content_converter.py   # Phase 3
│       ├── sync_engine.py         # Phase 3
│       └── file_monitor.py        # Phase 3
├── config/
│   └── base_config.yaml          # Auto-created
├── content/
│   └── Git-Documentation/
│       └── .mediawiki-config.yaml # Sample config
├── requirements/
│   └── base.txt                  # All dependencies
├── .env                          # Environment variables
├── setup.sh                      # Setup script
└── start.sh                      # Start script
```

## 💻 Extracting the Code

### Method 1: Manual Copy-Paste

Copy the code from each artifact file to the corresponding location:

**Phase 1 Files** (from `phase1-core-files.py`):
- `config_manager.py` → `mediawiki_automation/core/config_manager.py`
- `logger.py` → `mediawiki_automation/core/logger.py`
- `error_handler.py` → `mediawiki_automation/core/error_handler.py`
- `auth_manager.py` → `mediawiki_automation/core/auth_manager.py`
- `site_discovery.py` → `mediawiki_automation/core/site_discovery.py`
- `main.py` → `mediawiki_automation/main.py`

**Phase 2 Files** (from `phase2-web-files.py`):
- `models.py` → `mediawiki_automation/web/models.py`
- `database.py` → `mediawiki_automation/web/database.py`
- `schemas.py` → `mediawiki_automation/web/schemas.py`
- `app.py` → `mediawiki_automation/web/app.py`
- `jwt_handler.py` → `mediawiki_automation/web/auth/jwt_handler.py`
- `ad_auth.py` → `mediawiki_automation/web/auth/ad_auth.py`

**Phase 3 Files** (from `phase3-workers-files.py`):
- `content_converter.py` → `mediawiki_automation/workers/content_converter.py`
- `file_monitor.py` → `mediawiki_automation/workers/file_monitor.py`
- `sync_engine.py` → `mediawiki_automation/workers/sync_engine.py`
- `celery_app.py` → `mediawiki_automation/workers/celery_app.py`

### Method 2: Using VS Code in Coder

1. Click "VS Code" in your Coder dashboard
2. Open the file tree
3. Create new files and paste content directly

## 🔧 Services Pre-Configured

The Coder workspace automatically starts:

| Service | Port | Credentials |
|---------|------|-------------|
| PostgreSQL | 5432 | mediawiki_user / dev_password |
| Redis | 6379 | No auth |
| pgAdmin | 5050 | admin@admin.com / admin |

## 🚀 Starting the Application

### 1. Run Setup (First Time)

```bash
cd ~/mediawiki-automation
./setup.sh
```

### 2. Start Web Application

```bash
./start.sh
# Or manually:
uvicorn mediawiki_automation.web.app:app --host 0.0.0.0 --port 8000 --reload
```

### 3. Access the Application

In Coder dashboard, click:
- **MediaWiki Web App** - Main application
- **API Documentation** - Swagger docs
- **pgAdmin** - Database management

### 4. Start Background Workers

```bash
# In a new terminal
celery -A mediawiki_automation.workers.celery_app worker --loglevel=info

# In another terminal for scheduler
celery -A mediawiki_automation.workers.celery_app beat --loglevel=info
```

### 5. Monitor Celery (Optional)

```bash
celery -A mediawiki_automation.workers.celery_app flower --port=5555
```

Then access via Coder dashboard → "Celery Flower"

## 📋 Environment Configuration

The `.env` file is pre-created with:

```bash
DATABASE_URL=postgresql://mediawiki_user:dev_password@localhost:5432/mediawiki_automation
REDIS_URL=redis://localhost:6379/0
JWT_SECRET=dev-secret-key-change-in-production
ENVIRONMENT=development
LOG_LEVEL=DEBUG
```

Add your MediaWiki credentials:
```bash
GIT_WIKI_PASSWORD=your-bot-password
GITHUB_ADMIN_PASSWORD=your-bot-password
AD_SERVER=ldap://your-dc.company.com
AD_SERVICE_PASSWORD=your-ad-password
```

## ✅ Verification Steps

### 1. Check Services

```bash
# PostgreSQL
psql -h localhost -U mediawiki_user -d mediawiki_automation -c "SELECT 1;"

# Redis
redis-cli ping

# Python packages
python -c "import fastapi, pywikibot, celery; print('All packages installed!')"
```

### 2. Test API

```bash
# Health check
curl http://localhost:8000/health

# API docs
curl http://localhost:8000/api/docs
```

### 3. Create Admin User

The admin user is created automatically by the web app on first run:
- Username: `admin`
- Password: `admin123`

### 4. Test Login

```bash
curl -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}'
```

## 🐛 Troubleshooting

### Services Not Running

```bash
# Check Docker containers
docker ps

# Restart if needed
docker start postgres-mediawiki
docker start redis-mediawiki
docker start pgadmin-mediawiki
```

### Import Errors

```bash
# Ensure you're in the right directory
cd ~/mediawiki-automation

# Check Python path
python -c "import sys; print(sys.path)"

# Install missing packages
pip install -r requirements/base.txt
```

### Database Issues

```bash
# Connect to PostgreSQL
docker exec -it postgres-mediawiki psql -U mediawiki_user -d mediawiki_automation

# Check tables
\dt
```

## 🎯 Next Steps

1. **Configure MediaWiki Instances**
   - Create bot accounts on your wikis
   - Add credentials to `.env`
   - Update `config/base_config.yaml`

2. **Create Your First Site**
   - Add content to `content/Your-Site/`
   - Create `.mediawiki-config.yaml`
   - Use web UI to create and approve site

3. **Test Sync**
   - Trigger manual sync from web UI
   - Monitor progress in real-time
   - Check MediaWiki for synced content

4. **Deploy to Production**
   - Use Kubernetes manifests (Phase 4)
   - Configure production secrets
   - Set up monitoring

## 📚 Development Tips

### Using JupyterLab

Access JupyterLab from Coder dashboard for testing:

```python
# Test database connection
from mediawiki_automation.web.database import DatabaseManager
db_manager = DatabaseManager("postgresql://mediawiki_user:dev_password@localhost:5432/mediawiki_automation")
db = db_manager.get_session()
print("Database connected!")

# Test MediaWiki connection
import pywikibot
site = pywikibot.Site('en', 'wikipedia')
print(f"Connected to: {site}")
```

### Running Tests

```bash
cd ~/mediawiki-automation
python -m pytest tests/ -v
```

### Code Formatting

```bash
# Format code
black mediawiki_automation/

# Check linting
flake8 mediawiki_automation/

# Type checking
mypy mediawiki_automation/
```

## 🚀 Ready to Go!

Your complete MediaWiki Automation development environment is ready. You have:

- ✅ All services running (PostgreSQL, Redis, pgAdmin)
- ✅ Python environment with all packages
- ✅ VS Code and JupyterLab for development
- ✅ Complete project structure
- ✅ Sample configuration files

Just extract the code from the provided artifacts and start developing!