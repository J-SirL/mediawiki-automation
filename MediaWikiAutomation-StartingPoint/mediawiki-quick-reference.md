# MediaWiki Automation - Quick Reference Card

## 🚀 Essential Commands

### Coder Workspace
```bash
# Create workspace
coder create --template mediawiki-automation wiki-dev

# Connect
coder ssh wiki-dev

# Open VS Code
coder code wiki-dev
```

### Application Commands
```bash
# Navigate to project
cd ~/mediawiki-automation

# Start web app
./start.sh
# OR
uvicorn mediawiki_automation.web.app:app --host 0.0.0.0 --port 8000 --reload

# Start Celery worker
celery -A mediawiki_automation.workers.celery_app worker --loglevel=info

# Start Celery beat (scheduler)
celery -A mediawiki_automation.workers.celery_app beat --loglevel=info

# Start Celery Flower (monitoring)
celery -A mediawiki_automation.workers.celery_app flower --port=5555
```

## 🌐 Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| Web App | http://localhost:8000 | admin / admin123 |
| API Docs | http://localhost:8000/api/docs | - |
| pgAdmin | http://localhost:5050 | admin@admin.com / admin |
| Celery Flower | http://localhost:5555 | - |
| JupyterLab | Via Coder Dashboard | - |
| VS Code | Via Coder Dashboard | - |

## 🗄️ Database Access

```bash
# PostgreSQL
Host: localhost
Port: 5432
Database: mediawiki_automation
User: mediawiki_user
Password: dev_password

# Redis
Host: localhost
Port: 6379
Database: 0
```

## 🔧 Service Management

```bash
# Check services
docker ps

# Restart PostgreSQL
docker restart postgres-mediawiki

# Restart Redis
docker restart redis-mediawiki

# View logs
docker logs postgres-mediawiki
docker logs redis-mediawiki
```

## 📁 Key Files

```
~/mediawiki-automation/
├── .env                    # Environment variables
├── config/base_config.yaml # Main configuration
├── start.sh               # Start web app
├── setup.sh               # Initial setup
└── requirements/base.txt   # Python dependencies
```

## 🧪 Testing

```bash
# Run all tests
python -m pytest tests/ -v

# Run with coverage
python -m pytest tests/ --cov=mediawiki_automation

# Format code
black mediawiki_automation/

# Lint code
flake8 mediawiki_automation/
```

## 🔐 API Testing

```bash
# Get token
TOKEN=$(curl -s -X POST http://localhost:8000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"admin123"}' | \
  jq -r '.access_token')

# List sites
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/sites

# System status
curl -H "Authorization: Bearer $TOKEN" http://localhost:8000/api/system/status
```

## 📝 Create a Test Site

1. Create content:
```bash
mkdir -p content/Test-Wiki
echo "# Test Wiki" > content/Test-Wiki/README.md
```

2. Create config:
```yaml
# content/Test-Wiki/.mediawiki-config.yaml
metadata:
  created_by: "admin@company.com"
  status: "approved"
site:
  name: "test_wiki"
  display_name: "Test Wiki"
  wiki_url: "https://test.mediawiki.com"
  wiki_base_path: "Test"
sync:
  auto_sync: true
```

3. Sync via API:
```bash
curl -X POST http://localhost:8000/api/sites/1/sync \
  -H "Authorization: Bearer $TOKEN"
```

## 🐛 Quick Debugging

```bash
# Check Python imports
python -c "import mediawiki_automation; print('✅ Package OK')"

# Check database connection
python -c "import psycopg2; psycopg2.connect('postgresql://mediawiki_user:dev_password@localhost:5432/mediawiki_automation'); print('✅ DB OK')"

# Check Redis
redis-cli ping

# View web app logs
# (They appear in the terminal where you ran ./start.sh)

# View Celery logs
# (They appear in the terminal where you ran celery worker)
```

## 💾 Backup & Restore

```bash
# Backup database
pg_dump -h localhost -U mediawiki_user mediawiki_automation > backup.sql

# Restore database
psql -h localhost -U mediawiki_user mediawiki_automation < backup.sql

# Backup content
tar -czf content-backup.tar.gz content/

# Restore content
tar -xzf content-backup.tar.gz
```

---

**Keep this handy while developing!** 🚀