# Build stage
FROM python:3.14-slim AS builder

WORKDIR /app

# Copy only the requirements file first to leverage Docker cache
COPY src/requirements.txt .

# Install dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application code
COPY src/ .

# Runtime stage
FROM python:3.14-slim

WORKDIR /app

# Copy installed dependencies from builder stage
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages

# Copy the application code
COPY --from=builder /app .

# Run the application
CMD ["python", "main.py"]