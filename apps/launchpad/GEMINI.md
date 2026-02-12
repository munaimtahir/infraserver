# Project Overview

The project is an Al-Shifa “Launchpad” dashboard, designed as a status-first, insight-driven operations console. It monitors the health and status of various internal applications (like RIMS, LIMS, SIMS, etc.) through a centralized API. The frontend provides a clean, analytical, enterprise-style user interface, while the backend collects status information from Docker containers and performs health checks. The entire application is orchestrated using Docker Compose and exposed via a Caddy reverse proxy.

## Main Technologies
*   **Frontend:** Vue.js 3, Vite (for building), HTML, CSS (with custom design tokens).
*   **Backend:** Node.js, Express.js, Dockerode (for Docker API interaction).
*   **Orchestration:** Docker Compose.
*   **Web Server/Reverse Proxy:** Nginx (for serving frontend), Caddy (for external routing).

## Architecture
*   **`status-api` (Backend):** A Node.js Express server that interacts with the Docker daemon to get container statuses and performs HTTP health checks on configured applications. It exposes `/api` endpoints for the frontend.
*   **`dashboard` (Frontend):** A Vue.js application served by an Nginx container. It consumes data from the `status-api` to display application health, KPIs, and provides actions (start/stop/restart containers). The application is built using Vite for production.
*   **Docker Compose:** Orchestrates both `status-api` and `dashboard` services, managing their networking and volumes.
*   **Caddy:** Acts as the external reverse proxy, routing incoming requests from `portal.alshifalab.pk` to the `dashboard` service (Nginx) and potentially other internal services.

# Building and Running

To build and run this project:

1.  **Navigate to the project root:** `/home/munaim/srv/apps/launchpad`

2.  **Build the Frontend Assets:**
    *   Navigate into the `www` directory: `cd www`
    *   Install frontend dependencies: `npm install`
    *   Build the production assets: `npm run build`
    *   Navigate back to the project root: `cd ..`

3.  **Deploy / Run Docker Services:**
    *   Stop any existing running containers for this project: `docker compose down`
    *   Build the Docker images (especially if there are changes in `api/` or `docker-compose.yml`): `docker compose build`
    *   Start the services in detached mode: `docker compose up -d`

4.  **Access the Application:**
    *   The application should be accessible via the URL configured in Caddy, which is `https://portal.alshifalab.pk`.

# Development Conventions

*   **Frontend:** Vue.js component-based architecture, utilizing Vite for development and bundling. Styling uses CSS with custom design tokens.
*   **Backend:** Node.js Express server, modularized functions for Docker interaction and health checks.
*   **Configuration:** Application-specific configurations are managed in `api/apps.config.json`.
*   **Containerization:** Docker for isolating services; Docker Compose for multi-service orchestration.
*   **API Contracts:** Adherence to established API endpoints for status retrieval and actions (`/api/apps`, `/api/containers`).
