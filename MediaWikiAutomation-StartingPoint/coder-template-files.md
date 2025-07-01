# MediaWiki Automation - Coder Template Files

## 📁 Files to Create for Coder Template

To use this Coder template, create these 3 files in a directory:

### 1. `main.tf`
- **Filename**: `main.tf`
- **Content**: From artifact `mediawiki-coder-template`
- **Purpose**: Terraform configuration for Coder workspace

### 2. `Dockerfile`  
- **Filename**: `Dockerfile`
- **Content**: From artifact `mediawiki-dockerfile`
- **Purpose**: Container image with all development tools

### 3. `README.md`
- **Filename**: `README.md` 
- **Content**: From artifact `mediawiki-coder-readme`
- **Purpose**: Documentation for the template

## 🚀 How to Deploy

### Option A: CLI Upload
```bash
# Create directory
mkdir mediawiki-coder-template
cd mediawiki-coder-template

# Create the 3 files with content from artifacts
# Then push to Coder
coder templates push --name mediawiki-automation
```

### Option B: Web UI Upload
1. Create a zip file with the 3 files
2. Go to Coder → Templates → + Template
3. Upload the zip
4. Name it "mediawiki-automation"

## ✅ What This Template Provides

### Development Environment
- ✅ Python 3.11 with all MediaWiki automation packages
- ✅ PostgreSQL 15 database (auto-started)
- ✅ Redis 7 cache/queue (auto-started)
- ✅ Docker-in-Docker support
- ✅ VS Code in browser
- ✅ JupyterLab
- ✅ Kubernetes tools (kubectl, helm, k9s)

### Pre-installed Python Packages
- FastAPI, Uvicorn
- SQLAlchemy, Alembic  
- Celery, Redis
- Pywikibot (MediaWiki API)
- Pandoc integration
- LDAP authentication
- All testing tools

### Workspace Features
- Persistent home directory
- Pre-configured Git
- Environment variables set
- Project structure created
- Database ready to use

## 🎯 Quick Workspace Creation

```bash
# Create workspace with this template
coder create --template mediawiki-automation wiki-dev

# Connect
coder ssh wiki-dev

# Project is at ~/mediawiki-automation
cd ~/mediawiki-automation

# Services are running:
# PostgreSQL: localhost:5432 (mediawiki_user/dev_password)
# Redis: localhost:6379
```

## 📝 Summary

You need **just 3 files** to create a complete development environment for the MediaWiki Automation System:

1. **main.tf** - Workspace configuration
2. **Dockerfile** - Development image
3. **README.md** - Documentation

The template automatically:
- Creates the complete project structure
- Installs all dependencies
- Starts required services
- Configures the development environment

**Next Step**: Get the implementation code from the 4 phase artifacts to complete your project!