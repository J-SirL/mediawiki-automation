ARG PYTHON_VERSION=3.11
FROM python:${PYTHON_VERSION}

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # Development tools
    git \
    curl \
    wget \
    vim \
    nano \
    htop \
    build-essential \
    # PostgreSQL client
    postgresql-client \
    # Redis tools
    redis-tools \
    # Pandoc for content conversion
    pandoc \
    # LDAP development libraries
    libldap2-dev \
    libsasl2-dev \
    # Docker CLI
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    # Network tools
    iputils-ping \
    net-tools \
    dnsutils \
    # Process management
    supervisor \
    # Node.js for frontend development
    nodejs \
    npm \
    && rm -rf /var/lib/apt/lists/*

# Install Docker CLI
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null && \
    apt-get update && \
    apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# Create coder user
RUN useradd --create-home --shell /bin/bash coder && \
    usermod -aG sudo coder && \
    echo "coder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/coder

# Install Python development tools globally
RUN pip install --upgrade pip setuptools wheel && \
    pip install \
    # Development tools
    ipython \
    jupyter \
    jupyterlab \
    notebook \
    # Code quality
    black \
    isort \
    flake8 \
    mypy \
    pylint \
    # Testing
    pytest \
    pytest-asyncio \
    pytest-cov \
    # Documentation
    sphinx \
    mkdocs \
    # Debugging
    ipdb \
    # Performance profiling
    line_profiler \
    memory_profiler

# Install project-specific Python packages
RUN pip install \
    # Web framework
    fastapi \
    uvicorn[standard] \
    # Database
    sqlalchemy \
    alembic \
    psycopg2-binary \
    # Async tasks
    celery \
    redis \
    kombu \
    # MediaWiki integration
    pywikibot \
    pypandoc \
    # Authentication
    python-jose[cryptography] \
    passlib[bcrypt] \
    python-ldap \
    # API and networking
    httpx \
    requests \
    aiofiles \
    websockets \
    # Configuration
    pyyaml \
    python-dotenv \
    # Monitoring
    prometheus-client \
    # CLI tools
    typer \
    click \
    rich \
    # Data validation
    pydantic[email] \
    # Utilities
    structlog

# Install Node.js packages for frontend development
RUN npm install -g \
    @vue/cli \
    create-react-app \
    typescript \
    webpack \
    webpack-cli \
    prettier \
    eslint

# Create necessary directories
RUN mkdir -p /home/coder/.local/bin /home/coder/.config /home/coder/mediawiki-automation

# Set up Git configuration
RUN git config --global init.defaultBranch main && \
    git config --global pull.rebase false

# Set working directory
WORKDIR /home/coder

# Switch to coder user
USER coder

# Set PATH to include user's local bin
ENV PATH="/home/coder/.local/bin:${PATH}"

# Default command
CMD ["/bin/bash"]