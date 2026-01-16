FROM python:3.11-slim

# List files first (debug)
RUN echo "Files in context:" && ls -la /tmp/ && ls -la .

WORKDIR /app

# Copy only requirements first
COPY requirements.txt .
RUN ls -la requirements.txt  # Debug
RUN pip install -r requirements.txt

# Copy rest
COPY . .
RUN ls -la /app/api/  # Debug

EXPOSE 8080
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8080"]
