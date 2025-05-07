# Use a lightweight Python image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Install necessary dependencies
RUN pip install flask

# Copy the application code
COPY app.py /app/app.py

# Expose the port the app runs on
EXPOSE 5000

# Run the application
CMD ["python", "app.py"]