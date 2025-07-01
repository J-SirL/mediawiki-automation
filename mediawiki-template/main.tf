terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

locals {
  username = "coder"
}

data "coder_provisioner" "me" {}
data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}

# Parameters for customization
data "coder_parameter" "python_version" {
  name         = "python_version"
  display_name = "Python Version"
  description  = "Select Python version for development"
  default      = "3.11"
  type         = "string"
  mutable      = false
  
  option {
    name  = "Python 3.11 (Recommended)"
    value = "3.11"
  }
  
  option {
    name  = "Python 3.10"
    value = "3.10"
  }
  
  option {
    name  = "Python 3.12"
    value = "3.12"
  }
}

data "coder_parameter" "include_kubernetes" {
  name         = "include_kubernetes"
  display_name = "Include Kubernetes Tools"
  description  = "Install kubectl, helm, and k9s for Kubernetes deployment"
  default      = "true"
  type         = "bool"
  mutable      = true
}

data "coder_parameter" "workspace_size" {
  name         = "workspace_size"
  display_name = "Workspace Size"
  description  = "Resources for your workspace"
  default      = "large"
  type         = "string"
  mutable      = false
  
  option {
    name  = "Medium (4 CPU, 8GB RAM)"
    value = "medium"
  }
  
  option {
    name  = "Large (8 CPU, 16GB RAM) - Recommended"
    value = "large"
  }
  
  option {
    name  = "XLarge (16 CPU, 32GB RAM)"
    value = "xlarge"
  }
}

# Resource limits based on size
locals {
  cpu_limit = {
    medium = "4000m"
    large  = "8000m"
    xlarge = "16000m"
  }
  
  memory_limit = {
    medium = "8Gi"
    large  = "16Gi"
    xlarge = "32Gi"
  }
}

