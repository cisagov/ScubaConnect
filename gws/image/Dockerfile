FROM python:3.13-slim

# needed when installing ScubaGoggles directly from git
RUN apt-get update && apt-get install -y git

RUN useradd --create-home user
USER user

# Allow statements and log messages to immediately appear in the Cloud Run logs
ENV PYTHONUNBUFFERED=True
ENV APP_HOME=/app
ENV PATH="/home/user/.local/bin:${PATH}"
WORKDIR $APP_HOME
COPY . ./

# Install dependencies
RUN pip install --no-cache-dir --upgrade pip
RUN pip install --no-cache-dir -r requirements.txt
RUN scubagoggles setup

CMD ["python3", "main.py"]
