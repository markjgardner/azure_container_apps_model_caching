# Use the official Python base image
FROM python:3.9-slim

# Set environment variables to prevent Python from writing .pyc files and to buffer output
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl \
    && rm -rf /var/lib/apt/lists/*

# Install the latest version of Hugging Face CLI
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir huggingface_hub

#Install azcopy
RUN curl -sL https://aka.ms/downloadazcopy-v10-linux | tar xz -C /tmp && mv /tmp/azcopy_linux_amd64_*/azcopy /usr/local/bin/azcopy

# Set the working directory
WORKDIR /workspace

# Default command to run when the container starts
CMD ["bash"]