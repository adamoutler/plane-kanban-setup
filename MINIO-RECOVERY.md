# Deployment image updates

Jenkins pulls every Compose service with `--policy always` before deployment.
Upstream services use rolling latest or major-version tags:

- PostgreSQL: `postgres:15-alpine`
- Redis: `redis:7-alpine`
- RabbitMQ: `rabbitmq:3-management-alpine`
- MinIO server: `cgr.dev/chainguard/minio:latest`
- MinIO client: `cgr.dev/chainguard/minio-client:latest-dev` (includes the setup shell)
- Plane AIO: `makeplane/plane-aio-community:stable` (upstream rolling channel;
  upstream does not publish a `latest` tag)

Plane MCP is a local development project and keeps the configurable `MCP_IMAGE`
variant used for agent A/B testing. Do not replace that variant with a production
release tag or change its behavior as part of dependency updates.

The Chainguard server runs as root to retain access to the existing root-owned
`miniodata` volume. Bucket setup waits for readiness and fails on errors.

Before switching to Chainguard, the newer server was tested against a copy of
the existing data, including bucket listing and an object write/read/delete.
The pre-upgrade data copy and old image archive remain in `image-backups/`
for recovery only; deployment does not use those images.
