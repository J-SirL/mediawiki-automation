# MediaWiki Automation - Coder Development Template

This Coder template provides a complete development environment for the MediaWiki Automation System with all required tools and services pre-configured.

## 🚀 Features

### Development Environment
- **Python 3.11** (configurable to 3.10 or 3.12)
- **PostgreSQL 15** - Database for application data
- **Redis 7** - Cache and message queue
- **All Python packages** pre-installed (FastAPI, SQLAlchemy, Celery, etc.)
- **Docker-in-Docker** support for container development

### Development Tools
- **VS Code Server** - Full IDE in browser
- **JupyterLab** - For data analysis and testing
- **pgAdmin** - Database management interface
- **Git** pre-configured with your identity
- **Python tools**: black, flake8, mypy, pytest
- **Kubernetes tools** (optional): kubectl, helm, k9s

### Pre-configured Services
- FastAPI web app endpoint
- API documentation (Swagger UI)
- Database and Redis connections
- Environment variables set up

## 📋 Template Structure

```
mediawiki-automation-coder/
├── main.tf              # Terraform configuration
├── Dockerfile           # Workspace image definition
└── README.md           # This file
```

## 🔧 How to Use

### 1. Create Template in Coder

```bash
# Upload this template to Coder
coder templates push --name mediawiki-automation

# Or via Web UI:
# 1. Go to Templates → + Template
# 2. Upload the template files
# 3. Name it "mediawiki-automation"
```

### 2. Create Workspace

```bash
coder create --template mediawiki-automation mediawiki-dev
```

Or use the web interface with these options:
- **Python Version**: 3.11 (recommended)
- **Include Kubernetes Tools**: Yes (if deploying to K8s)
- **Workspace Size**: Medium (4 CPU, 8GB RAM)

### 3. Access Your Workspace

After creation, you'll have access to:
- **VS Code**: Full IDE with Python support
- **Terminal**: SSH or web terminal
- **JupyterLab**: For notebooks and testing
- **Web Apps**: When you start the FastAPI server

### 4. Initial Setup

The workspace automatically:
1. Creates the project structure
2. Installs all Python dependencies
3. Starts PostgreSQL and Redis
4. Sets up development tools

## 💻 Development Workflow

### Starting the Project

1. **SSH into workspace**:
   ```bash
   coder ssh mediawiki-dev
   ```

2. **Navigate to project**:
   ```bash
   cd ~/mediawiki-automation
   ```

3. **Extract code from artifacts** (if you have them):
   ```bash
   # The extraction script is already there
   ./extraction-script.sh
   
   # Then copy code from artifacts as per the setup guide
   ```

4. **Start the web application**:
   ```bash
   cd ~/mediawiki-automation
   uvicorn mediawiki_automation.web.app:app --reload --host 0.0.0.0
   ```

5. **Access the application**:
   - Click "MediaWiki Web App" in Coder dashboard
   - Or navigate to the FastAPI endpoint

### Database Access

PostgreSQL is running with:
- **Host**: localhost
- **Port**: 5432
- **Database**: mediawiki_automation
- **User**: mediawiki_user
- **Password**: dev_password

Connect via:
```bash
psql -h localhost -U mediawiki_user -d mediawiki_automation
```

Or use pgAdmin (if you start it):
```bash
docker run -d -p 5050:80 \
  -e PGADMIN_DEFAULT_EMAIL=admin@admin.com \
  -e PGADMIN_DEFAULT_PASSWORD=admin \
  dpage/pgadmin4
```

### Redis Access

Redis is running on default port:
```bash
redis-cli -h localhost
```

### Running Tests

```bash
cd ~/mediawiki-automation
python -m pytest tests/ -v
```

### Background Workers

Start Celery workers:
```bash
celery -A mediawiki_automation.workers.celery_app worker --loglevel=info
```

Start Celery beat (scheduler):
```bash
celery -A mediawiki_automation.workers.celery_app beat --loglevel=info
```

## 🛠️ Customization

### Environment Variables

Pre-configured in the workspace:
- `DATABASE_URL` - PostgreSQL connection
- `REDIS_URL` - Redis connection
- `ENVIRONMENT` - Set to "development"
- `LOG_LEVEL` - Set to "DEBUG"

Add more in your `.env` file:
```bash
JWT_SECRET=your-dev-secret
AD_SERVER=ldap://your-dc.company.com
GIT_WIKI_PASSWORD=your-bot-password
```

### Adding Dependencies

Install additional Python packages:
```bash
pip install package-name

# Save to requirements
pip freeze > requirements.txt
```

### Kubernetes Development

If you enabled Kubernetes tools:
```bash
# Test kubectl
kubectl version --client

# Test helm
helm version

# Use k9s for cluster management
k9s
```

## 📊 Resource Monitoring

The workspace shows real-time metrics:
- CPU usage
- RAM usage
- PostgreSQL status
- Redis status

## 🐛 Troubleshooting

### Services Not Running

Check Docker containers:
```bash
docker ps
```

Restart services if needed:
```bash
# PostgreSQL
docker start postgres-mediawiki

# Redis
docker start redis-mediawiki
```

### Port Conflicts

If ports are in use:
```bash
# Find what's using a port
sudo lsof -i :5432

# Stop conflicting service or use different ports
```

### Permission Issues

The workspace runs as `coder` user with sudo access:
```bash
sudo command-that-needs-permissions
```

## 🔄 Workspace Lifecycle

### Stopping Workspace
When you stop the workspace:
- Docker containers are preserved
- Home directory is persistent
- Database data is preserved

### Starting Workspace
When you start the workspace:
- Services auto-start
- Previous work is restored
- Environment is ready immediately

## 📚 Next Steps

1. **Get the Implementation Code**:
   - Request the 4 phase artifacts from the previous chat
   - Extract code into the project structure

2. **Configure MediaWiki Instances**:
   - Set up bot accounts on your wikis
   - Add credentials to environment

3. **Start Development**:
   - Run the web app
   - Create test content
   - Implement new features

4. **Deploy to Production**:
   - Use included Kubernetes manifests
   - Follow production deployment guide

## 🆘 Support

- Check workspace logs: `coder ssh mediawiki-dev --log-level debug`
- View container logs: `docker logs container-name`
- Restart workspace if issues persist

This template provides everything you need to develop, test, and deploy the MediaWiki Automation System!