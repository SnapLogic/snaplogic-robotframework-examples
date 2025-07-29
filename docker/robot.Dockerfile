FROM python:3.12.7-slim-bookworm 

# Set the working directory
WORKDIR /app

# Install system dependencies for database drivers
RUN apt-get update && apt-get install -y \
    gcc \
    g++ \
    unixodbc-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements file
COPY requirements.txt . 

# Install dependencies, excluding ibm_db on ARM64
RUN if [ "$(uname -m)" = "aarch64" ]; then \
        grep -v "ibm_db" requirements.txt > requirements-filtered.txt && \
        pip install --no-cache-dir --index-url https://pypi.org/simple -r requirements-filtered.txt; \
    else \
        pip install --no-cache-dir --index-url https://pypi.org/simple -r requirements.txt; \
    fi