# Coder agent with comprehensive setup
resource "coder_agent" "main" {
  arch = data.coder_provisioner.me.arch
  os   = "linux"
  
  startup_script = <<-EOT
    set -e
    
    echo "🚀 Starting MediaWiki Automation workspace setup..."
    
    # Create project structure
    mkdir -p ~/mediawiki-automation/{mediawiki_automation/{core,web/{auth,api,frontend},workers,database/{migrations/versions},utils},config/{environments,instances,auth},content/{Git-Documentation/{basics,commands},GitHub-Administration,General-Documentation},kubernetes/{configmaps,secrets,deployments,services,ingress,persistent-volumes,monitoring,security,autoscaling,cronjobs},docker,scripts,tests/{unit,integration,e2e},docs/{api,deployment,user-guide},requirements,tools,cache,logs,backups}
    
    # Create __init__.py files for Python packages
    find ~/mediawiki-automation/mediawiki_automation -type d -exec touch {}/__init__.py \;
    find ~/mediawiki-automation/tests -type d -exec touch {}/__init__.py \;
    
    # Install system dependencies for python-ldap
    sudo apt-get update && sudo apt-get install -y libldap2-dev libsasl2-dev ldap-utils
    
    # Install Python packages
    pip install --user fastapi uvicorn[standard] sqlalchemy alembic pydantic[email] python-multipart python-jose[cryptography] passlib[bcrypt] redis celery pywikibot pypandoc pyyaml psycopg2-binary python-ldap requests aiofiles asyncio-mqtt prometheus-client structlog click typer rich pytest pytest-asyncio pytest-cov httpx black isort flake8 mypy pre-commit ipython jupyter jupyterlab notebook websockets jinja2 kombu watchdog aiofiles
    
    # Install Kubernetes tools if requested
    if [ "${data.coder_parameter.include_kubernetes.value}" = "true" ]; then
      # Install kubectl
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/
      
      # Install helm
      curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
      
      # Install k9s
      curl -sL https://github.com/derailed/k9s/releases/latest/download/k9s_Linux_amd64.tar.gz | tar xz
      sudo mv k9s /usr/local/bin/
    fi
    
    # Start PostgreSQL
    docker run -d --name postgres-mediawiki \
      -e POSTGRES_USER=mediawiki_user \
      -e POSTGRES_PASSWORD=dev_password \
      -e POSTGRES_DB=mediawiki_automation \
      -p 5432:5432 \
      --restart unless-stopped \
      postgres:15-alpine
    
    # Start Redis
    docker run -d --name redis-mediawiki \
      -p 6379:6379 \
      --restart unless-stopped \
      redis:7-alpine redis-server --appendonly yes --maxmemory 1gb --maxmemory-policy allkeys-lru
    
    # Start pgAdmin
    docker run -d --name pgadmin-mediawiki \
      -p 5050:80 \
      -e PGADMIN_DEFAULT_EMAIL=admin@admin.com \
      -e PGADMIN_DEFAULT_PASSWORD=admin \
      --restart unless-stopped \
      dpage/pgadmin4
    
    # Wait for services
    echo "⏳ Waiting for services to start..."
    sleep 15
    
    # Create base configuration if not exists
    if [ ! -f ~/mediawiki-automation/config/base_config.yaml ]; then
      cat > ~/mediawiki-automation/config/base_config.yaml << 'CONFIG'
system:
  log_level: "DEBUG"
  max_concurrent_operations: 5
  retry_attempts: 3
  timeout_seconds: 30

content_discovery:
  base_paths: ["/home/coder/mediawiki-automation/content"]

authentication:
  git_wiki:
    url: "https://git.mediawiki.urlen"
    username: "automation_bot"
    password: "\${GIT_WIKI_PASSWORD}"
    family: "mediawiki"
  github_admin_wiki:
    url: "https://github-admin.mediawiki.urlen"
    username: "admin_bot"
    password: "\${GITHUB_ADMIN_PASSWORD}"
    family: "mediawiki"

content_conversion:
  pandoc_executable: "pandoc"
  default_format: "mediawiki"
  preserve_images: true

web:
  host: "0.0.0.0"
  port: 8000
  cors_origins: ["*"]
  jwt_expiration_hours: 24

logging:
  level: "DEBUG"
  format: "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
  file_path: "logs/mediawiki_automation.log"
  max_file_size: "10MB"
  backup_count: 5

error_handling:
  retry_attempts: 3
  base_delay: 1
  enable_notifications: true
CONFIG
    fi
    
    # Create sample site configuration
    if [ ! -f ~/mediawiki-automation/content/Git-Documentation/.mediawiki-config.yaml ]; then
      cat > ~/mediawiki-automation/content/Git-Documentation/.mediawiki-config.yaml << 'SITECONFIG'
metadata:
  created_by: "admin@company.com"
  created_date: "2025-06-28T10:00:00Z"
  status: "approved"

site:
  name: "git_wiki"
  display_name: "Git Documentation Wiki"
  wiki_url: "https://git.mediawiki.urlen"
  wiki_base_path: "Git"
  description: "Internal Git documentation and best practices"

folder_mapping:
  - folder: "basics"
    wiki_name: "Basics"
  - folder: "commands"
    wiki_name: "Commands"

content_processing:
  - applies_to: "commands/"
    add_category: "[[Category:Git Commands]]"
    add_template: "{{Git-Commands-Nav}}"

sync:
  schedule: "0 */6 * * *"
  auto_sync: true
SITECONFIG
    fi
    
    # Create requirements files
    mkdir -p ~/mediawiki-automation/requirements
    cat > ~/mediawiki-automation/requirements/base.txt << 'REQUIREMENTS'
fastapi>=0.104.0
uvicorn[standard]>=0.24.0
sqlalchemy>=2.0.0
alembic>=1.12.0
pydantic[email]>=2.5.0
python-multipart>=0.0.6
python-jose[cryptography]>=3.3.0
passlib[bcrypt]>=1.7.4
redis>=5.0.0
celery>=5.3.0
pywikibot>=8.4.0
pypandoc>=1.12
pyyaml>=6.0.1
psycopg2-binary>=2.9.0
python-ldap>=3.4.0
requests>=2.31.0
aiofiles>=23.2.1
asyncio-mqtt>=0.16.1
prometheus-client>=0.19.0
structlog>=23.2.0
click>=8.1.7
typer>=0.9.0
rich>=13.7.0
REQUIREMENTS
    
    # Create .env file
    cat > ~/mediawiki-automation/.env << 'ENV'
# Database
DATABASE_URL=postgresql://mediawiki_user:dev_password@localhost:5432/mediawiki_automation

# Redis
REDIS_URL=redis://localhost:6379/0

# Authentication
JWT_SECRET=dev-secret-key-change-in-production
AD_SERVER=ldap://dc.company.com
AD_SERVICE_ACCOUNT=svc_mediawiki@company.com
AD_SERVICE_PASSWORD=your-ad-password

# MediaWiki Bot Credentials
GIT_WIKI_PASSWORD=your-git-wiki-bot-password
GITHUB_ADMIN_PASSWORD=your-github-admin-bot-password
GENERAL_DOC_PASSWORD=your-general-doc-bot-password

# Environment
ENVIRONMENT=development
LOG_LEVEL=DEBUG
ENV
    
    # Create setup script
    cat > ~/mediawiki-automation/setup.sh << 'SETUP'
#!/bin/bash
set -euo pipefail

echo "🚀 Starting MediaWiki Automation System setup..."

# Check prerequisites
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Create virtual environment
if [[ ! -d "venv" ]]; then
    python3 -m venv venv
    echo "✅ Virtual environment created"
fi

# Activate virtual environment
source venv/bin/activate

# Install dependencies
pip install --upgrade pip
pip install -r requirements/base.txt
echo "✅ Dependencies installed"

# Run database migrations
echo "🗄️ Setting up database..."
cd mediawiki_automation
alembic init database/migrations 2>/dev/null || true
cd ..

echo "✅ Setup completed!"
echo ""
echo "🌐 Next steps:"
echo "  1. Copy implementation code to respective files"
echo "  2. Run: python -m mediawiki_automation.web.app"
echo "  3. Access: http://localhost:8000"
SETUP
    
    chmod +x ~/mediawiki-automation/setup.sh
    
    # Create start script
    cat > ~/mediawiki-automation/start.sh << 'START'
#!/bin/bash
cd ~/mediawiki-automation
source venv/bin/activate 2>/dev/null || true
uvicorn mediawiki_automation.web.app:app --host 0.0.0.0 --port 8000 --reload
START
    
    chmod +x ~/mediawiki-automation/start.sh
    
    # Install code-server
    curl -fsSL https://code-server.dev/install.sh | sh -s -- --method=standalone --prefix=/tmp/code-server
    
    # Install VS Code extensions
    /tmp/code-server/bin/code-server --install-extension ms-python.python --force
    /tmp/code-server/bin/code-server --install-extension ms-python.vscode-pylance --force
    /tmp/code-server/bin/code-server --install-extension ms-azuretools.vscode-docker --force
    /tmp/code-server/bin/code-server --install-extension redhat.vscode-yaml --force
    /tmp/code-server/bin/code-server --install-extension ms-kubernetes-tools.vscode-kubernetes-tools --force
    
    # Start code-server
    /tmp/code-server/bin/code-server --auth none --port 13337 >/tmp/code-server.log 2>&1 &
    
    # Start Jupyter
    jupyter notebook --generate-config
    echo "c.NotebookApp.token = ''" >> ~/.jupyter/jupyter_notebook_config.py
    echo "c.NotebookApp.password = ''" >> ~/.jupyter/jupyter_notebook_config.py
    jupyter lab --ip=0.0.0.0 --port=8888 --no-browser --NotebookApp.base_url=/@${data.coder_workspace_owner.me.name}/${data.coder_workspace.me.name}/apps/jupyter/ >/tmp/jupyter.log 2>&1 &
    
    echo "✅ MediaWiki Automation Development Environment Ready!"
    echo ""
    echo "📍 Services:"
    echo "   PostgreSQL: localhost:5432 (mediawiki_user/dev_password)"
    echo "   Redis: localhost:6379"
    echo "   pgAdmin: http://localhost:5050 (admin@admin.com/admin)"
    echo ""
    echo "📂 Project location: ~/mediawiki-automation"
    echo ""
    echo "🚀 To start the web app:"
    echo "   cd ~/mediawiki-automation"
    echo "   ./start.sh"
  EOT
  
  # Environment variables
  env = {
    GIT_AUTHOR_NAME     = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_AUTHOR_EMAIL    = "${data.coder_workspace_owner.me.email}"
    GIT_COMMITTER_NAME  = coalesce(data.coder_workspace_owner.me.full_name, data.coder_workspace_owner.me.name)
    GIT_COMMITTER_EMAIL = "${data.coder_workspace_owner.me.email}"
    
    # Project environment variables
    DATABASE_URL = "postgresql://mediawiki_user:dev_password@localhost:5432/mediawiki_automation"
    REDIS_URL    = "redis://localhost:6379/0"
    ENVIRONMENT  = "development"
    LOG_LEVEL    = "DEBUG"
    JWT_SECRET   = "dev-secret-key-change-in-production"
  }
  
  # Metadata for workspace info
  metadata {
    display_name = "CPU Usage"
    key          = "0_cpu_usage"
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }
  
  metadata {
    display_name = "RAM Usage"
    key          = "1_ram_usage"
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }
  
  metadata {
    display_name = "PostgreSQL"
    key          = "2_postgres"
    script       = "docker ps --filter name=postgres-mediawiki --format 'table {{.Status}}' | tail -n1 || echo 'Not running'"
    interval     = 30
    timeout      = 1
  }
  
  metadata {
    display_name = "Redis"
    key          = "3_redis"
    script       = "docker ps --filter name=redis-mediawiki --format 'table {{.Status}}' | tail -n1 || echo 'Not running'"
    interval     = 30
    timeout      = 1
  }
  
  metadata {
    display_name = "Celery Workers"
    key          = "4_celery"
    script       = "ps aux | grep -c '[c]elery worker' || echo '0'"
    interval     = 30
    timeout      = 1
  }
}

