FROM python:3.10-slim AS base

RUN apt-get update \
    && apt-get install --no-install-recommends -y git jq \
    && rm -rf /var/lib/apt/lists/* \
    && ln -s /usr/local/bin/python3 /usr/bin/python3 \
    && git config --system user.name "HCHAIN Demo" \
    && git config --system user.email "demo@hchain.local" \
    && useradd --create-home --uid 10001 hchain

WORKDIR /app

COPY --chown=hchain:hchain . .

ENV DEMO_PAUSE=0

FROM base AS demo

USER hchain

CMD ["bash", "scripts/demo.sh"]

FROM base AS test

RUN pip install --no-cache-dir pytest==9.0.2

USER hchain

CMD ["pytest", "-q"]
