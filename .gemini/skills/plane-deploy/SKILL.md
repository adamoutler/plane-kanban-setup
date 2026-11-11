---
name: plane-deploy
description: Deployment and redeployment protocol for Plane AIO. Enforces the "Push-to-Deploy" mandate. Use when you need to rebuild Docker containers, update configuration, or redeploy the system.
---

# Plane AIO Deployment Protocol

## Mandate: No Local Docker Builds

**NEVER build Docker containers locally or run docker compose up locally in the project folder.**

Local builds bypass the Jenkins deployment pipeline, causing broken environments and destroying secret key contexts.

## Workflow: Push-to-Deploy

To redeploy or update Plane AIO, you MUST use the following workflow:

1. **Commit**: Stage changes and commit with a descriptive message.
   ```bash
   git add .
   git commit -m "Your descriptive message"
   ```
2. **Push and Monitor**: Use the custom alias `git p` which will push to master and immediately tail the Jenkins receipt file.
   ```bash
   git p
   ```
   If you don't use `git p`, manually trigger the monitoring script after pushing:
   ```bash
   git push origin master
   ./.gemini/skills/plane-deploy/scripts/wait-for-receipt.sh
   ```

## Verification

After deployment, always check the system health:
```bash
docker compose ps
docker compose logs --tail 50 plane-aio
cat /tmp/jenkins-receipt-plane.log
```