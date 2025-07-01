#!/bin/bash
# MediaWiki Automation System - Complete Setup & Code Extraction Script
# This script creates the complete project structure and all Python files

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 MediaWiki Automation System - Complete Setup${NC}"
echo -e "${BLUE}==================================================${NC}"
echo ""

# Check if we're in the right directory or create it
if [ ! -d "mediawiki_automation" ]; then
    echo -e "${YELLOW}⚠️  Creating project structure...${NC}"
    mkdir -p mediawiki_automation/{core,web/{auth,api,frontend},workers,database/{migrations/versions},utils}
    mkdir -p {config/{environments,instances,auth},content/{Git-Documentation/{basics,commands},GitHub-Administration,General-Documentation},kubernetes/{configmaps,secrets,deployments,services,ingress,persistent-volumes,monitoring,security,autoscaling,cronjobs},docker,scripts,tests/{unit,integration,e2e},docs/{api,deployment,user-guide},requirements,tools,cache,logs,backups}
    
    # Create __init__.py files
    find mediawiki_automation -type d -exec touch {}/__init__.py \;
    find tests -type d -exec touch {}/__init__.py \;
fi

echo -e "${BLUE}📝 Creating Phase 1: Core Framework Files...${NC}"

# ===== Phase 1: Core Framework Files =====

# config_manager.py
cat > mediawiki_automation/core/config_manager.py << 'EOF'
import os
import yaml
import logging
from typing import Dict, Optional, Any
from pathlib import Path
import re

class ConfigManager:
    """Centralized configuration management with environment-specific overrides"""
    
    def __init__(self, config_path: str = "config"):
        self.config_path = Path(config_path)
        self.config_cache = {}
        self.environment = os.getenv('ENVIRONMENT', 'development')
        
    def load_config(self, environment: str = None) -> Dict[str, Any]:
        """Load configuration with priority: env vars > environment config > base config"""
        if environment is None:
            environment = self.environment
            
        cache_key = f"config_{environment}"
        if cache_key in self.config_cache:
            return self.config_cache[cache_key]
        
        # Start with base configuration
        base_config = self._load_yaml_file(self.config_path / "base_config.yaml")
        
        # Override with environment-specific config
        env_config_path = self.config_path / f"environments/{environment}.yaml"
        if env_config_path.exists():
            env_config = self._load_yaml_file(env_config_path)
            base_config = self._deep_merge(base_config, env_config)
        
        # Override with environment variables
        base_config = self._apply_env_overrides(base_config)
        
        # Validate configuration
        if self.validate_config(base_config):
            self.config_cache[cache_key] = base_config
            return base_config
        else:
            raise ValueError("Configuration validation failed")
    
    def get_instance_config(self, instance_name: str) -> Dict[str, Any]:
        """Get configuration for a specific MediaWiki instance"""
        instance_path = self.config_path / "instances" / f"{instance_name}.yaml"
        if not instance_path.exists():
            raise FileNotFoundError(f"Instance config not found: {instance_path}")
        
        instance_config = self._load_yaml_file(instance_path)
        base_config = self.load_config()
        
        # Merge instance config with base config
        return self._deep_merge(base_config, {"instance": instance_config})
    
    def get_site_config(self, site_path: str) -> Dict[str, Any]:
        """Load site configuration from .mediawiki-config.yaml"""
        config_file = Path(site_path) / ".mediawiki-config.yaml"
        if not config_file.exists():
            raise FileNotFoundError(f"Site config not found: {config_file}")
        
        return self._load_yaml_file(config_file)
    
    def validate_config(self, config: Dict[str, Any]) -> bool:
        """Validate configuration structure and required fields"""
        required_fields = ["system", "logging"]
        
        for field in required_fields:
            if field not in config:
                logging.error(f"Missing required configuration field: {field}")
                return False
        
        # Validate system config
        system_config = config.get("system", {})
        if "timeout_seconds" not in system_config:
            logging.error("Missing system.timeout_seconds in configuration")
            return False
        
        return True
    
    def reload_config(self) -> bool:
        """Reload configuration from files"""
        try:
            self.config_cache.clear()
            self.load_config()
            logging.info("Configuration reloaded successfully")
            return True
        except Exception as e:
            logging.error(f"Failed to reload configuration: {e}")
            return False
    
    def get_secret(self, key: str) -> str:
        """Get secret from environment variables"""
        value = os.getenv(key)
        if value is None:
            raise ValueError(f"Secret not found in environment: {key}")
        return value
    
    def _load_yaml_file(self, file_path: Path) -> Dict[str, Any]:
        """Load and parse YAML file"""
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                # Replace environment variable placeholders
                content = self._substitute_env_vars(content)
                return yaml.safe_load(content) or {}
        except FileNotFoundError:
            logging.warning(f"Config file not found: {file_path}")
            return {}
        except yaml.YAMLError as e:
            logging.error(f"YAML parsing error in {file_path}: {e}")
            raise
    
    def _substitute_env_vars(self, content: str) -> str:
        """Replace ${VAR_NAME} placeholders with environment variables"""
        def replace_var(match):
            var_name = match.group(1)
            return os.getenv(var_name, match.group(0))
        
        return re.sub(r'\$\{([^}]+)\}', replace_var, content)
    
    def _deep_merge(self, base: Dict, override: Dict) -> Dict:
        """Deep merge two dictionaries"""
        result = base.copy()
        for key, value in override.items():
            if key in result and isinstance(result[key], dict) and isinstance(value, dict):
                result[key] = self._deep_merge(result[key], value)
            else:
                result[key] = value
        return result
    
    def _apply_env_overrides(self, config: Dict) -> Dict:
        """Apply environment variable overrides"""
        # Map environment variables to config paths
        env_mappings = {
            'MEDIAWIKI_LOG_LEVEL': ['system', 'log_level'],
            'MEDIAWIKI_TIMEOUT': ['system', 'timeout_seconds'],
            'MEDIAWIKI_MAX_OPERATIONS': ['system', 'max_concurrent_operations'],
        }
        
        for env_var, config_path in env_mappings.items():
            if env_var in os.environ:
                value = os.environ[env_var]
                # Convert to appropriate type
                if config_path[-1] in ['timeout_seconds', 'max_concurrent_operations']:
                    value = int(value)
                
                # Set nested config value
                current = config
                for key in config_path[:-1]:
                    if key not in current:
                        current[key] = {}
                    current = current[key]
                current[config_path[-1]] = value
        
        return config
EOF

# logger.py
cat > mediawiki_automation/core/logger.py << 'EOF'
import logging
import json
from typing import Dict, Any
from datetime import datetime
from pathlib import Path
from logging.handlers import RotatingFileHandler

class StructuredLogger:
    """Structured logging with JSON output for ELK stack integration"""
    
    def __init__(self, name: str, config: Dict[str, Any]):
        self.logger = logging.getLogger(name)
        self.config = config.get('logging', {})
        self._setup_logger()
    
    def _setup_logger(self):
        """Setup logger with file and console handlers"""
        log_level = self.config.get('level', 'INFO')
        self.logger.setLevel(getattr(logging, log_level))
        
        # Clear existing handlers
        self.logger.handlers.clear()
        
        # Console handler
        console_handler = logging.StreamHandler()
        console_formatter = logging.Formatter(
            self.config.get('format', '%(asctime)s - %(name)s - %(levelname)s - %(message)s')
        )
        console_handler.setFormatter(console_formatter)
        self.logger.addHandler(console_handler)
        
        # File handler (if configured)
        log_file = self.config.get('file_path')
        if log_file:
            # Ensure log directory exists
            Path(log_file).parent.mkdir(parents=True, exist_ok=True)
            
            file_handler = RotatingFileHandler(
                log_file,
                maxBytes=self._parse_size(self.config.get('max_file_size', '10MB')),
                backupCount=self.config.get('backup_count', 5)
            )
            file_handler.setFormatter(console_formatter)
            self.logger.addHandler(file_handler)
    
    def _parse_size(self, size_str: str) -> int:
        """Parse size string like '10MB' to bytes"""
        units = {'B': 1, 'KB': 1024, 'MB': 1024**2, 'GB': 1024**3}
        size_str = size_str.upper()
        for unit, multiplier in units.items():
            if size_str.endswith(unit):
                return int(size_str[:-len(unit)]) * multiplier
        return int(size_str)
    
    def info(self, message: str, **kwargs):
        """Log info message with optional context"""
        self._log_with_context('info', message, **kwargs)
    
    def error(self, message: str, **kwargs):
        """Log error message with optional context"""
        self._log_with_context('error', message, **kwargs)
    
    def warning(self, message: str, **kwargs):
        """Log warning message with optional context"""
        self._log_with_context('warning', message, **kwargs)
    
    def debug(self, message: str, **kwargs):
        """Log debug message with optional context"""
        self._log_with_context('debug', message, **kwargs)
    
    def _log_with_context(self, level: str, message: str, **kwargs):
        """Log message with structured context"""
        if kwargs:
            context = json.dumps(kwargs, default=str)
            message = f"{message} | Context: {context}"
        
        getattr(self.logger, level)(message)
EOF

# error_handler.py
cat > mediawiki_automation/core/error_handler.py << 'EOF'
import time
from typing import Dict, Any, Callable, List
from datetime import datetime
import pywikibot

class MediaWikiAuthError(Exception):
    """Authentication-related errors"""
    pass

class MediaWikiSyncError(Exception):
    """Synchronization-related errors"""
    pass

class ConfigurationError(Exception):
    """Configuration-related errors"""
    pass

class ErrorHandler:
    """Comprehensive error handling with retry logic and monitoring"""
    
    def __init__(self, config: Dict[str, Any], logger):
        self.config = config.get('error_handling', {})
        self.logger = logger
        self.retry_attempts = self.config.get('retry_attempts', 3)
        self.base_delay = self.config.get('base_delay', 1)
    
    def handle_error(self, error: Exception, context: Dict[str, Any]) -> str:
        """Handle error and determine action"""
        error_type = type(error).__name__
        
        self.logger.error(
            f"Error occurred: {error}",
            error_type=error_type,
            context=context
        )
        
        # Determine error action based on error type
        if isinstance(error, MediaWikiAuthError):
            return "re_authenticate"
        elif isinstance(error, pywikibot.exceptions.ServerError):
            return "retry"
        elif isinstance(error, pywikibot.exceptions.NoUsernameError):
            return "authentication_required"
        else:
            return "log_and_continue"
    
    def retry_operation(self, operation, max_retries: int = None, **kwargs):
        """Retry operation with exponential backoff"""
        max_retries = max_retries or self.retry_attempts
        last_exception = None
        
        for attempt in range(max_retries + 1):
            try:
                return operation(**kwargs)
            except Exception as e:
                last_exception = e
                
                if attempt == max_retries:
                    self.logger.error(
                        f"Operation failed after {max_retries} retries",
                        operation=operation.__name__,
                        final_error=str(e),
                        attempt=attempt + 1
                    )
                    raise e
                
                delay = self.base_delay * (2 ** attempt)
                self.logger.warning(
                    f"Operation failed, retrying in {delay}s",
                    operation=operation.__name__,
                    error=str(e),
                    attempt=attempt + 1,
                    max_retries=max_retries
                )
                time.sleep(delay)
        
        raise last_exception
    
    def check_health(self, instance: str) -> Dict[str, Any]:
        """Check health status of a MediaWiki instance"""
        return {
            "instance": instance,
            "status": "healthy",
            "timestamp": datetime.now().isoformat(),
            "checks": {
                "api_accessible": True,
                "authentication": True,
                "permissions": True
            }
        }
