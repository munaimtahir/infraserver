# VPS Server Configuration Review

**Date:** February 13, 2026  
**User:** munaim  
**Home Directory:** `/home/munaim`  
**Content Directory:** `/home/munaim/srv`

---

## 📁 Directory Structure

```
/home/munaim/srv/
├── apps/          # All application repositories
├── backups/       # Automated offsite & local backups
├── dashboard/     # Al-Shifa Launchpad (Ops Management)
├── logs/          # System-wide operational logs
├── observability/ # Monitoring stack (Prometheus/Grafana)
├── ops/           # Operational scripts and control logic
└── proxy/         # Centralized Caddy reverse proxy
```

---

## 🗂️ Applications Overview

### 1. **lims** (Laboratory Information Management System)
- **Location:** `/home/munaim/srv/apps/lims/`
- **Reverse Proxy:** Host-level Caddy
- **Status:** 
  - ✅ Fully integrated with central Caddy proxy.
  - ✅ Docker Compose orchestration active.

### 2. **accredivault** (Evidence & Accreditation Management)
- **Location:** `/home/munaim/srv/apps/accredivault/`
- **Status:** Integrated with MinIO for storage and central Caddy.

### 3. **dashboard** (Al-Shifa Launchpad)
- **Location:** `/home/munaim/srv/dashboard/`
- **Status:** Provides centralized control for starting/stopping all containers.

### 2. **accred-ai** (Accreditation AI)
- **Location:** `/home/munaim/srv/apps/accred-ai/`
- **Reverse Proxy:** Nginx (Docker container)
- **Port Mapping:** Ports 80 and 443 exposed directly
- **Status:** Uses Nginx for reverse proxy

### 3. **consult** (Consultation Platform)
- **Location:** `/home/munaim/srv/apps/consult/`
- **Reverse Proxy:** Nginx (Docker container) or Coolify Traefik
- **Port Mapping:** Port 3000 for frontend
- **Status:** Has multi-app deployment documentation

### 4. **fmu-platform** (FMU Platform)
- **Location:** `/home/munaim/srv/apps/fmu-platform/`
- **Status:** Has docker-compose.yml files

### 5. **pgsims** (PGSIMS)
- **Location:** `/home/munaim/srv/apps/pgsims/`
- **Status:** Has multiple docker-compose variants

### 6. **radreport** (Radiology Report)
- **Location:** `/home/munaim/srv/apps/radreport/`
- **Status:** Has docker-compose.yml files

---

## 🔍 Current Configuration Analysis

### Host-Level Services
- ❌ **Caddy:** Not installed on host system
- ❌ **Caddy Service:** No systemd service found
- ❌ **Caddy Config:** No configuration in `/etc/caddy/`

### Application-Level Reverse Proxies
- **lims:** Uses Caddy in Docker (port 8013) - expects host Caddy
- **accred-ai:** Uses Nginx in Docker (ports 80/443)
- **consult:** Uses Nginx or Coolify Traefik

### Port Conflicts
⚠️ **Potential Issues:**
- Multiple apps trying to use port 80/443 directly
- `accred-ai` exposes ports 80 and 443
- `lims` uses port 8013 internally but expects host Caddy
- Need centralized routing strategy

---

## 🎯 Target State Achieved
- **IP-based and Domain routing** active.
- **Caddy-based routing** at host level fully operational.
- **Centralized configuration** in `/home/munaim/srv/proxy/caddy/`.
- All apps (LIMS, Accredivault, etc.) accessible via central proxy.

---

## 📋 Next Steps

### 1. Create Proxy Directory Structure
```bash
/home/munaim/srv/proxy/
├── Caddyfile          # Main Caddy configuration
├── apps/              # Per-app Caddy configs
│   ├── lims.conf
│   ├── accred-ai.conf
│   ├── consult.conf
│   ├── fmu-platform.conf
│   ├── pgsims.conf
│   └── radreport.conf
└── README.md          # Documentation
```

### 2. Install Caddy on Host
- Install Caddy server on the host system
- Configure systemd service
- Set up automatic HTTPS (if domains available) or IP-based access

### 3. Update Application Configurations
- Modify docker-compose files to avoid port conflicts
- Update apps to use internal ports only
- Configure host Caddy to route to appropriate internal ports

### 4. IP-Based Routing Strategy
- Route by path: `/lims/*`, `/accred-ai/*`, etc.
- OR route by subdomain (if DNS configured)
- OR route by port mapping (not recommended for production)

---

## 🔧 Key Findings

### LIMS App (Most Advanced)
- Already has Caddyfile configured
- Expects host-level Caddy for HTTPS termination
- Internal Caddy on port 8013 handles routing to services
- Well-documented deployment process

### Other Apps
- Use Nginx or expect external reverse proxy
- Need configuration updates for IP-based access
- May need ALLOWED_HOSTS updates to include IP addresses

---

## 📝 Notes

1. **Proxy folder doesn't exist yet** - needs to be created
2. **Caddy not installed** - needs installation and configuration
3. **Port conflicts** - need to resolve before deployment
4. **IP-based access** - apps need ALLOWED_HOSTS updates
5. **Centralized routing** - Caddy at host level will route to all apps

---

## 🚀 Ready for Next Phase

Once you confirm this review, we can proceed with:
1. Creating the `/home/munaim/srv/proxy/` directory structure
2. Installing and configuring Caddy
3. Creating Caddyfile configurations for IP-based routing
4. Updating application configurations to work with new setup
