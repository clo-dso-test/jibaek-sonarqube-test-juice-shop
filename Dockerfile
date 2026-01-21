FROM node:22-slim AS installer
WORKDIR /juice-shop

RUN apt-get update && apt-get install -y \
    git python3 python3-dev make g++ build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY package*.json ./

RUN --mount=type=cache,target=/root/.npm \
    npm install --omit=dev --ignore-scripts

COPY . .

RUN npm rebuild && npm run postinstall || true
RUN npm dedupe --omit=dev && \
    rm -rf frontend/node_modules frontend/.angular frontend/src/assets && \
    mkdir -p logs && \
    chown -R 65532 logs && \
    chgrp -R 0 ftp/ frontend/dist/ logs/ data/ i18n/ && \
    chmod -R g=u ftp/ frontend/dist/ logs/ data/ i18n/ && \
    rm data/chatbot/botDefaultTrainingData.json ftp/legal.md i18n/*.json || true

ARG CYCLONEDX_NPM_VERSION=latest
RUN npx @cyclonedx/cyclonedx-npm@$CYCLONEDX_NPM_VERSION --omit dev && \
    npm run sbom

FROM gcr.io/distroless/nodejs22-debian12
ARG BUILD_DATE
ARG VCS_REF
LABEL maintainer="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
    org.opencontainers.image.title="OWASP Juice Shop" \
    org.opencontainers.image.description="Probably the most modern and sophisticated insecure web application" \
    org.opencontainers.image.authors="Bjoern Kimminich <bjoern.kimminich@owasp.org>" \
    org.opencontainers.image.vendor="Open Worldwide Application Security Project" \
    org.opencontainers.image.documentation="https://help.owasp-juice.shop" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.version="19.1.1" \
    org.opencontainers.image.url="https://owasp-juice.shop" \
    org.opencontainers.image.source="https://github.com/juice-shop/juice-shop" \
    org.opencontainers.image.revision=$VCS_REF \
    org.opencontainers.image.created=$BUILD_DATE
WORKDIR /juice-shop
COPY --from=installer --chown=65532:0 /juice-shop .
USER 65532
EXPOSE 3000
CMD ["/juice-shop/build/app.js"]
