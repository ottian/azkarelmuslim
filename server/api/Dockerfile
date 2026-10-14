FROM ubuntu:24.04

RUN apt-get update \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends python3 ffmpeg ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server.py importer.py ./

ENV PYTHONUNBUFFERED=1
EXPOSE 8080
CMD ["python3", "server.py"]
