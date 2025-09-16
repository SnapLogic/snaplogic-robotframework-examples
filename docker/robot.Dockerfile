FROM python:3.12.7-slim-bookworm 

# Set the working directory
WORKDIR /app

# Install system dependencies for database drivers
# First install essential packages that should always work
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    wget \
    git \
    libxml2 \
    unixodbc-dev \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Kafka command-line tools
RUN wget -q https://archive.apache.org/dist/kafka/3.7.0/kafka_2.13-3.7.0.tgz && \
    tar -xzf kafka_2.13-3.7.0.tgz && \
    mv kafka_2.13-3.7.0 /opt/kafka && \
    rm kafka_2.13-3.7.0.tgz && \
    ln -s /opt/kafka/bin/kafka-topics.sh /usr/local/bin/kafka-topics.sh && \
    ln -s /opt/kafka/bin/kafka-console-producer.sh /usr/local/bin/kafka-console-producer.sh && \
    ln -s /opt/kafka/bin/kafka-console-consumer.sh /usr/local/bin/kafka-console-consumer.sh

# Try to install gcc/g++ but don't fail if it doesn't work (for Apple Silicon compatibility)
RUN apt-get update && \
    (apt-get install -y gcc g++ || echo "Warning: gcc/g++ installation failed, continuing without compilers...") && \
    rm -rf /var/lib/apt/lists/*

# Install IBM DB2 CLI driver (required for ibm_db) - only for x86_64
RUN if [ "$(uname -m)" != "aarch64" ]; then \
    mkdir -p /opt/ibm && \
    cd /opt/ibm && \
    wget https://public.dhe.ibm.com/ibmdl/export/pub/software/data/db2/drivers/odbc_cli/linuxx64_odbc_cli.tar.gz && \
    tar -xzf linuxx64_odbc_cli.tar.gz && \
    rm linuxx64_odbc_cli.tar.gz; \
    fi

# Set environment variables for IBM DB2
ENV IBM_DB_HOME=/opt/ibm/clidriver
ENV PATH=$PATH:$IBM_DB_HOME/bin
ENV LD_LIBRARY_PATH=$IBM_DB_HOME/lib

# Copy the requirements file from the correct location
COPY requirements.txt . 

# Install dependencies, excluding ibm_db on ARM64
RUN if [ "$(uname -m)" = "aarch64" ]; then \
        grep -v "ibm_db" requirements.txt > requirements-filtered.txt && \
        pip install --no-cache-dir --index-url https://pypi.org/simple -r requirements-filtered.txt; \
    else \
        pip install --no-cache-dir --index-url https://pypi.org/simple -r requirements.txt; \
    fi