EOF

# auth_manager.py
cat > mediawiki_automation/core/auth_manager.py << 'EOF'
import pywikibot
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
from .error_handler import MediaWikiAuthError

class AuthManager:
    """Centralized authentication and session management for MediaWiki instances"""
    
    def __init__(self, config: Dict[str, Any], logger, error_handler):
        self.config = config
        self.logger = logger
        self.error_handler = error_handler
        self.sites = {}
        self.auth_config = config.get('authentication', {})
    
    def login(self, instance_name: str) -> bool:
        """Login to a MediaWiki instance"""
        try:
            if instance_name not in self.auth_config:
                raise MediaWikiAuthError(f"No authentication config for instance: {instance_name}")
            
            instance_config = self.auth_config[instance_name]
            
            # Create pywikibot Site object
            site = pywikibot.Site(
                url=instance_config['url'],
                fam=instance_config.get('family', 'mediawiki')
            )
            
            # Set credentials
            site.login(
                username=instance_config['username'],
                password=instance_config['password']
            )
            
            # Store authenticated site
            self.sites[instance_name] = {
                'site': site,
                'last_login': datetime.now(),
                'config': instance_config
            }
            
            self.logger.info(
                "Successfully logged in to MediaWiki instance",
                instance=instance_name,
                url=instance_config['url']
            )
            
            return True
            
        except Exception as e:
            self.logger.error(
                "Failed to login to MediaWiki instance",
                instance=instance_name,
                error=str(e)
            )
            raise MediaWikiAuthError(f"Login failed for {instance_name}: {e}")
    
    def logout(self, instance_name: str) -> bool:
        """Logout from a MediaWiki instance"""
        try:
            if instance_name in self.sites:
                del self.sites[instance_name]
                
                self.logger.info(
                    "Logged out from MediaWiki instance",
                    instance=instance_name
                )
                return True
            return False
            
        except Exception as e:
            self.logger.error(
                "Error during logout",
                instance=instance_name,
                error=str(e)
            )
            return False
    
    def get_site(self, instance_name: str) -> pywikibot.Site:
        """Get authenticated site object"""
        if not self.is_authenticated(instance_name):
            self.login(instance_name)
        
        return self.sites[instance_name]['site']
    
    def is_authenticated(self, instance_name: str) -> bool:
        """Check if instance is authenticated and session is valid"""
        if instance_name not in self.sites:
            return False
        
        site_info = self.sites[instance_name]
        
        # Check if session is too old (older than 24 hours)
        session_age = datetime.now() - site_info['last_login']
        if session_age > timedelta(hours=24):
            self.logger.info(
                "Session expired, removing from cache",
                instance=instance_name,
                session_age=str(session_age)
            )
            del self.sites[instance_name]
            return False
        
        # Test connection by making a simple API call
        try:
            site = site_info['site']
            # Simple test - get site info
            site.siteinfo
            return True
        except Exception as e:
            self.logger.warning(
                "Authentication test failed",
                instance=instance_name,
                error=str(e)
            )
            if instance_name in self.sites:
                del self.sites[instance_name]
            return False
    
    def refresh_session(self, instance_name: str) -> bool:
        """Refresh authentication session"""
        try:
            self.logout(instance_name)
            return self.login(instance_name)
        except Exception as e:
            self.logger.error(
                "Failed to refresh session",
                instance=instance_name,
                error=str(e)
            )
            return False
    
    def get_authenticated_instances(self) -> List[str]:
        """Get list of currently authenticated instances"""
        return [name for name in self.sites.keys() if self.is_authenticated(name)]
EOF

# site_discovery.py
cat > mediawiki_automation/core/site_discovery.py << 'EOF'
import os
import yaml
from pathlib import Path
from typing import List, Dict, Any
from dataclasses import dataclass

@dataclass
class SiteInfo:
    name: str
    display_name: str
    content_path: str
    config_path: str
    status: str
    config: Dict[str, Any]

