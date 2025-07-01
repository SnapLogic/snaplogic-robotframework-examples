FROM python:3.12.7-slim-bookworm 

# Set the working directory
WORKDIR /app
# Copy the requirements file and install dependencies
COPY requirements.txt . 
RUN pip install --no-cache-dir --index-url https://pypi.org/simple -r requirements.txt





