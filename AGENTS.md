# Deployment policy

Use rolling `latest` tags or major-version tags for third-party containers.
Each Jenkins deployment must pull fresh images for every service. Do not pin
release dates, digests, or local cached images as a deployment workaround.
Plane AIO uses its upstream rolling `stable` channel because no `latest` tag is published.

Exception: Plane MCP is a local development project with configurable image
variants for Claude, Gemini, and Codex A/B testing. Preserve `MCP_IMAGE` and the
development variant; do not change MCP behavior during infrastructure fixes.