# Code Server
resource "coder_app" "code-server" {
  agent_id     = coder_agent.main.id
  slug         = "code-server"
  display_name = "VS Code"
  url          = "http://localhost:13337/?folder=/home/${local.username}/mediawiki-automation"
  icon         = "/icon/code.svg"
  subdomain    = false
  share        = "owner"
  
  healthcheck {
    url      = "http://localhost:13337/healthz"
    interval = 5
    threshold = 6
  }
}

# JupyterLab
resource "coder_app" "jupyter" {
  agent_id     = coder_agent.main.id
  slug         = "jupyter"
  display_name = "JupyterLab"
  url          = "http://localhost:8888"
  icon         = "/icon/jupyter.svg"
  subdomain    = false
  share        = "owner"
}

# FastAPI App
resource "coder_app" "fastapi" {
  agent_id     = coder_agent.main.id
  slug         = "web-app"
  display_name = "MediaWiki Web App"
  url          = "http://localhost:8000"
  icon         = "/icon/fastapi.svg"
  subdomain    = false
  share        = "owner"
}

# API Documentation
resource "coder_app" "api-docs" {
  agent_id     = coder_agent.main.id
  slug         = "api-docs"
  display_name = "API Documentation"
  url          = "http://localhost:8000/api/docs"
  icon         = "/icon/swagger.svg"
  subdomain    = false
  share        = "owner"
}

