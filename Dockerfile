FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    git curl ca-certificates ripgrep ffmpeg \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

RUN curl -LsSf https://astral.sh/uv/install.sh | sh
ENV PATH="/root/.local/bin:$PATH"

# Pinned upstream revision. Change this one line to update Hermes; the previous
# value is your rollback. Leave unset (HERMES_REV=main) only if you deliberately
# want whatever HEAD happens to be at build time.
ARG HERMES_REV=cc4cab2f592e60a197e796506de9168f74baf3ea

RUN git clone https://github.com/NousResearch/hermes-agent.git /opt/hermes-agent \
    && git -C /opt/hermes-agent checkout --detach "${HERMES_REV}" \
    && git -C /opt/hermes-agent submodule update --init --recursive

WORKDIR /opt/hermes-agent
RUN uv venv venv --python 3.11 \
    && VIRTUAL_ENV=/opt/hermes-agent/venv uv pip install -e ".[all]"

ENV PATH="/opt/hermes-agent/venv/bin:$PATH"

# yt-dlp backs the YouTube/Bilibili paths in the agent-reach skill, which
# otherwise documents commands for a binary that isn't here. Verified working
# from Railway's egress IP (metadata + auto-subs) on 2026-07-30.
RUN VIRTUAL_ENV=/opt/hermes-agent/venv uv pip install yt-dlp==2026.7.4

RUN mkdir -p /root/.hermes/{cron,sessions,logs,memories,skills,pairing,hooks,image_cache,audio_cache} \
    && cp cli-config.yaml.example /root/.hermes/config.yaml \
    && touch /root/.hermes/.env

COPY auth_proxy.py /auth_proxy.py
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
