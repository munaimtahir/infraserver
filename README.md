# Infrastructure Server Repository

**Al-Shifa Lab VPS Infrastructure Management**

This repository contains the complete infrastructure configuration for the Al-Shifa Lab VPS server, including all applications, proxy configuration, operational tools, and backup systems.

---

## 📁 Repository Structure

```
/home/munaim/srv/
├── apps/                          # Application repositories (git submodules)
│   ├── lims/                      # Laboratory Information Management System
│   ├── accred-ai/                 # Accreditation AI (PHC)
│   ├── consult/                   # Consultation Platform
│   ├── fmu-platform/              # FMU Platform (SIMS)
│   ├── pgsims/                    # PGSIMS
│   └── radreport/                 # Radiology Report (RIMS)
│
├── proxy/                         # Reverse proxy configuration
│   └── caddy/                     # Caddy server configuration
│
├── observability/                 # Monitoring and observability stack
│   ├── prometheus/                # Metrics collection
│   └── grafana/                   # Metrics visualization
│
├── ops/                           # Operational tools and scripts
│   ├── bin/                       # Operational scripts
│   ├── scripts/                   # Helper scripts
│   ├── systemd/                   # Systemd service files
│   ├── backups/                   # Backup storage
│   ├── logs/                      # Operational logs
│   ├── config/                    # Ops configuration
│   ├── archive/                   # Important archives
│   └── docs/                      # Operational documentation
│
├── backups/                       # Application backup storage
├── logs/                          # System-wide logs
├── envlogic/                      # Environment management scripts
│
├── CREDENTIALS_PLAN.md            # Credential management strategy
├── PORTS_REGISTRY.md              # Port allocation registry
├── setup_vps.sh                   # VPS setup and restoration script
└── truth.sh                       # System status and health check script
```

---

## 🚀 Quick Start

### Initial VPS Setup

To set up a new VPS from this repository:

```bash
# Clone the repository
git clone --recurse-submodules <repository-url> /home/munaim/srv
cd /home/munaim/srv

# Run the VPS setup script
./setup_vps.sh

# Restore environment files (credentials)
cd envlogic
./restore_env.sh
```

### Application Management

All applications are managed through Docker Compose. Use the operational scripts in `ops/bin/` for safe management:

```bash
# Start a production application
ops-prod-up <app-name>

# Stop a production application
ops-prod-down <app-name>

# Check system status
./truth.sh
```

---

## 📦 Applications

### 1. LIMS (Laboratory Information Management System)
- **Domains:** lims.alshifalab.pk, portal.alshifalab.pk
- **API:** api.lims.alshifalab.pk
- **Port:** 127.0.0.1:8013
- **Stack:** Django + React + PostgreSQL + Redis + Celery

### 2. RIMS (Radiology Information Management System)
- **Domains:** rims.alshifalab.pk
- **API:** api.rims.alshifalab.pk
- **Port:** 127.0.0.1:8081 (frontend), 8015 (backend)
- **Stack:** Django + React + PostgreSQL

### 3. SIMS (Student Information Management System)
- **Domains:** sims.alshifalab.pk, sims.pmc.edu.pk
- **API:** api.sims.alshifalab.pk
- **Port:** 127.0.0.1:8080 (frontend), 8010 (backend)
- **Stack:** Django + React + PostgreSQL + Redis

### 4. PGSIMS (Postgraduate SIMS)
- **Domains:** pgsims.alshifalab.pk, pgsims.pmc.edu.pk
- **API:** api.pgsims.alshifalab.pk
- **Port:** 127.0.0.1:8082 (frontend), 8014 (backend)
- **Stack:** Django + Next.js + PostgreSQL + Redis + Celery

### 5. Consult (Consultation Platform)
- **Domains:** consult.alshifalab.pk
- **API:** api.consult.alshifalab.pk
- **Port:** 127.0.0.1:8011
- **Stack:** Django + React + PostgreSQL + Redis + Nginx

### 6. PHC (Primary Health Care / Accred-AI)
- **Domains:** phc.alshifalab.pk
- **API:** api.phc.alshifalab.pk
- **Port:** 127.0.0.1:8016
- **Stack:** Django + React + PostgreSQL + Nginx

---

## 🔧 Infrastructure Components

### Reverse Proxy (Caddy)
- **Location:** `/home/munaim/srv/proxy/caddy/`
- **Service:** systemd service `caddy.service`
- **Configuration:** `/etc/caddy/Caddyfile` (symlinked to proxy/caddy/Caddyfile)
- **Ports:** 80 (HTTP), 443 (HTTPS)
- **Features:** Automatic HTTPS, domain routing, API routing

### Observability Stack
- **Prometheus:** Metrics collection and storage
- **Grafana:** Metrics visualization and dashboards
- **Location:** `/home/munaim/srv/observability/`

