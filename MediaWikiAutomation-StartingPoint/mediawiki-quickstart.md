# MediaWiki Automation - Quick Start in Coder

## 🚀 5-Minute Setup

### 1. Create Coder Workspace

```bash
# Using our template
coder create --template mediawiki-automation my-mediawiki-dev
```

Choose:
- Python: 3.11
- Kubernetes Tools: Yes  
- Size: Medium (4 CPU, 8GB RAM)

### 2. Access Workspace

```bash
coder ssh my-mediawiki-dev
```

### 3. Project is Auto-Created!

The workspace automatically:
- ✅ Creates project structure at `~/mediawiki-automation`
- ✅ Installs all Python packages
- ✅ Starts PostgreSQL on port 5432
- ✅ Starts Redis on port 6379
- ✅ Sets up VS Code and JupyterLab

### 4. Get the Implementation Code

Since you need the actual code from the 4 phase artifacts:

```bash
cd ~/mediawiki-automation

# Option A: If you have the artifacts as files
# Copy them to the workspace and extract

# Option B: Request from the original chat
# "Please provide the complete artifacts for:
#  - Phase 1: mediawiki-core
#  - Phase 2: mediawiki-web-app  
#  - Phase 3: mediawiki-content-processing
#  - Phase 4: mediawiki-production-deployment"
```

### 5. Quick Test (Without Full Code)

Even without the full implementation, you can test the environment:

```python
# Test database connection
cd ~/mediawiki-automation
python3 << EOF
import psycopg2
conn = psycopg2.connect(
    host="localhost",
    database="mediawiki_automation",
    user="mediawiki_user", 
    password="dev_password"
)
print("✅ Database connected!")
conn.close()
EOF

# Test Redis
python3 << EOF
import redis
r = redis.Redis(host='localhost', port=6379, db=0)
r.set('test', 'works')
print(f"✅ Redis working: {r.get('test').decode()}")
EOF

# Test FastAPI
cat > test_app.py << EOF
from fastapi import FastAPI
app = FastAPI()

@app.get("/")
def read_root():
    return {"status": "MediaWiki Automation Ready!"}
EOF

# Run it
uvicorn test_app:app --host 0.0.0.0 --port 8000 &

# Access via Coder dashboard → "MediaWiki Web App"
```

## 📁 What's In Your Workspace

```
~/mediawiki-automation/
├── extraction-script.sh     # Creates full structure
├── mediawiki_automation/    # Main application code (empty, needs artifacts)
│   ├── core/               # Core framework
│   ├── web/                # Web application  
│   ├── workers/            # Background workers
│   └── database/           # Database models
├── config/                 # Configuration files
├── content/                # Sample MediaWiki content
├── kubernetes/             # K8s deployment files
├── scripts/                # Utility scripts
├── tests/                  # Test suite
└── requirements/           # Python dependencies
```

## 🔥 Start Developing Now!

### 1. Use VS Code in Browser
- Open Coder dashboard
- Click "VS Code" 
- Full IDE with Python support ready!

### 2. Use JupyterLab
- Click "JupyterLab" in Coder dashboard
- Great for testing code snippets

### 3. Create a Simple MediaWiki Bot

```python
# In JupyterLab or VS Code
import pywikibot

# Configure your wiki (when you have credentials)
site = pywikibot.Site('en', 'wikipedia')  # Example
page = pywikibot.Page(site, 'Sandbox')
print(page.text)
```

### 4. Test Pandoc Conversion

```bash
# Markdown to MediaWiki
echo "# Hello World" | pandoc -f markdown -t mediawiki
# Output: = Hello World =
```

## ⚡ Services Status

Check everything is running:

```bash
# In your workspace
docker ps

# Should show:
# postgres-mediawiki
# redis-mediawiki
```

## 🎯 Next Steps

1. **Get Implementation Code**
   - Request the 4 artifacts from original chat
   - Place code in correct directories

2. **Configure Your MediaWiki**
   - Add your wiki URLs to config
   - Create bot accounts
   - Add credentials to `.env`

3. **Start the Full App**
   ```bash
   cd ~/mediawiki-automation
   ./scripts/start-dev.sh  # When you have full code
   ```

## 💡 Tips

- **Persistent Storage**: Your home directory persists between workspace restarts
- **Database Data**: PostgreSQL data persists in Docker volumes
- **Auto-save**: VS Code auto-saves your work
- **Collaboration**: Share your workspace URL for pair programming

## 🆘 Quick Fixes

```bash
# Restart PostgreSQL
docker restart postgres-mediawiki

# Restart Redis  
docker restart redis-mediawiki

# Check logs
docker logs postgres-mediawiki
docker logs redis-mediawiki

# Reinstall packages
pip install -r requirements/dev.txt
```

**Your MediaWiki Automation development environment is ready! 🚀**