# pgAdmin
resource "coder_app" "pgadmin" {
  agent_id     = coder_agent.main.id
  slug         = "pgadmin"
  display_name = "pgAdmin"
  url          = "http://localhost:5050"
  icon         = "/icon/postgresql.svg"
  subdomain    = false
  share        = "owner"
}

# Celery Flower (monitoring)
resource "coder_app" "flower" {
  agent_id     = coder_agent.main.id
  slug         = "flower"
  display_name = "Celery Flower"
  url          = "http://localhost:5555"
  icon         = "/icon/celery.svg"
  subdomain    = false
  share        = "owner"
}

# Persistent home volume
resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  lifecycle {
    ignore_changes = all
  }
}

# Project data volume
resource "docker_volume" "project_volume" {
  name = "coder-${data.coder_workspace.me.id}-project"
  lifecycle {
    ignore_changes = all
  }
}

# Docker image with all dependencies
resource "docker_image" "main" {
  name = "coder-${data.coder_workspace.me.id}"
  build {
    context = "."
    build_args = {
      PYTHON_VERSION = data.coder_parameter.python_version.value
    }
  }
  triggers = {
    dir_sha1 = sha1(join("", [for f in fileset(path.module, "Dockerfile") : filesha1(f)]))
  }
}

# Main workspace container
resource "docker_container" "workspace" {
  count = data.coder_workspace.me.start_count
  image = docker_image.main.name
  name  = "coder-${data.coder_workspace_owner.me.name}-${data.coder_workspace.me.name}"
  hostname = data.coder_workspace.me.name
  
  command = ["sh", "-c", coder_agent.main.init_script]
  
  env = [
    "CODER_AGENT_TOKEN=${coder_agent.main.token}",
  ]
  
  # Host Docker socket for container management
  volumes {
    host_path      = "/var/run/docker.sock"
    container_path = "/var/run/docker.sock"
  }
  
  # Persistent home directory
  volumes {
    volume_name    = docker_volume.home_volume.name
    container_path = "/home/${local.username}"
    read_only      = false
  }
  
  # Persistent project directory
  volumes {
    volume_name    = docker_volume.project_volume.name
    container_path = "/home/${local.username}/mediawiki-automation"
    read_only      = false
  }
  
  # Resources based on workspace size
  memory = local.memory_limit[data.coder_parameter.workspace_size.value]
  cpu_shares = tonumber(trim(local.cpu_limit[data.coder_parameter.workspace_size.value], "m"))
  
  # Add user to docker group
  group_add = ["999"] # docker group
}