### Backup System
- **Automated Backups:** Nightly systemd timer
- **Retention:** 14 days daily, 8 weeks weekly
- **Storage:** `/home/munaim/srv/ops/backups/`
- **Offsite:** Configurable via `ops/backup.env`

---

## 📚 Key Documentation

### Configuration
- **CREDENTIALS_PLAN.md** - How credentials are managed and restored
- **PORTS_REGISTRY.md** - Port allocation for all services

### Operational
- **ops/docs/README_OPS.md** - Operational overview
- **ops/docs/SOP_BackupRestore.md** - Backup and restore procedures
- **ops/docs/DR_RestoreDrill_Checklist.md** - Disaster recovery checklist
- **ops/docs/OPS_DASHBOARD_README.md** - Ops dashboard documentation

---

## 🔐 Security

### Credentials Management
All sensitive credentials (`.env` files) are:
1. **Excluded from git** (via `.gitignore`)
2. **Backed up separately** using `envlogic/backup_env.sh`
3. **Restored during setup** using `envlogic/restore_env.sh`

See `CREDENTIALS_PLAN.md` for detailed credential management strategy.

### Superadmin Access
Default superadmin credentials for all applications:
- **Username:** admin
- **Password:** admin123

⚠️ **Change these credentials in production!**

---

## 🛠️ Operational Scripts

### System Management
- `./truth.sh` - System status and health check
- `./setup_vps.sh` - VPS setup and restoration

### Application Management (in ops/bin/)
- `ops-status` - Status overview of running projects/volumes
- `ops-prod-up <app>` - Start a production app safely
- `ops-prod-down <app>` - Stop a production app (volumes kept)
- `ops-dev-up <app>` - Start a development version of an app
- `ops-dev-reset-hard <app>` - Wipe dev data and rebuild (blocks prod)

### Backup Management (in ops/bin/)
- `ops-backup-now` - Trigger manual backup of all prod DBs
- `ops-restore-sandbox <file>` - Restore backup into temporary container

### Environment Management (in envlogic/)
- `backup_env.sh` - Backup all .env files
- `restore_env.sh` - Restore .env files from backup

---

## 🚨 Disaster Recovery

### Quick Recovery Steps

1. **Provision new VPS** with Ubuntu 24.04
2. **Clone repository:**
   ```bash
   git clone --recurse-submodules <repo-url> /home/munaim/srv
   cd /home/munaim/srv
   ```
3. **Run setup script:**
   ```bash
   ./setup_vps.sh
   ```
4. **Restore credentials:**
   ```bash
   cd envlogic
   ./restore_env.sh
   ```
5. **Start applications:**
   ```bash
   ops-prod-up lims
   ops-prod-up rims
   # ... etc for other apps
   ```
6. **Verify system:**
   ```bash
   ./truth.sh
   ```

### Database Restoration

If database restoration is needed:
```bash
# Restore from backup
ops-restore-sandbox /path/to/backup.sql.gz

# Or restore directly to production (CAREFUL!)
zcat backup.sql.gz | docker exec -i <container> psql -U <user> <db>
```

---

## 📊 Monitoring

### Health Checks
- **System Status:** `./truth.sh`
- **Ops Dashboard:** Access via configured domain
- **Prometheus:** Metrics at configured endpoint
- **Grafana:** Dashboards at configured endpoint

### Logs
- **Application Logs:** `docker compose logs -f <service>`
- **Operational Logs:** `/home/munaim/srv/ops/logs/`
- **System Logs:** `/home/munaim/srv/logs/`
- **Caddy Logs:** `journalctl -u caddy -f`

---

## 🔄 Updates and Maintenance

### Updating Applications
```bash
cd /home/munaim/srv/apps/<app-name>
git pull
docker compose -f docker-compose.prod.yml up -d --build
```

### Updating Infrastructure
```bash
cd /home/munaim/srv
git pull --recurse-submodules
# Review changes and restart affected services
```

### Backup Verification
Regular DR drills are recommended. Use the checklist:
```bash
cat ops/docs/DR_RestoreDrill_Checklist.md
```

---

## 🤝 Contributing

This is an infrastructure repository. Changes should be:
1. **Tested** in development environment first
2. **Documented** in relevant docs
3. **Committed** with clear commit messages
4. **Deployed** during maintenance windows

---

## 📞 Support

For operational issues:
1. Check `./truth.sh` for system status
2. Review logs in `ops/logs/`
3. Consult operational documentation in `ops/docs/`
4. Check application-specific README files

---

## 📝 License

Internal use only - Al-Shifa Lab Infrastructure

---

**Last Updated:** 2026-02-15  
**Maintained By:** Infrastructure Team