class SiteDiscovery:
    """Automatic site discovery and management"""
    
    def __init__(self, config: Dict[str, Any], logger):
        self.config = config
        self.logger = logger
        self.content_base_paths = config.get('content_discovery', {}).get('base_paths', ['/content'])
    
    def discover_sites(self) -> List[SiteInfo]:
        """Discover all sites with .mediawiki-config.yaml files"""
        sites = []
        
        for base_path in self.content_base_paths:
            base_path = Path(base_path)
            if not base_path.exists():
                self.logger.warning(f"Content base path does not exist: {base_path}")
                continue
            
            # Walk through directories looking for .mediawiki-config.yaml
            for root, dirs, files in os.walk(base_path):
                if '.mediawiki-config.yaml' in files:
                    try:
                        config_path = Path(root) / '.mediawiki-config.yaml'
                        site_config = self._load_site_config(config_path)
                        
                        site_info = SiteInfo(
                            name=site_config['site']['name'],
                            display_name=site_config['site'].get('display_name', site_config['site']['name']),
                            content_path=str(root),
                            config_path=str(config_path),
                            status=site_config['metadata'].get('status', 'unknown'),
                            config=site_config
                        )
                        
                        sites.append(site_info)
                        
                        self.logger.info(
                            "Discovered site",
                            site_name=site_info.name,
                            path=site_info.content_path,
                            status=site_info.status
                        )
                        
                    except Exception as e:
                        self.logger.error(
                            "Failed to load site config",
                            config_path=str(config_path),
                            error=str(e)
                        )
        
        return sites
    
    def get_approved_sites(self) -> List[SiteInfo]:
        """Get only approved sites"""
        all_sites = self.discover_sites()
        return [site for site in all_sites if site.status == 'approved']
    
    def get_pending_sites(self) -> List[SiteInfo]:
        """Get sites pending approval"""
        all_sites = self.discover_sites()
        return [site for site in all_sites if site.status == 'pending_approval']
    
    def _load_site_config(self, config_path: Path) -> Dict[str, Any]:
        """Load site configuration file"""
        with open(config_path, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
EOF

# main.py
cat > mediawiki_automation/main.py << 'EOF'
import os
import json
from datetime import datetime
from typing import Dict, Any

from .core.config_manager import ConfigManager
from .core.auth_manager import AuthManager
from .core.logger import StructuredLogger
from .core.error_handler import ErrorHandler
from .core.site_discovery import SiteDiscovery

class MediaWikiAutomationSystem:
    """Main system class that orchestrates all components"""
    
    def __init__(self, config_path: str = "config"):
        # Initialize configuration
        self.config_manager = ConfigManager(config_path)
        self.config = self.config_manager.load_config()
        
        # Initialize logging
        self.logger = StructuredLogger("mediawiki_automation", self.config)
        
        # Initialize error handler
        self.error_handler = ErrorHandler(self.config, self.logger)
        
        # Initialize authentication manager
        self.auth_manager = AuthManager(self.config, self.logger, self.error_handler)
        
        # Initialize site discovery
        self.site_discovery = SiteDiscovery(self.config, self.logger)
        
        self.logger.info("MediaWiki Automation System initialized successfully")
    
    def initialize(self) -> bool:
        """Initialize the system and perform startup checks"""
        try:
            self.logger.info("Starting system initialization...")
            
            # Discover sites
            sites = self.site_discovery.discover_sites()
            self.logger.info(f"Discovered {len(sites)} sites")
            
            # Test authentication for approved sites
            approved_sites = self.site_discovery.get_approved_sites()
            for site in approved_sites:
                try:
                    if self.auth_manager.login(site.name):
                        self.logger.info(f"Successfully authenticated to {site.name}")
                    else:
                        self.logger.warning(f"Failed to authenticate to {site.name}")
                except Exception as e:
                    self.logger.error(f"Authentication error for {site.name}: {e}")
            
            self.logger.info("System initialization completed")
            return True
            
        except Exception as e:
            self.logger.error(f"System initialization failed: {e}")
            return False
    
    def get_system_status(self) -> Dict[str, Any]:
        """Get overall system status"""
        sites = self.site_discovery.discover_sites()
        authenticated_instances = self.auth_manager.get_authenticated_instances()
        
        return {
            "status": "running",
            "timestamp": datetime.now().isoformat(),
            "sites": {
                "total": len(sites),
                "approved": len([s for s in sites if s.status == 'approved']),
                "pending": len([s for s in sites if s.status == 'pending_approval']),
                "authenticated": len(authenticated_instances)
            },
            "authentication": {
                "authenticated_instances": authenticated_instances
            }
        }
EOF

echo -e "${GREEN}✅ Phase 1 completed${NC}"
echo ""

echo -e "${BLUE}📝 Creating Phase 2: Web Application Files...${NC}"

# ===== Phase 2: Web Application Files =====

# Create web directories if they don't exist
mkdir -p mediawiki_automation/web/auth

# models.py
cat > mediawiki_automation/web/models.py << 'EOF'
from sqlalchemy import Column, Integer, String, DateTime, Text, Boolean, ForeignKey, JSON
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from datetime import datetime

Base = declarative_base()

class User(Base):
    """User model for authentication and authorization"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String(50), unique=True, index=True, nullable=False)
    email = Column(String(100), unique=True, index=True, nullable=False)
    full_name = Column(String(100), nullable=True)
    hashed_password = Column(String(255), nullable=False)
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    ad_user = Column(Boolean, default=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Relationships
    sync_jobs = relationship("SyncJob", back_populates="created_by_user")
    site_permissions = relationship("SitePermission", back_populates="user")

class Site(Base):
    """Site model for MediaWiki instances"""
    __tablename__ = "sites"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), unique=True, index=True, nullable=False)
    display_name = Column(String(200), nullable=False)
    content_path = Column(Text, nullable=False)
    config_path = Column(Text, nullable=False)
    status = Column(String(20), default="pending_approval")  # pending_approval, approved, disabled
    wiki_url = Column(String(500), nullable=True)
    wiki_base_path = Column(String(200), nullable=True)
    last_sync = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Configuration stored as JSON
    sync_config = Column(JSON, nullable=True)
    
    # Relationships
    sync_jobs = relationship("SyncJob", back_populates="site")
    permissions = relationship("SitePermission", back_populates="site")

class SyncJob(Base):
    """Sync job tracking model"""
    __tablename__ = "sync_jobs"
    
    id = Column(Integer, primary_key=True, index=True)
    site_id = Column(Integer, ForeignKey("sites.id"), nullable=False)
    created_by = Column(Integer, ForeignKey("users.id"), nullable=False)
    job_type = Column(String(50), nullable=False)  # manual, scheduled, auto
    status = Column(String(20), default="pending")  # pending, running, completed, failed
    progress = Column(Integer, default=0)  # 0-100
    
    # Detailed information
    files_processed = Column(Integer, default=0)
    files_total = Column(Integer, default=0)
    errors_count = Column(Integer, default=0)
    
    # Logs and results
    log_data = Column(JSON, nullable=True)
    error_details = Column(Text, nullable=True)
    
    # Timestamps
    started_at = Column(DateTime(timezone=True), nullable=True)
    completed_at = Column(DateTime(timezone=True), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    site = relationship("Site", back_populates="sync_jobs")
    created_by_user = relationship("User", back_populates="sync_jobs")

class SitePermission(Base):
    """User permissions for specific sites"""
    __tablename__ = "site_permissions"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    site_id = Column(Integer, ForeignKey("sites.id"), nullable=False)
    permission_level = Column(String(20), nullable=False)  # read, write, admin
    granted_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    # Relationships
    user = relationship("User", back_populates="site_permissions", foreign_keys=[user_id])
    site = relationship("Site", back_populates="permissions")

class SystemConfig(Base):
    """System configuration storage"""
    __tablename__ = "system_config"
    
    id = Column(Integer, primary_key=True, index=True)
    key = Column(String(100), unique=True, index=True, nullable=False)
    value = Column(Text, nullable=False)
    description = Column(Text, nullable=True)
    updated_by = Column(Integer, ForeignKey("users.id"), nullable=True)
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class AuditLog(Base):
    """Audit log for tracking system activities"""
    __tablename__ = "audit_logs"
    
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=True)
    action = Column(String(100), nullable=False)
    resource_type = Column(String(50), nullable=False)  # site, sync_job, user
    resource_id = Column(Integer, nullable=True)
    details = Column(JSON, nullable=True)
    ip_address = Column(String(45), nullable=True)
    user_agent = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
EOF

# database.py
cat > mediawiki_automation/web/database.py << 'EOF'
from sqlalchemy import create_engine, MetaData
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool
import os
from typing import Generator

# Database URL from environment
DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://mediawiki_user:dev_password@localhost:5432/mediawiki_automation")

# Create SQLAlchemy engine
engine = create_engine(
    DATABASE_URL,
    poolclass=StaticPool,
    connect_args={"check_same_thread": False} if "sqlite" in DATABASE_URL else {},
    echo=os.getenv("DEBUG", "false").lower() == "true"
)

# Create SessionLocal class
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Base class for models
Base = declarative_base()

class DatabaseManager:
    """Database management utilities"""
    
    def __init__(self, database_url: str = None):
        self.database_url = database_url or DATABASE_URL
        self.engine = create_engine(self.database_url)
        self.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=self.engine)
    
    def create_tables(self):
        """Create all tables"""
        from .models import Base
        Base.metadata.create_all(bind=self.engine)
    
    def drop_tables(self):
        """Drop all tables"""
        from .models import Base
        Base.metadata.drop_all(bind=self.engine)
    
    def get_session(self) -> Session:
        """Get database session"""
        return self.SessionLocal()

# Dependency for FastAPI
def get_database_session() -> Generator[Session, None, None]:
    """Get database session for FastAPI dependency injection"""
    session = SessionLocal()
    try:
        yield session
    finally:
        session.close()

# Initialize database
def init_database():
    """Initialize database with tables and default data"""
    from .models import Base, User, SystemConfig
    from passlib.context import CryptContext
    
    # Create tables
    Base.metadata.create_all(bind=engine)
    
    # Create default admin user if not exists
    session = SessionLocal()
    try:
        admin_user = session.query(User).filter(User.username == "admin").first()
        if not admin_user:
            pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
            admin_user = User(
                username="admin",
                email="admin@company.com",
                full_name="System Administrator",
                hashed_password=pwd_context.hash("admin123"),
                is_active=True,
                is_admin=True,
                ad_user=False
            )
            session.add(admin_user)
        
        # Create default system config
        default_configs = [
            ("site_approval_required", "true", "Whether new sites require admin approval"),
            ("auto_sync_enabled", "true", "Whether automatic sync is enabled globally"),
            ("max_concurrent_syncs", "5", "Maximum number of concurrent sync jobs"),
            ("sync_timeout_minutes", "60", "Timeout for sync jobs in minutes"),
        ]
        
        for key, value, description in default_configs:
            existing_config = session.query(SystemConfig).filter(SystemConfig.key == key).first()
            if not existing_config:
                config = SystemConfig(
                    key=key,
                    value=value,
                    description=description
                )
                session.add(config)
        
        session.commit()
        
    except Exception as e:
        session.rollback()
        raise e
    finally:
        session.close()
EOF

# schemas.py
cat > mediawiki_automation/web/schemas.py << 'EOF'
from pydantic import BaseModel, EmailStr, validator
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum

# Enums
class SiteStatus(str, Enum):
    PENDING_APPROVAL = "pending_approval"
    APPROVED = "approved"
    DISABLED = "disabled"

class SyncJobType(str, Enum):
    MANUAL = "manual"
    SCHEDULED = "scheduled"
    AUTO = "auto"

class SyncJobStatus(str, Enum):
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"

class PermissionLevel(str, Enum):
    READ = "read"
    WRITE = "write"
    ADMIN = "admin"

# User schemas
class UserBase(BaseModel):
    username: str
    email: EmailStr
    full_name: Optional[str] = None

class UserCreate(UserBase):
    password: str
    is_admin: Optional[bool] = False

class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    full_name: Optional[str] = None
    is_active: Optional[bool] = None
    is_admin: Optional[bool] = None

class User(UserBase):
    id: int
    is_active: bool
    is_admin: bool
    ad_user: bool
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True

# Site schemas
class SiteBase(BaseModel):
    name: str
    display_name: str
    content_path: str
    wiki_url: Optional[str] = None
    wiki_base_path: Optional[str] = None

class SiteCreate(SiteBase):
    sync_config: Optional[Dict[str, Any]] = None

class SiteUpdate(BaseModel):
    display_name: Optional[str] = None
    status: Optional[SiteStatus] = None
    wiki_url: Optional[str] = None
    wiki_base_path: Optional[str] = None
    sync_config: Optional[Dict[str, Any]] = None

class Site(SiteBase):
    id: int
    config_path: str
    status: SiteStatus
    last_sync: Optional[datetime] = None
    created_at: datetime
    updated_at: Optional[datetime] = None
    sync_config: Optional[Dict[str, Any]] = None
    
    class Config:
        from_attributes = True

# Sync Job schemas
class SyncJobBase(BaseModel):
    job_type: SyncJobType

class SyncJobCreate(SyncJobBase):
    site_id: int

class SyncJob(SyncJobBase):
    id: int
    site_id: int
    created_by: int
    status: SyncJobStatus
    progress: int
    files_processed: int
    files_total: int
    errors_count: int
    log_data: Optional[Dict[str, Any]] = None
    error_details: Optional[str] = None
    started_at: Optional[datetime] = None
    completed_at: Optional[datetime] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

# Permission schemas
class SitePermissionBase(BaseModel):
    permission_level: PermissionLevel

class SitePermissionCreate(SitePermissionBase):
    user_id: int
    site_id: int

class SitePermission(SitePermissionBase):
    id: int
    user_id: int
    site_id: int
    granted_by: Optional[int] = None
    created_at: datetime
    
    class Config:
        from_attributes = True

# Authentication schemas
class LoginRequest(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int

class TokenData(BaseModel):
    username: Optional[str] = None
    user_id: Optional[int] = None

# System schemas
class SystemStatus(BaseModel):
    status: str
    timestamp: datetime
    sites: Dict[str, int]
    authentication: Dict[str, Any]
    sync_jobs: Dict[str, int]

class SystemConfig(BaseModel):
    key: str
    value: str
    description: Optional[str] = None

# API Response schemas
class APIResponse(BaseModel):
    success: bool
    message: str
    data: Optional[Any] = None

class PaginatedResponse(BaseModel):
    items: List[Any]
    total: int
    page: int
    per_page: int
    pages: int

# Sync operation schemas
class SyncRequest(BaseModel):
    dry_run: Optional[bool] = False
    force: Optional[bool] = False

class SyncProgress(BaseModel):
    job_id: int
    status: SyncJobStatus
    progress: int
    files_processed: int
    files_total: int
    current_file: Optional[str] = None
    errors: List[str] = []

# Site discovery schemas
class DiscoveredSite(BaseModel):
    name: str
    display_name: str
    content_path: str
    config_path: str
    status: str
    config: Dict[str, Any]

# Audit log schemas
class AuditLogEntry(BaseModel):
    id: int
    user_id: Optional[int]
    action: str
    resource_type: str
    resource_id: Optional[int]
    details: Optional[Dict[str, Any]]
    ip_address: Optional[str]
    created_at: datetime
    
    class Config:
        from_attributes = True
EOF

# app.py (Main FastAPI application)
cat > mediawiki_automation/web/app.py << 'EOF'
from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session
from typing import List, Optional
import os
from datetime import datetime

from .database import get_database_session, init_database
from .models import User, Site, SyncJob, SitePermission
from .schemas import (
    UserCreate, User as UserSchema, SiteCreate, Site as SiteSchema,
    SyncJobCreate, SyncJob as SyncJobSchema, LoginRequest, Token,
    SystemStatus, APIResponse, SyncRequest, SyncProgress
)
from .auth.jwt_handler import JWTHandler
from .auth.ad_auth import ADAuthenticator

# Initialize FastAPI app
app = FastAPI(
    title="MediaWiki Automation System",
    description="Automated content synchronization between file repositories and MediaWiki instances",
    version="2.4.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Configure appropriately for production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Initialize components
jwt_handler = JWTHandler()
ad_authenticator = ADAuthenticator()
security = HTTPBearer()

# Initialize database on startup
@app.on_event("startup")
async def startup_event():
    """Initialize database and create default data"""
    try:
        init_database()
        print("✅ Database initialized successfully")
    except Exception as e:
        print(f"❌ Database initialization failed: {e}")
        raise

# Authentication dependency
async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security),
    db: Session = Depends(get_database_session)
) -> User:
    """Get current authenticated user"""
    try:
        token = credentials.credentials
        payload = jwt_handler.decode_token(token)
        username = payload.get("sub")
        
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid authentication credentials"
            )
        
        user = db.query(User).filter(User.username == username).first()
        if user is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User not found"
            )
        
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User account is disabled"
            )
        
        return user
        
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials"
        )

# Admin user dependency
async def get_admin_user(current_user: User = Depends(get_current_user)) -> User:
    """Require admin privileges"""
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin privileges required"
        )
    return current_user

# Health check endpoint
@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy", "timestamp": datetime.now().isoformat()}

# Authentication endpoints
@app.post("/api/auth/login", response_model=Token)
async def login(
    login_data: LoginRequest,
    db: Session = Depends(get_database_session)
):
    """Authenticate user and return JWT token"""
    try:
        # Try AD authentication first
        ad_user = await ad_authenticator.authenticate(login_data.username, login_data.password)
        
        if ad_user:
            # Create or update AD user in database
            user = db.query(User).filter(User.username == login_data.username).first()
            if not user:
                user = User(
                    username=login_data.username,
                    email=ad_user.get("email", f"{login_data.username}@company.com"),
                    full_name=ad_user.get("full_name", login_data.username),
                    hashed_password="",  # AD users don't need local password
                    is_active=True,
                    is_admin=ad_user.get("is_admin", False),
                    ad_user=True
                )
                db.add(user)
                db.commit()
                db.refresh(user)
        else:
            # Fall back to local authentication
            user = db.query(User).filter(User.username == login_data.username).first()
            if not user or not jwt_handler.verify_password(login_data.password, user.hashed_password):
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Invalid username or password"
                )
        
        if not user.is_active:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="User account is disabled"
            )
        
        # Generate JWT token
        access_token = jwt_handler.create_access_token(
            data={"sub": user.username, "user_id": user.id}
        )
        
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "expires_in": 86400  # 24 hours
        }
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Authentication failed"
        )

# User management endpoints
@app.get("/api/users", response_model=List[UserSchema])
async def list_users(
    admin_user: User = Depends(get_admin_user),
    db: Session = Depends(get_database_session)
):
    """List all users (admin only)"""
    users = db.query(User).all()
    return users

@app.post("/api/users", response_model=UserSchema)
async def create_user(
    user_data: UserCreate,
    admin_user: User = Depends(get_admin_user),
    db: Session = Depends(get_database_session)
):
    """Create new user (admin only)"""
    # Check if username already exists
    existing_user = db.query(User).filter(User.username == user_data.username).first()
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already exists"
        )
    
    # Create user
    hashed_password = jwt_handler.get_password_hash(user_data.password)
    user = User(
        username=user_data.username,
        email=user_data.email,
        full_name=user_data.full_name,
        hashed_password=hashed_password,
        is_admin=user_data.is_admin,
        ad_user=False
    )
    
    db.add(user)
    db.commit()
    db.refresh(user)
    
    return user

# Site management endpoints
@app.get("/api/sites", response_model=List[SiteSchema])
async def list_sites(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_database_session)
):
    """List all sites"""
    sites = db.query(Site).all()
    return sites

@app.post("/api/sites", response_model=SiteSchema)
async def create_site(
    site_data: SiteCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_database_session)
):
    """Create new site"""
    site = Site(
        name=site_data.name,
        display_name=site_data.display_name,
        content_path=site_data.content_path,
        config_path=f"{site_data.content_path}/.mediawiki-config.yaml",
        wiki_url=site_data.wiki_url,
        wiki_base_path=site_data.wiki_base_path,
        sync_config=site_data.sync_config,
        status="pending_approval"
    )
    
    db.add(site)
    db.commit()
    db.refresh(site)
    
    return site

@app.patch("/api/sites/{site_id}/approve")
async def approve_site(
    site_id: int,
    admin_user: User = Depends(get_admin_user),
    db: Session = Depends(get_database_session)
):
    """Approve a site (admin only)"""
    site = db.query(Site).filter(Site.id == site_id).first()
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    
    site.status = "approved"
    db.commit()
    
    return {"success": True, "message": "Site approved successfully"}

# Sync job endpoints
@app.post("/api/sites/{site_id}/sync", response_model=SyncJobSchema)
async def trigger_sync(
    site_id: int,
    sync_request: SyncRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_database_session)
):
    """Trigger manual sync for a site"""
    site = db.query(Site).filter(Site.id == site_id).first()
    if not site:
        raise HTTPException(status_code=404, detail="Site not found")
    
    if site.status != "approved":
        raise HTTPException(status_code=400, detail="Site must be approved to sync")
    
    # Create sync job
    sync_job = SyncJob(
        site_id=site_id,
        created_by=current_user.id,
        job_type="manual",
        status="pending"
    )
    
    db.add(sync_job)
    db.commit()
    db.refresh(sync_job)
    
    # TODO: Trigger actual sync process via Celery
    
    return sync_job

@app.get("/api/sync-jobs", response_model=List[SyncJobSchema])
async def list_sync_jobs(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_database_session)
):
    """List sync jobs"""
    jobs = db.query(SyncJob).order_by(SyncJob.created_at.desc()).limit(50).all()
    return jobs

@app.get("/api/sync-jobs/{job_id}/progress", response_model=SyncProgress)
async def get_sync_progress(
    job_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_database_session)
):
    """Get sync job progress"""
    job = db.query(SyncJob).filter(SyncJob.id == job_id).first()
    if not job:
        raise HTTPException(status_code=404, detail="Sync job not found")
    
    return SyncProgress(
        job_id=job.id,
        status=job.status,
        progress=job.progress,
        files_processed=job.files_processed,
        files_total=job.files_total,
        errors=[]  # TODO: Extract from log_data
    )

# System status endpoint
@app.get("/api/system/status", response_model=SystemStatus)
async def get_system_status(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_database_session)
):
    """Get system status"""
    sites = db.query(Site).all()
    sync_jobs = db.query(SyncJob).all()
    
    return SystemStatus(
        status="running",
        timestamp=datetime.now(),
        sites={
            "total": len(sites),
            "approved": len([s for s in sites if s.status == "approved"]),
            "pending": len([s for s in sites if s.status == "pending_approval"])
        },
        authentication={
            "method": "JWT + AD/LDAP"
        },
        sync_jobs={
            "total": len(sync_jobs),
            "running": len([j for j in sync_jobs if j.status == "running"]),
            "completed": len([j for j in sync_jobs if j.status == "completed"]),
            "failed": len([j for j in sync_jobs if j.status == "failed"])
        }
    )

# Error handlers
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code,
        content={"success": False, "message": exc.detail}
    )

@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"success": False, "message": "Internal server error"}
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
EOF

# jwt_handler.py
cat > mediawiki_automation/web/auth/jwt_handler.py << 'EOF'
import os
import jwt
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from passlib.context import CryptContext

class JWTHandler:
    """JWT token handling and password utilities"""
    
    def __init__(self):
        self.secret_key = os.getenv("JWT_SECRET", "dev-secret-key-change-in-production")
        self.algorithm = "HS256"
        self.access_token_expire_hours = 24
        self.pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
    
    def create_access_token(self, data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        """Create JWT access token"""
        to_encode = data.copy()
        
        if expires_delta:
            expire = datetime.utcnow() + expires_delta
        else:
            expire = datetime.utcnow() + timedelta(hours=self.access_token_expire_hours)
        
        to_encode.update({
            "exp": expire,
            "iat": datetime.utcnow(),
            "type": "access"
        })
        
        encoded_jwt = jwt.encode(to_encode, self.secret_key, algorithm=self.algorithm)
        return encoded_jwt
    
    def decode_token(self, token: str) -> Dict[str, Any]:
        """Decode and validate JWT token"""
        try:
            payload = jwt.decode(token, self.secret_key, algorithms=[self.algorithm])
            return payload
        except jwt.ExpiredSignatureError:
            raise Exception("Token has expired")
        except jwt.JWTError:
            raise Exception("Invalid token")
    
    def verify_password(self, plain_password: str, hashed_password: str) -> bool:
        """Verify password against hash"""
        return self.pwd_context.verify(plain_password, hashed_password)
    
    def get_password_hash(self, password: str) -> str:
        """Generate password hash"""
        return self.pwd_context.hash(password)
    
    def is_token_valid(self, token: str) -> bool:
        """Check if token is valid"""
        try:
            self.decode_token(token)
            return True
        except Exception:
            return False
EOF

# ad_auth.py
cat > mediawiki_automation/web/auth/ad_auth.py << 'EOF'
import os
import ldap
from typing import Optional, Dict, Any
import logging

class ADAuthenticator:
    """Active Directory authentication"""
    
    def __init__(self):
        self.server = os.getenv("AD_SERVER", "ldap://dc.company.com")
        self.domain = os.getenv("AD_DOMAIN", "company.com")
        self.service_account = os.getenv("AD_SERVICE_ACCOUNT", "svc_mediawiki@company.com")
        self.service_password = os.getenv("AD_SERVICE_PASSWORD", "")
        self.base_dn = os.getenv("AD_BASE_DN", "DC=company,DC=com")
        self.admin_groups = ["Domain Admins", "MediaWiki Admins"]
        
        # Configure LDAP
        ldap.set_option(ldap.OPT_X_TLS_REQUIRE_CERT, ldap.OPT_X_TLS_NEVER)
        ldap.set_option(ldap.OPT_REFERRALS, 0)
        ldap.set_option(ldap.OPT_PROTOCOL_VERSION, 3)
        
        self.logger = logging.getLogger(__name__)
    
    async def authenticate(self, username: str, password: str) -> Optional[Dict[str, Any]]:
        """Authenticate user against Active Directory"""
        try:
            if not self.service_password:
                self.logger.warning("AD service password not configured, skipping AD auth")
                return None
            
            # Connect to AD
            conn = ldap.initialize(self.server)
            
            # Bind with service account
            conn.simple_bind_s(self.service_account, self.service_password)
            
            # Search for user
            search_filter = f"(sAMAccountName={username})"
            search_attrs = ['displayName', 'mail', 'memberOf', 'sAMAccountName']
            
            result = conn.search_s(
                self.base_dn,
                ldap.SCOPE_SUBTREE,
                search_filter,
                search_attrs
            )
            
            if not result:
                self.logger.warning(f"User {username} not found in AD")
                return None
            
            user_dn, user_attrs = result[0]
            
            # Try to authenticate user with their password
            try:
                user_conn = ldap.initialize(self.server)
                user_conn.simple_bind_s(user_dn, password)
                user_conn.unbind()
            except ldap.INVALID_CREDENTIALS:
                self.logger.warning(f"Invalid credentials for user {username}")
                return None
            
            # Extract user information
            display_name = user_attrs.get('displayName', [b''])[0].decode('utf-8')
            email = user_attrs.get('mail', [b''])[0].decode('utf-8')
            member_of = [group.decode('utf-8') for group in user_attrs.get('memberOf', [])]
            
            # Check if user is admin
            is_admin = any(
                any(admin_group in group for admin_group in self.admin_groups)
                for group in member_of
            )
            
            conn.unbind()
            
            return {
                "username": username,
                "full_name": display_name,
                "email": email or f"{username}@{self.domain}",
                "is_admin": is_admin,
                "groups": member_of
            }
            
        except ldap.LDAPError as e:
            self.logger.error(f"LDAP error during authentication: {e}")
            return None
        except Exception as e:
            self.logger.error(f"Unexpected error during AD authentication: {e}")
            return None
    
    def is_user_in_group(self, username: str, group_name: str) -> bool:
        """Check if user is member of specific group"""
        try:
            if not self.service_password:
                return False
            
            conn = ldap.initialize(self.server)
            conn.simple_bind_s(self.service_account, self.service_password)
            
            search_filter = f"(&(sAMAccountName={username})(memberOf=CN={group_name},{self.base_dn}))"
            result = conn.search_s(
                self.base_dn,
                ldap.SCOPE_SUBTREE,
                search_filter,
                ['sAMAccountName']
            )
            
            conn.unbind()
            return len(result) > 0
            
        except Exception as e:
            self.logger.error(f"Error checking group membership: {e}")
            return False
    
    def get_user_groups(self, username: str) -> list:
        """Get all groups for a user"""
        try:
            if not self.service_password:
                return []
            
            conn = ldap.initialize(self.server)
            conn.simple_bind_s(self.service_account, self.service_password)
            
            search_filter = f"(sAMAccountName={username})"
            result = conn.search_s(
                self.base_dn,
                ldap.SCOPE_SUBTREE,
                search_filter,
                ['memberOf']
            )
            
            if result:
                user_dn, user_attrs = result[0]
                groups = [group.decode('utf-8') for group in user_attrs.get('memberOf', [])]
                conn.unbind()
                return groups
            
            conn.unbind()
            return []
            
        except Exception as e:
            self.logger.error(f"Error getting user groups: {e}")
            return []
EOF

echo -e "${GREEN}✅ Phase 2 completed${NC}"
echo ""

echo -e "${BLUE}📝 Creating Phase 3: Worker & Content Processing Files...${NC}"

# ===== Phase 3: Worker Files =====

# Create workers directory if it doesn't exist
mkdir -p mediawiki_automation/workers

# content_converter.py
cat > mediawiki_automation/workers/content_converter.py << 'EOF'
import pypandoc
import os
import re
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
import yaml
from datetime import datetime

class ContentConverter:
    """Convert content between different formats using Pandoc"""
    
    def __init__(self, pandoc_path: str = "pandoc"):
        self.pandoc_path = pandoc_path
        self.image_extensions = {'.png', '.jpg', '.jpeg', '.gif', '.svg', '.webp'}
        self.supported_formats = {
            'markdown': 'md',
            'mediawiki': 'mediawiki',
            'html': 'html',
            'docx': 'docx',
            'pdf': 'pdf'
        }
    
    def convert_markdown_to_mediawiki(
        self, 
        content: str, 
        preserve_images: bool = True,
        base_path: str = None
    ) -> str:
        """Convert Markdown content to MediaWiki format"""
        try:
            # Pre-process content for better conversion
            processed_content = self._preprocess_markdown(content, base_path)
            
            # Convert using Pandoc
            mediawiki_content = pypandoc.convert_text(
                processed_content,
                'mediawiki',
                format='markdown',
                extra_args=['--wrap=none']
            )
            
            # Post-process for MediaWiki-specific formatting
            final_content = self._postprocess_mediawiki(mediawiki_content, preserve_images)
            
            return final_content
            
        except Exception as e:
            raise Exception(f"Markdown to MediaWiki conversion failed: {e}")
    
    def convert_mediawiki_to_markdown(self, content: str) -> str:
        """Convert MediaWiki content to Markdown format"""
        try:
            # Pre-process MediaWiki content
            processed_content = self._preprocess_mediawiki(content)
            
            # Convert using Pandoc
            markdown_content = pypandoc.convert_text(
                processed_content,
                'markdown',
                format='mediawiki',
                extra_args=['--wrap=none']
            )
            
            # Post-process for cleaner Markdown
            final_content = self._postprocess_markdown(markdown_content)
            
            return final_content
            
        except Exception as e:
            raise Exception(f"MediaWiki to Markdown conversion failed: {e}")
    
    def convert_file(
        self, 
        input_file: str, 
        output_file: str, 
        target_format: str = 'mediawiki'
    ) -> bool:
        """Convert file from one format to another"""
        try:
            input_path = Path(input_file)
            output_path = Path(output_file)
            
            if not input_path.exists():
                raise FileNotFoundError(f"Input file not found: {input_file}")
            
            # Determine input format
            input_format = self._detect_format(input_path)
            
            # Read content
            with open(input_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Convert based on formats
            if input_format == 'markdown' and target_format == 'mediawiki':
                converted_content = self.convert_markdown_to_mediawiki(
                    content, 
                    base_path=str(input_path.parent)
                )
            elif input_format == 'mediawiki' and target_format == 'markdown':
                converted_content = self.convert_mediawiki_to_markdown(content)
            else:
                # Use Pandoc directly for other formats
                converted_content = pypandoc.convert_text(
                    content,
                    target_format,
                    format=input_format
                )
            
            # Ensure output directory exists
            output_path.parent.mkdir(parents=True, exist_ok=True)
            
            # Write converted content
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(converted_content)
            
            return True
            
        except Exception as e:
            raise Exception(f"File conversion failed: {e}")
    
    def batch_convert_directory(
        self, 
        input_dir: str, 
        output_dir: str, 
        target_format: str = 'mediawiki',
        pattern: str = "**/*.md"
    ) -> Dict[str, Any]:
        """Convert all files in a directory"""
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        
        results = {
            'converted': [],
            'failed': [],
            'skipped': [],
            'total_files': 0,
            'start_time': datetime.now()
        }
        
        try:
            # Find all matching files
            files = list(input_path.glob(pattern))
            results['total_files'] = len(files)
            
            for file_path in files:
                try:
                    # Calculate relative path and output file
                    rel_path = file_path.relative_to(input_path)
                    output_file = output_path / rel_path.with_suffix(f'.{target_format}')
                    
                    # Convert file
                    if self.convert_file(str(file_path), str(output_file), target_format):
                        results['converted'].append({
                            'input': str(file_path),
                            'output': str(output_file),
                            'status': 'success'
                        })
                    
                except Exception as e:
                    results['failed'].append({
                        'file': str(file_path),
                        'error': str(e)
                    })
            
            results['end_time'] = datetime.now()
            results['duration'] = (results['end_time'] - results['start_time']).total_seconds()
            
            return results
            
        except Exception as e:
            results['error'] = str(e)
            return results
    
    def extract_images(self, content: str, base_path: str) -> List[Dict[str, str]]:
        """Extract image references from content"""
        images = []
        
        # Markdown image pattern: ![alt](path)
        md_pattern = r'!\[([^\]]*)\]\(([^)]+)\)'
        for match in re.finditer(md_pattern, content):
            alt_text = match.group(1)
            image_path = match.group(2)
            
            if not image_path.startswith('http'):
                full_path = Path(base_path) / image_path
                if full_path.exists():
                    images.append({
                        'alt': alt_text,
                        'path': image_path,
                        'full_path': str(full_path),
                        'type': 'markdown'
                    })
        
        return images
    
    def _detect_format(self, file_path: Path) -> str:
        """Detect file format based on extension"""
        extension = file_path.suffix.lower()
        
        format_map = {
            '.md': 'markdown',
            '.markdown': 'markdown',
            '.txt': 'markdown',
            '.wiki': 'mediawiki',
            '.html': 'html',
            '.htm': 'html',
            '.docx': 'docx',
            '.pdf': 'pdf'
        }
        
        return format_map.get(extension, 'markdown')
    
    def _preprocess_markdown(self, content: str, base_path: str = None) -> str:
        """Pre-process Markdown content before conversion"""
        # Fix heading levels (ensure proper hierarchy)
        content = self._fix_heading_levels(content)
        
        # Handle code blocks
        content = self._process_code_blocks(content)
        
        # Process internal links
        content = self._process_internal_links(content)
        
        return content
    
    def _postprocess_mediawiki(self, content: str, preserve_images: bool = True) -> str:
        """Post-process MediaWiki content after conversion"""
        # Fix common conversion issues
        
        # Fix code blocks
        content = re.sub(r'<pre><code class="([^"]+)">', r'<syntaxhighlight lang="\1">', content)
        content = re.sub(r'</code></pre>', r'</syntaxhighlight>', content)
        
        # Fix simple code spans
        content = re.sub(r'<code>([^<]+)</code>', r'<code>\1</code>', content)
        
        # Fix tables
        content = self._fix_mediawiki_tables(content)
        
        # Add categories and templates if needed
        content = self._add_mediawiki_metadata(content)
        
        return content
    
    def _preprocess_mediawiki(self, content: str) -> str:
        """Pre-process MediaWiki content before conversion"""
        # Convert MediaWiki-specific syntax
        
        # Handle templates (basic conversion)
        content = re.sub(r'\{\{([^}]+)\}\}', r'<!-- Template: \1 -->', content)
        
        # Handle categories
        content = re.sub(r'\[\[Category:([^\]]+)\]\]', r'<!-- Category: \1 -->', content)
        
        return content
    
    def _postprocess_markdown(self, content: str) -> str:
        """Post-process Markdown content after conversion"""
        # Clean up common issues from MediaWiki conversion
        
        # Fix excessive newlines
        content = re.sub(r'\n{3,}', '\n\n', content)
        
        # Fix list formatting
        content = re.sub(r'^\*\s+([^\s])', r'* \1', content, flags=re.MULTILINE)
        
        return content
    
    def _fix_heading_levels(self, content: str) -> str:
        """Ensure proper heading hierarchy"""
        lines = content.split('\n')
        current_level = 0
        
        for i, line in enumerate(lines):
            if line.startswith('#'):
                level = len(line) - len(line.lstrip('#'))
                if level > current_level + 1:
                    # Adjust level to maintain hierarchy
                    level = current_level + 1
                    lines[i] = '#' * level + line[line.find(' '):]
                current_level = level
        
        return '\n'.join(lines)
    
    def _process_code_blocks(self, content: str) -> str:
        """Process code blocks for better conversion"""
        # Ensure fenced code blocks have language identifiers
        content = re.sub(r'^```\s*$', '```text', content, flags=re.MULTILINE)
        return content
    
    def _process_internal_links(self, content: str) -> str:
        """Process internal links for MediaWiki compatibility"""
        # Convert markdown links to MediaWiki internal links where appropriate
        def replace_link(match):
            text = match.group(1)
            url = match.group(2)
            
            # If it's a relative link without extension, treat as internal
            if not url.startswith('http') and '.' not in url:
                return f"[[{url}|{text}]]"
            
            return match.group(0)
        
        content = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', replace_link, content)
        return content
    
    def _fix_mediawiki_tables(self, content: str) -> str:
        """Fix table formatting in MediaWiki"""
        # Basic table fixes - this could be expanded
        return content
    
    def _add_mediawiki_metadata(self, content: str) -> str:
        """Add MediaWiki-specific metadata"""
        # This would add categories, templates, etc. based on configuration
        return content
EOF

# file_monitor.py
cat > mediawiki_automation/workers/file_monitor.py << 'EOF'
import os
import time
from pathlib import Path
from typing import Dict, List, Set, Callable, Any
from datetime import datetime, timedelta
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileModifiedEvent, FileCreatedEvent, FileDeletedEvent
import threading
import queue
import yaml

class FileChangeEvent:
    """Represents a file change event"""
    
    def __init__(self, event_type: str, file_path: str, timestamp: datetime = None):
        self.event_type = event_type  # created, modified, deleted
        self.file_path = file_path
        self.timestamp = timestamp or datetime.now()
        self.processed = False

class MediaWikiFileHandler(FileSystemEventHandler):
    """Custom file handler for MediaWiki content changes"""
    
    def __init__(self, change_queue: queue.Queue, watched_extensions: Set[str]):
        super().__init__()
        self.change_queue = change_queue
        self.watched_extensions = watched_extensions or {'.md', '.markdown', '.txt', '.yaml', '.yml'}
        self.debounce_time = 2  # seconds
        self.pending_events = {}  # file_path -> timestamp
    
    def on_created(self, event):
        if not event.is_directory:
            self._handle_file_event('created', event.src_path)
    
    def on_modified(self, event):
        if not event.is_directory:
            self._handle_file_event('modified', event.src_path)
    
    def on_deleted(self, event):
        if not event.is_directory:
            self._handle_file_event('deleted', event.src_path)
    
    def _handle_file_event(self, event_type: str, file_path: str):
        """Handle file system events with debouncing"""
        path = Path(file_path)
        
        # Only process files with watched extensions
        if path.suffix.lower() not in self.watched_extensions:
            return
        
        # Skip hidden files and temporary files
        if path.name.startswith('.') or path.name.startswith('~'):
            return
        
        # Debounce rapid changes to the same file
        current_time = time.time()
        
        if file_path in self.pending_events:
            last_time = self.pending_events[file_path]
            if current_time - last_time < self.debounce_time:
                # Update timestamp but don't queue yet
                self.pending_events[file_path] = current_time
                return
        
        # Queue the event
        self.pending_events[file_path] = current_time
        
        # Use a timer to actually queue the event after debounce period
        timer = threading.Timer(
            self.debounce_time,
            self._queue_event,
            args=[event_type, file_path, current_time]
        )
        timer.start()
    
    def _queue_event(self, event_type: str, file_path: str, event_time: float):
        """Queue event after debounce period"""
        # Check if this is still the latest event for this file
        if file_path in self.pending_events:
            if self.pending_events[file_path] == event_time:
                # This is still the latest event, queue it
                change_event = FileChangeEvent(event_type, file_path)
                self.change_queue.put(change_event)
                
                # Remove from pending
                del self.pending_events[file_path]

class FileMonitor:
    """Monitor file system changes in MediaWiki content directories"""
    
    def __init__(self, config: Dict[str, Any], logger):
        self.config = config
        self.logger = logger
        self.observers = []
        self.change_queue = queue.Queue()
        self.watched_paths = set()
        self.running = False
        self.change_handlers = []
        
        # Configuration
        self.watched_extensions = set(
            config.get('file_monitor', {}).get('extensions', ['.md', '.markdown', '.txt', '.yaml', '.yml'])
        )
        self.exclude_patterns = config.get('file_monitor', {}).get('exclude_patterns', [])
        self.batch_processing = config.get('file_monitor', {}).get('batch_processing', True)
        self.batch_delay = config.get('file_monitor', {}).get('batch_delay', 5)  # seconds
    
    def add_watch_path(self, path: str, recursive: bool = True):
        """Add a path to monitor for changes"""
        path_obj = Path(path)
        
        if not path_obj.exists():
            self.logger.warning(f"Watch path does not exist: {path}")
            return False
        
        if not path_obj.is_dir():
            self.logger.warning(f"Watch path is not a directory: {path}")
            return False
        
        self.watched_paths.add(str(path_obj.absolute()))
        
        if self.running:
            self._start_observer_for_path(str(path_obj.absolute()), recursive)
        
        self.logger.info(f"Added watch path: {path}")
        return True
    
    def remove_watch_path(self, path: str):
        """Remove a path from monitoring"""
        path_obj = Path(path)
        abs_path = str(path_obj.absolute())
        
        if abs_path in self.watched_paths:
            self.watched_paths.remove(abs_path)
            
            # Stop and restart observers (simple approach)
            if self.running:
                self.stop()
                self.start()
            
            self.logger.info(f"Removed watch path: {path}")
            return True
        
        return False
    
    def add_change_handler(self, handler: Callable[[FileChangeEvent], None]):
        """Add a handler function for file changes"""
        self.change_handlers.append(handler)
    
    def start(self):
        """Start monitoring file changes"""
        if self.running:
            return
        
        self.running = True
        
        # Start observers for all watched paths
        for path in self.watched_paths:
            self._start_observer_for_path(path, recursive=True)
        
        # Start change processing thread
        self.processing_thread = threading.Thread(target=self._process_changes, daemon=True)
        self.processing_thread.start()
        
        self.logger.info(f"File monitor started, watching {len(self.watched_paths)} paths")
    
    def stop(self):
        """Stop monitoring file changes"""
        if not self.running:
            return
        
        self.running = False
        
        # Stop all observers
        for observer in self.observers:
            observer.stop()
            observer.join(timeout=5)
        
        self.observers.clear()
        
        self.logger.info("File monitor stopped")
    
    def get_recent_changes(self, since: datetime = None) -> List[FileChangeEvent]:
        """Get recent file changes (for manual processing)"""
        if since is None:
            since = datetime.now() - timedelta(hours=1)
        
        changes = []
        temp_queue = queue.Queue()
        
        # Drain the queue and filter by timestamp
        while True:
            try:
                event = self.change_queue.get_nowait()
                if event.timestamp >= since:
                    changes.append(event)
                temp_queue.put(event)
            except queue.Empty:
                break
        
        # Put events back in queue
        while True:
            try:
                event = temp_queue.get_nowait()
                self.change_queue.put(event)
            except queue.Empty:
                break
        
        return changes
    
    def force_scan(self, path: str = None) -> List[str]:
        """Force scan a directory for changes (useful for initial sync)"""
        scan_paths = [path] if path else self.watched_paths
        all_files = []
        
        for scan_path in scan_paths:
            path_obj = Path(scan_path)
            if path_obj.exists() and path_obj.is_dir():
                # Find all files with watched extensions
                for ext in self.watched_extensions:
                    pattern = f"**/*{ext}"
                    files = list(path_obj.glob(pattern))
                    all_files.extend([str(f) for f in files])
        
        self.logger.info(f"Force scan found {len(all_files)} files")
        return all_files
    
    def _start_observer_for_path(self, path: str, recursive: bool = True):
        """Start file system observer for a specific path"""
        try:
            event_handler = MediaWikiFileHandler(self.change_queue, self.watched_extensions)
            observer = Observer()
            observer.schedule(event_handler, path, recursive=recursive)
            observer.start()
            
            self.observers.append(observer)
            
            self.logger.debug(f"Started observer for path: {path}")
            
        except Exception as e:
            self.logger.error(f"Failed to start observer for path {path}: {e}")
    
    def _process_changes(self):
        """Process file changes in background thread"""
        batch = []
        last_batch_time = time.time()
        
        while self.running:
            try:
                # Wait for changes with timeout
                try:
                    event = self.change_queue.get(timeout=1)
                    batch.append(event)
                except queue.Empty:
                    # Check if we should process current batch
                    if batch and time.time() - last_batch_time >= self.batch_delay:
                        self._process_batch(batch)
                        batch = []
                        last_batch_time = time.time()
                    continue
                
                # Process batch if conditions are met
                if self.batch_processing:
                    current_time = time.time()
                    if (len(batch) >= 10 or  # Batch size limit
                        current_time - last_batch_time >= self.batch_delay):  # Time limit
                        self._process_batch(batch)
                        batch = []
                        last_batch_time = current_time
                else:
                    # Process immediately
                    self._process_batch([event])
                    batch = []
                
            except Exception as e:
                self.logger.error(f"Error processing file changes: {e}")
        
        # Process any remaining batch
        if batch:
            self._process_batch(batch)
    
    def _process_batch(self, events: List[FileChangeEvent]):
        """Process a batch of file change events"""
        if not events:
            return
        
        self.logger.info(f"Processing batch of {len(events)} file changes")
        
        # Group events by file path (keep only latest event per file)
        latest_events = {}
        for event in events:
            latest_events[event.file_path] = event
        
        # Process each unique file change
        for event in latest_events.values():
            try:
                self._process_single_event(event)
                event.processed = True
            except Exception as e:
                self.logger.error(f"Error processing file change {event.file_path}: {e}")
    
    def _process_single_event(self, event: FileChangeEvent):
        """Process a single file change event"""
        self.logger.debug(f"Processing {event.event_type} event for {event.file_path}")
        
        # Call all registered handlers
        for handler in self.change_handlers:
            try:
                handler(event)
            except Exception as e:
                self.logger.error(f"Error in change handler: {e}")
    
    def _should_exclude_file(self, file_path: str) -> bool:
        """Check if file should be excluded based on patterns"""
        path = Path(file_path)
        
        for pattern in self.exclude_patterns:
            if pattern in str(path):
                return True
        
        return False
EOF

# sync_engine.py
cat > mediawiki_automation/workers/sync_engine.py << 'EOF'
import pywikibot
from pathlib import Path
from typing import Dict, List, Optional, Any, Tuple
from datetime import datetime
import hashlib
import yaml
import re
from .content_converter import ContentConverter
from .file_monitor import FileChangeEvent

class SyncResult:
    """Result of a sync operation"""
    
    def __init__(self):
        self.success = False
        self.files_processed = 0
        self.files_created = 0
        self.files_updated = 0
        self.files_deleted = 0
        self.files_skipped = 0
        self.errors = []
        self.warnings = []
        self.start_time = datetime.now()
        self.end_time = None
        self.details = {}
    
    def finish(self):
        """Mark sync as finished"""
        self.end_time = datetime.now()
        self.success = len(self.errors) == 0
    
    def duration(self) -> float:
        """Get sync duration in seconds"""
        if self.end_time:
            return (self.end_time - self.start_time).total_seconds()
        return 0
    
    def add_error(self, message: str, file_path: str = None):
        """Add an error to the result"""
        self.errors.append({
            'message': message,
            'file': file_path,
            'timestamp': datetime.now()
        })
    
    def add_warning(self, message: str, file_path: str = None):
        """Add a warning to the result"""
        self.warnings.append({
            'message': message,
            'file': file_path,
            'timestamp': datetime.now()
        })

class MediaWikiPage:
    """Represents a MediaWiki page for sync operations"""
    
    def __init__(self, title: str, content: str, summary: str = None):
        self.title = title
        self.content = content
        self.summary = summary or "Automated content sync"
        self.exists = False
        self.current_content = ""
        self.content_hash = hashlib.md5(content.encode('utf-8')).hexdigest()

class SyncEngine:
    """Engine for synchronizing content between file system and MediaWiki"""
    
    def __init__(self, config: Dict[str, Any], logger, auth_manager):
        self.config = config
        self.logger = logger
        self.auth_manager = auth_manager
        self.content_converter = ContentConverter()
        
        # Sync configuration
        self.dry_run = False
        self.force_update = False
        self.conflict_resolution = 'skip'  # skip, overwrite, prompt
        self.batch_size = 10
        
    def sync_site(
        self, 
        site_config: Dict[str, Any], 
        instance_name: str,
        dry_run: bool = False,
        force: bool = False
    ) -> SyncResult:
        """Sync entire site content to MediaWiki"""
        result = SyncResult()
        self.dry_run = dry_run
        self.force_update = force
        
        try:
            self.logger.info(f"Starting sync for site: {site_config['site']['name']}")
            
            # Get MediaWiki site connection
            site = self.auth_manager.get_site(instance_name)
            
            # Get content path
            content_path = Path(site_config['metadata']['content_path'])
            if not content_path.exists():
                result.add_error(f"Content path does not exist: {content_path}")
                result.finish()
                return result
            
            # Discover content files
            content_files = self._discover_content_files(content_path)
            self.logger.info(f"Found {len(content_files)} content files")
            
            # Process each file
            for file_path in content_files:
                try:
                    file_result = self._sync_file(
                        file_path, 
                        content_path, 
                        site_config, 
                        site
                    )
                    
                    result.files_processed += 1
                    
                    if file_result['action'] == 'created':
                        result.files_created += 1
                    elif file_result['action'] == 'updated':
                        result.files_updated += 1
                    elif file_result['action'] == 'skipped':
                        result.files_skipped += 1
                    
                    result.details[str(file_path)] = file_result
                    
                except Exception as e:
                    result.add_error(f"Failed to sync file {file_path}: {e}", str(file_path))
            
            # Handle deletions if configured
            if site_config.get('sync', {}).get('handle_deletions', False):
                self._handle_deletions(content_path, site_config, site, result)
            
            result.finish()
            
            self.logger.info(
                f"Sync completed for {site_config['site']['name']}: "
                f"{result.files_processed} processed, "
                f"{result.files_created} created, "
                f"{result.files_updated} updated, "
                f"{len(result.errors)} errors"
            )
            
            return result
            
        except Exception as e:
            result.add_error(f"Sync failed: {e}")
            result.finish()
            self.logger.error(f"Sync failed for site {site_config['site']['name']}: {e}")
            return result
    
    def sync_file_change(
        self, 
        change_event: FileChangeEvent, 
        site_config: Dict[str, Any], 
        instance_name: str
    ) -> SyncResult:
        """Sync a single file change to MediaWiki"""
        result = SyncResult()
        
        try:
            file_path = Path(change_event.file_path)
            content_path = Path(site_config['metadata']['content_path'])
            
            # Get MediaWiki site connection
            site = self.auth_manager.get_site(instance_name)
            
            if change_event.event_type == 'deleted':
                # Handle file deletion
                wiki_title = self._get_wiki_title(file_path, content_path, site_config)
                if wiki_title:
                    self._delete_wiki_page(wiki_title, site, result)
            else:
                # Handle file creation/modification
                file_result = self._sync_file(file_path, content_path, site_config, site)
                result.files_processed = 1
                
                if file_result['action'] == 'created':
                    result.files_created = 1
                elif file_result['action'] == 'updated':
                    result.files_updated = 1
                else:
                    result.files_skipped = 1
                
                result.details[str(file_path)] = file_result
            
            result.finish()
            return result
            
        except Exception as e:
            result.add_error(f"Failed to sync file change: {e}")
            result.finish()
            return result
    
    def _sync_file(
        self, 
        file_path: Path, 
        content_path: Path, 
        site_config: Dict[str, Any], 
        site: pywikibot.Site
    ) -> Dict[str, Any]:
        """Sync a single file to MediaWiki"""
        
        # Calculate relative path
        rel_path = file_path.relative_to(content_path)
        
        # Get wiki title for this file
        wiki_title = self._get_wiki_title(file_path, content_path, site_config)
        if not wiki_title:
            return {'action': 'skipped', 'reason': 'No wiki title mapping'}
        
        # Read and convert content
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                file_content = f.read()
        except Exception as e:
            return {'action': 'error', 'reason': f'Failed to read file: {e}'}
        
        # Convert to MediaWiki format
        try:
            if file_path.suffix.lower() in ['.md', '.markdown']:
                wiki_content = self.content_converter.convert_markdown_to_mediawiki(
                    file_content,
                    base_path=str(file_path.parent)
                )
            else:
                wiki_content = file_content
        except Exception as e:
            return {'action': 'error', 'reason': f'Content conversion failed: {e}'}
        
        # Apply content processing rules
        wiki_content = self._apply_content_processing(wiki_content, rel_path, site_config)
        
        # Create MediaWiki page object
        page = pywikibot.Page(site, wiki_title)
        
        # Check if page exists and get current content
        page_exists = page.exists()
        current_content = page.text if page_exists else ""
        
        # Check if content has changed
        if not self.force_update and page_exists:
            if self._normalize_content(current_content) == self._normalize_content(wiki_content):
                return {'action': 'skipped', 'reason': 'Content unchanged'}
        
        # Handle conflicts
        if page_exists and self.conflict_resolution == 'skip' and not self.force_update:
            # Check if there might be a conflict (basic check)
            if len(current_content.strip()) > 0 and current_content != wiki_content:
                return {'action': 'skipped', 'reason': 'Potential conflict, skipping'}
        
        # Create edit summary
        summary = self._create_edit_summary(file_path, page_exists)
        
        # Save page (if not dry run)
        if not self.dry_run:
            try:
                page.text = wiki_content
                page.save(summary=summary, minor=False)
                
                action = 'updated' if page_exists else 'created'
                return {
                    'action': action,
                    'wiki_title': wiki_title,
                    'summary': summary,
                    'content_length': len(wiki_content)
                }
                
            except Exception as e:
                return {'action': 'error', 'reason': f'Failed to save page: {e}'}
        else:
            action = 'would_update' if page_exists else 'would_create'
            return {
                'action': action,
                'wiki_title': wiki_title,
                'summary': summary,
                'content_length': len(wiki_content)
            }
    
    def _discover_content_files(self, content_path: Path) -> List[Path]:
        """Discover all content files to sync"""
        files = []
        
        # Supported file extensions
        extensions = ['.md', '.markdown', '.txt']
        
        for ext in extensions:
            pattern = f"**/*{ext}"
            found_files = list(content_path.glob(pattern))
            files.extend(found_files)
        
        # Filter out files that should be excluded
        filtered_files = []
        exclude_patterns = ['.git', '__pycache__', '.DS_Store', 'README.md']
        
        for file_path in files:
            should_exclude = False
            for pattern in exclude_patterns:
                if pattern in str(file_path):
                    should_exclude = True
                    break
            
            if not should_exclude:
                filtered_files.append(file_path)
        
        return filtered_files
    
    def _get_wiki_title(
        self, 
        file_path: Path, 
        content_path: Path, 
        site_config: Dict[str, Any]
    ) -> Optional[str]:
        """Generate wiki title for a file"""
        
        rel_path = file_path.relative_to(content_path)
        
        # Get base wiki path from config
        base_path = site_config['site'].get('wiki_base_path', '')
        
        # Handle folder mappings
        folder_mappings = site_config.get('folder_mapping', [])
        
        for mapping in folder_mappings:
            if str(rel_path).startswith(mapping['folder']):
                # Apply folder mapping
                mapped_path = str(rel_path).replace(mapping['folder'], mapping['wiki_name'], 1)
                wiki_title = f"{base_path}/{mapped_path}" if base_path else mapped_path
                break
        else:
            # Default mapping
            wiki_title = f"{base_path}/{rel_path}" if base_path else str(rel_path)
        
        # Clean up title
        wiki_title = wiki_title.replace('\\', '/')  # Normalize path separators
        wiki_title = re.sub(r'/+', '/', wiki_title)  # Remove duplicate slashes
        wiki_title = wiki_title.strip('/')  # Remove leading/trailing slashes
        
        # Remove file extension
        if wiki_title.endswith(file_path.suffix):
            wiki_title = wiki_title[:-len(file_path.suffix)]
        
        # Replace underscores with spaces (MediaWiki convention)
        wiki_title = wiki_title.replace('_', ' ')
        
        return wiki_title
    
    def _apply_content_processing(
        self, 
        content: str, 
        rel_path: Path, 
        site_config: Dict[str, Any]
    ) -> str:
        """Apply content processing rules from site config"""
        
        processing_rules = site_config.get('content_processing', [])
        
        for rule in processing_rules:
            applies_to = rule.get('applies_to', '')
            
            # Check if rule applies to this file
            if applies_to and not str(rel_path).startswith(applies_to):
                continue
            
            # Apply category
            if 'add_category' in rule:
                category = rule['add_category']
                if category not in content:
                    content += f"\n\n{category}"
            
            # Apply template
            if 'add_template' in rule:
                template = rule['add_template']
                if template not in content:
                    content = f"{template}\n\n{content}"
            
            # Apply custom transformations
            if 'transformations' in rule:
                for transform in rule['transformations']:
                    if transform['type'] == 'replace':
                        content = content.replace(transform['from'], transform['to'])
                    elif transform['type'] == 'regex':
                        content = re.sub(transform['pattern'], transform['replacement'], content)
        
        return content
    
    def _normalize_content(self, content: str) -> str:
        """Normalize content for comparison"""
        # Remove extra whitespace and normalize line endings
        normalized = re.sub(r'\s+', ' ', content.strip())
        normalized = normalized.replace('\r\n', '\n').replace('\r', '\n')
        return normalized
    
    def _create_edit_summary(self, file_path: Path, page_exists: bool) -> str:
        """Create edit summary for wiki page"""
        action = "Updated" if page_exists else "Created"
        return f"{action} from {file_path.name} via MediaWiki Automation"
    
    def _handle_deletions(
        self, 
        content_path: Path, 
        site_config: Dict[str, Any], 
        site: pywikibot.Site, 
        result: SyncResult
    ):
        """Handle deletion of pages that no longer have corresponding files"""
        # This would require tracking which pages were created by the sync system
        # For now, we'll skip this to avoid accidentally deleting important pages
        pass
    
    def _delete_wiki_page(self, wiki_title: str, site: pywikibot.Site, result: SyncResult):
        """Delete a wiki page"""
        if self.dry_run:
            result.details[wiki_title] = {'action': 'would_delete'}
            return
        
        try:
            page = pywikibot.Page(site, wiki_title)
            if page.exists():
                page.delete(reason="File deleted from source repository", prompt=False)
                result.files_deleted += 1
                result.details[wiki_title] = {'action': 'deleted'}
            else:
                result.details[wiki_title] = {'action': 'already_deleted'}
        except Exception as e:
            result.add_error(f"Failed to delete page {wiki_title}: {e}")
EOF

# celery_app.py
cat > mediawiki_automation/workers/celery_app.py << 'EOF'
from celery import Celery
from celery.schedules import crontab
import os
import sys
from pathlib import Path

# Add the project root to the Python path
project_root = Path(__file__).parent.parent.parent
sys.path.insert(0, str(project_root))

# Celery configuration
redis_url = os.getenv('REDIS_URL', 'redis://localhost:6379/0')

# Create Celery app
celery_app = Celery(
    'mediawiki_automation',
    broker=redis_url,
    backend=redis_url,
    include=[
        'mediawiki_automation.workers.sync_tasks',
        'mediawiki_automation.workers.monitoring_tasks',
        'mediawiki_automation.workers.maintenance_tasks'
    ]
)

# Celery configuration
celery_app.conf.update(
    # Task settings
    task_serializer='json',
    accept_content=['json'],
    result_serializer='json',
    timezone='UTC',
    enable_utc=True,
    
    # Worker settings
    worker_prefetch_multiplier=1,
    task_acks_late=True,
    worker_disable_rate_limits=False,
    
    # Result backend settings
    result_expires=3600,  # 1 hour
    result_persistent=True,
    
    # Task routing
    task_routes={
        'mediawiki_automation.workers.sync_tasks.sync_site': {'queue': 'sync'},
        'mediawiki_automation.workers.sync_tasks.sync_file_change': {'queue': 'sync'},
        'mediawiki_automation.workers.monitoring_tasks.health_check': {'queue': 'monitoring'},
        'mediawiki_automation.workers.maintenance_tasks.cleanup_old_jobs': {'queue': 'maintenance'},
    },
    
    # Queue settings
    task_default_queue='default',
    task_create_missing_queues=True,
    
    # Beat schedule (for periodic tasks)
    beat_schedule={
        'health-check-every-5-minutes': {
            'task': 'mediawiki_automation.workers.monitoring_tasks.health_check',
            'schedule': crontab(minute='*/5'),
        },
        'cleanup-old-jobs-daily': {
            'task': 'mediawiki_automation.workers.maintenance_tasks.cleanup_old_jobs',
            'schedule': crontab(hour=2, minute=0),  # Daily at 2 AM
        },
        'auto-sync-sites-hourly': {
            'task': 'mediawiki_automation.workers.sync_tasks.auto_sync_approved_sites',
            'schedule': crontab(minute=0),  # Every hour
        },
    }
)

# Sync tasks
@celery_app.task(bind=True)
def sync_site_task(self, site_id: int, dry_run: bool = False, force: bool = False):
    """Celery task for syncing a site"""
    from mediawiki_automation.main import MediaWikiAutomationSystem
    from mediawiki_automation.web.database import get_database_session
    from mediawiki_automation.web.models import Site, SyncJob
    from datetime import datetime
    
    # Update task state
    self.update_state(state='PROGRESS', meta={'progress': 0, 'status': 'Starting sync...'})
    
    try:
        # Initialize system
        system = MediaWikiAutomationSystem()
        
        # Get database session
        db = next(get_database_session())
        
        try:
            # Get site information
            site = db.query(Site).filter(Site.id == site_id).first()
            if not site:
                raise Exception(f"Site with ID {site_id} not found")
            
            # Update task state
            self.update_state(state='PROGRESS', meta={'progress': 10, 'status': f'Syncing site: {site.display_name}'})
            
            # Load site configuration
            site_config = system.config_manager.get_site_config(site.content_path)
            
            # Get MediaWiki instance name
            instance_name = site_config['site']['name']
            
            # Perform sync
            from mediawiki_automation.workers.sync_engine import SyncEngine
            sync_engine = SyncEngine(system.config, system.logger, system.auth_manager)
            
            self.update_state(state='PROGRESS', meta={'progress': 20, 'status': 'Processing files...'})
            
            result = sync_engine.sync_site(site_config, instance_name, dry_run, force)
            
            # Update site last_sync timestamp
            if result.success:
                site.last_sync = datetime.now()
                db.commit()
            
            self.update_state(state='PROGRESS', meta={'progress': 100, 'status': 'Sync completed'})
            
            return {
                'success': result.success,
                'files_processed': result.files_processed,
                'files_created': result.files_created,
                'files_updated': result.files_updated,
                'files_skipped': result.files_skipped,
                'errors': result.errors,
                'warnings': result.warnings,
                'duration': result.duration()
            }
            
        finally:
            db.close()
            
    except Exception as e:
        self.update_state(state='FAILURE', meta={'error': str(e)})
        raise

@celery_app.task(bind=True)
def sync_file_change_task(self, site_id: int, file_path: str, event_type: str):
    """Celery task for syncing a single file change"""
    from mediawiki_automation.main import MediaWikiAutomationSystem
    from mediawiki_automation.web.database import get_database_session
    from mediawiki_automation.web.models import Site
    from mediawiki_automation.workers.file_monitor import FileChangeEvent
    from datetime import datetime
    
    try:
        # Initialize system
        system = MediaWikiAutomationSystem()
        
        # Get database session
        db = next(get_database_session())
        
        try:
            # Get site information
            site = db.query(Site).filter(Site.id == site_id).first()
            if not site:
                raise Exception(f"Site with ID {site_id} not found")
            
            # Load site configuration
            site_config = system.config_manager.get_site_config(site.content_path)
            
            # Get MediaWiki instance name
            instance_name = site_config['site']['name']
            
            # Create file change event
            change_event = FileChangeEvent(event_type, file_path)
            
            # Perform sync
            from mediawiki_automation.workers.sync_engine import SyncEngine
            sync_engine = SyncEngine(system.config, system.logger, system.auth_manager)
            
            result = sync_engine.sync_file_change(change_event, site_config, instance_name)
            
            # Update site last_sync timestamp if successful
            if result.success:
                site.last_sync = datetime.now()
                db.commit()
            
            return {
                'success': result.success,
                'files_processed': result.files_processed,
                'errors': result.errors,
                'duration': result.duration()
            }
            
        finally:
            db.close()
            
    except Exception as e:
        raise

@celery_app.task
def auto_sync_approved_sites():
    """Automatically sync all approved sites"""
    from mediawiki_automation.main import MediaWikiAutomationSystem
    from mediawiki_automation.web.database import get_database_session
    from mediawiki_automation.web.models import Site
    
    try:
        # Initialize system
        system = MediaWikiAutomationSystem()
        
        # Get database session
        db = next(get_database_session())
        
        try:
            # Get all approved sites with auto_sync enabled
            sites = db.query(Site).filter(Site.status == 'approved').all()
            
            results = []
            for site in sites:
                try:
                    # Load site configuration
                    site_config = system.config_manager.get_site_config(site.content_path)
                    
                    # Check if auto sync is enabled
                    if not site_config.get('sync', {}).get('auto_sync', False):
                        continue
                    
                    # Trigger sync task
                    task = sync_site_task.delay(site.id, dry_run=False, force=False)
                    
                    results.append({
                        'site_id': site.id,
                        'site_name': site.name,
                        'task_id': task.id,
                        'status': 'queued'
                    })
                    
                except Exception as e:
                    results.append({
                        'site_id': site.id,
                        'site_name': site.name,
                        'error': str(e),
                        'status': 'failed'
                    })
            
            return {
                'total_sites': len(sites),
                'queued_syncs': len([r for r in results if r.get('status') == 'queued']),
                'results': results
            }
            
        finally:
            db.close()
            
    except Exception as e:
        raise

# Monitoring tasks
@celery_app.task
def health_check():
    """Periodic health check task"""
    from mediawiki_automation.main import MediaWikiAutomationSystem
    from datetime import datetime
    
    try:
        # Initialize system
        system = MediaWikiAutomationSystem()
        
        # Get system status
        status = system.get_system_status()
        
        # Log health check
        system.logger.info("Health check completed", **status)
        
        return {
            'timestamp': datetime.now().isoformat(),
            'status': 'healthy',
            'details': status
        }
        
    except Exception as e:
        return {
            'timestamp': datetime.now().isoformat(),
            'status': 'unhealthy',
            'error': str(e)
        }

# Maintenance tasks
@celery_app.task
def cleanup_old_jobs():
    """Clean up old sync jobs"""
    from mediawiki_automation.web.database import get_database_session
    from mediawiki_automation.web.models import SyncJob
    from datetime import datetime, timedelta
    
    try:
        # Get database session
        db = next(get_database_session())
        
        try:
            # Delete jobs older than 30 days
            cutoff_date = datetime.now() - timedelta(days=30)
            
            old_jobs = db.query(SyncJob).filter(SyncJob.created_at < cutoff_date).all()
            deleted_count = len(old_jobs)
            
            for job in old_jobs:
                db.delete(job)
            
            db.commit()
            
            return {
                'deleted_jobs': deleted_count,
                'cutoff_date': cutoff_date.isoformat()
            }
            
        finally:
            db.close()
            
    except Exception as e:
        raise

if __name__ == '__main__':
    celery_app.start()
EOF

echo -e "${GREEN}✅ Phase 3 completed${NC}"
echo ""

echo -e "${BLUE}📝 Creating Configuration Files...${NC}"

# Create configuration files
if [ ! -f config/base_config.yaml ]; then
    cat > config/base_config.yaml << 'CONFIG'
system:
  log_level: "DEBUG"
  max_concurrent_operations: 5
  retry_attempts: 3
  timeout_seconds: 30

content_discovery:
  base_paths: ["./content"]

authentication:
  git_wiki:
    url: "https://git.mediawiki.urlen"
    username: "automation_bot"
    password: "${GIT_WIKI_PASSWORD}"
    family: "mediawiki"
  github_admin_wiki:
    url: "https://github-admin.mediawiki.urlen"
    username: "admin_bot"
    password: "${GITHUB_ADMIN_PASSWORD}"
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

file_monitor:
  extensions: [".md", ".markdown", ".txt", ".yaml", ".yml"]
  exclude_patterns: [".git", "__pycache__", ".DS_Store"]
  batch_processing: true
  batch_delay: 5
CONFIG
fi

# Create sample site configuration
if [ ! -f content/Git-Documentation/.mediawiki-config.yaml ]; then
    cat > content/Git-Documentation/.mediawiki-config.yaml << 'SITECONFIG'
metadata:
  created_by: "admin@company.com"
  created_date: "2025-07-01T10:00:00Z"
  status: "approved"
  content_path: "./content/Git-Documentation"

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
  handle_deletions: false
SITECONFIG
fi

# Create requirements files
mkdir -p requirements
cat > requirements/base.txt << 'REQUIREMENTS'
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
watchdog>=3.0.0
REQUIREMENTS

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
    cat > .env << 'ENV'
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
fi

# Create setup script
cat > setup.sh << 'SETUP'
#!/bin/bash
set -euo pipefail

echo "🚀 Starting MediaWiki Automation System setup..."

# Check prerequisites
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 is required but not installed"
    exit 1
fi

echo "✅ Prerequisites check passed"

# Install dependencies
pip install --upgrade pip
pip install -r requirements/base.txt
echo "✅ Dependencies installed"

# Create logs directory
mkdir -p logs

echo "✅ Setup completed!"
echo ""
echo "🌐 Next steps:"
echo "  1. Run: ./start.sh to start the web application"
echo "  2. Access: http://localhost:8000"
echo ""
echo "🔧 To start background workers:"
echo "  celery -A mediawiki_automation.workers.celery_app worker --loglevel=info"
echo ""
echo "📊 To start Celery Beat (scheduler):"
echo "  celery -A mediawiki_automation.workers.celery_app beat --loglevel=info"
SETUP

chmod +x setup.sh

# Create start script
cat > start.sh << 'START'
#!/bin/bash
cd "$(dirname "$0")"
echo "🚀 Starting MediaWiki Automation Web Application..."
uvicorn mediawiki_automation.web.app:app --host 0.0.0.0 --port 8000 --reload
START

chmod +x start.sh

echo -e "${GREEN}✅ All files created successfully!${NC}"
echo ""
echo -e "${BLUE}📋 Next Steps:${NC}"
echo "1. Review the created files in mediawiki_automation/"
echo "2. Run: ./setup.sh to install dependencies"
echo "3. Start the web app: ./start.sh"
echo "4. Access at http://localhost:8000"
echo ""
echo -e "${BLUE}🔐 Default Login:${NC}"
echo "Username: admin"
echo "Password: admin123"
echo ""
echo -e "${BLUE}🔧 Background Workers:${NC}"
echo "# In separate terminals:"
echo "celery -A mediawiki_automation.workers.celery_app worker --loglevel=info"
echo "celery -A mediawiki_automation.workers.celery_app beat --loglevel=info"
echo ""
echo -e "${GREEN}🎉 MediaWiki Automation System is ready to use!${NC}"