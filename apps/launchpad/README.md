# Al-Shifa Launchpad: Service Dashboard

The Al-Shifa Launchpad is a mission-critical operations console designed for monitoring and managing the health and status of various internal applications. It provides a status-first, insight-driven, and low-cognitive-load interface for DevOps and NOC teams to efficiently oversee the service ecosystem.

## Mission
To refactor the Al-Shifa “Launchpad” dashboard UI into a clean, analytical, enterprise-style operations console, preserving 100% existing operational functionality (start/stop/restart/health checks).

## Features
*   **Status-First Overview:** Global status bar indicating healthy, degraded, and down services.
*   **Key Performance Indicators (KPIs):** Quick insights into total containers, running, failed, uptime, and alerts.
*   **Progressive Disclosure:** Summary-first system cards; detailed information and actions are hidden until a specific service card is selected.
*   **Clear Health Badges:** Replaces ambiguous indicators with readable badges (HEALTHY, DEGRADED, DOWN).
*   **Emergency Actions:** Destructive actions require explicit confirmation, with "Stop All" requiring a typed confirmation phrase.
*   **Fast & Responsive UI:** Optimized to avoid unnecessary re-renders and designed for low cognitive load.

## Technologies Used

The project is built using a modern stack for both frontend and backend services, orchestrated with Docker Compose.

### Frontend
*   **Framework:** Vue.js 3
*   **Build Tool:** Vite
*   **Styling:** Custom CSS with design tokens for a consistent dark enterprise palette.
*   **Deployment Server:** Nginx (serving static assets)

### Backend (Status API)
*   **Runtime:** Node.js
*   **Web Framework:** Express.js
*   **Docker Interaction:** Dockerode (communicates with the Docker daemon to get container status and perform actions).
*   **Configuration:** `api/apps.config.json` for monitored application definitions.

### Infrastructure & Orchestration
*   **Containerization:** Docker
*   **Orchestration:** Docker Compose (defines and runs the multi-container Docker application).
*   **Reverse Proxy:** Caddy (for external routing and SSL termination).

## Architecture

The Al-Shifa Launchpad comprises several interconnected services:

*   **`status-api` (Backend Service):**
    *   A Node.js Express server that acts as the central intelligence for service status.
    *   It reads application configurations from `api/apps.config.json`.
    *   Communicates with the Docker daemon (via mounted socket) to inspect container states.
    *   Performs HTTP health checks on configured application URLs.
    *   Exposes `/api` endpoints used by the frontend to retrieve status data and trigger container actions.

*   **`dashboard` (Frontend Service):**
    *   A Vue.js application, built by Vite into static HTML, CSS, and JavaScript assets.
    *   Served by an Nginx container.
    *   Fetches data from the `status-api` to render the dashboard UI.
    *   Provides user interaction for viewing details and performing actions on applications/containers.

*   **Docker Compose:**
    *   Manages the lifecycle of both the `status-api` and `dashboard` services.
    *   Defines their networking, volume mounts, and dependencies.

*   **Caddy (External Routing):**
    *   An external reverse proxy responsible for routing incoming HTTP(S) requests to the appropriate backend services.
    *   Specifically, `portal.alshifalab.pk` is configured in Caddy to route traffic to the `dashboard` service (Nginx) running on port `8013`.

```mermaid
graph TD
    User --> Caddy[Caddy Server (portal.alshifalab.pk)]
    Caddy --> Nginx[Nginx (dashboard:8013)]
    Nginx --> Frontend[Vue.js Frontend (www/dist)]
    Frontend -- /api --> Nginx
    Nginx -- Proxy --> StatusAPI[Node.js Status API (status-api:4000)]
    StatusAPI -- Docker Socket --> Docker[Docker Daemon]
    Docker -- Inspect & Control --> Containers[Application Containers]
    StatusAPI -- HTTP Check --> Applications[External Applications]
```

## Getting Started

Follow these steps to set up and run the Al-Shifa Launchpad locally using Docker Compose.

### Prerequisites
*   Docker Desktop or Docker Engine installed and running.
*   `docker compose` plugin (or `docker-compose` v1) available in your PATH.
*   `npm` installed (for frontend build).

### Setup and Run

1.  **Clone the repository (if not already done):**
    ```bash
    git clone <repository-url>
    cd alshifa-launchpad # or your project root directory
    ```

2.  **Build Frontend Assets:**
    Navigate into the `www` directory, install dependencies, and build the production-ready assets.
    ```bash
    cd www
    npm install
    npm run build
    cd .. # Navigate back to the project root
    ```

3.  **Deploy Docker Services:**
    From the project root directory, use Docker Compose to bring up the backend API and frontend Nginx services.
    ```bash
    docker compose down # Stop and remove any previously running containers
    docker compose build # Build Docker images (especially for status-api)
    docker compose up -d # Start services in detached mode
    ```

4.  **Access the Dashboard:**
    The dashboard should now be accessible. If you have Caddy configured on your host machine to route `portal.alshifalab.pk` to `localhost:8013`, you can access it at:
    `https://portal.alshifalab.pk`

    Alternatively, you can configure your `/etc/hosts` file (or `C:\Windows\System32\drivers\etc\hosts` on Windows) to point `portal.alshifalab.pk` to `127.0.0.1` for local development if Caddy is running elsewhere or not used locally.

## Development

### Frontend Development
*   The frontend code resides in the `www/` directory.
*   To start the Vite development server (with hot-module reloading), navigate to `www/` and run:
    ```bash
    cd www
    npm run dev
    ```
*   This will typically serve the app on `http://localhost:5173` (or similar). You'll need to configure your local Caddy or Nginx setup to proxy requests to this port for API calls to function correctly during development, or configure Vite's proxy.

### Backend Development
*   The backend code is in the `api/` directory.
*   Ensure Docker is running, as the `status-api` directly interacts with the Docker daemon.
*   You can run the Node.js API directly (ensure `DOCKER_SOCKET` environment variable is set if not `/var/run/docker.sock`):
    ```bash
    cd api
    npm install
    npm start # Or `node server.js`
    ```
*   The API listens on port 4000 by default.

## Deployment Conventions

*   **Automated Builds:** Frontend assets are built into the `www/dist` directory using Vite.
*   **Dockerized Services:** Both frontend and backend are deployed as Docker containers.
*   **Docker Compose for Services:** `docker-compose.yml` defines the production service setup.
*   **Caddy as Edge Proxy:** Caddy is expected to handle ingress traffic, SSL termination, and routing to internal Docker Compose services.

## Troubleshooting

*   **`docker compose` vs `docker-compose`:** Depending on your Docker installation, you might need to use `docker-compose` (with a hyphen) instead of `docker compose` (with a space).
*   **`Vue is not defined` error:** Ensure the frontend assets are built (`npm run build` in `www/`) and Nginx is serving the `www/dist` directory. Also, verify `www/js/main.js` correctly imports `createApp` from 'vue'.
*   **MIME type errors:** Ensure the frontend is built and Nginx is serving the `www/dist` directory. The `nginx.conf` and `docker-compose.yml` should be correctly configured to mount `www/dist` as Nginx's root.
*   **API connectivity issues:** Check Docker Compose logs (`docker compose logs status-api`) and Nginx error logs. Ensure the `status-api` container has access to the Docker socket.

---
_Generated by Gemini CLI_
