# Credentials Management Plan

This plan outlines how to securely store and reapply sensitive credentials (.env files) when restoring the infrastructure on a new VPS.

## 1. Storage Strategy

Since `.env` files are excluded from Git for security, they must be backed up separately.

### Option A: Local Secure Backup (Recommended)
Store all production `.env` files in a local, encrypted archive on your personal machine or a secure storage location (e.g., 1Password, Bitwarden, encrypted USB drive).

**Action:** Run the following command on the *current* server to bundle all secrets:

```bash
# Create a tarball of all .env files (excluding examples and node_modules)
find apps/ -name ".env*" -not -name "*.example" -not -path "*/node_modules/*" | tar -czvf secrets_backup_$(date +%Y%m%d).tar.gz -T -
```

Download `secrets_backup_YYYYMMDD.tar.gz` to your secure storage.

### Option B: Cloud Secrets Manager (Advanced)
For a more automated approach, use a secrets manager (like HashiCorp Vault, AWS Secrets Manager, or Doppler) to inject secrets at runtime. This is overkill for a single VPS but good for scaling.

## 2. Restoration Process

When setting up a new VPS using the `setup_vps.sh` script:

1.  **Transfer Secrets**: Upload your `secrets_backup_YYYYMMDD.tar.gz` to the new server's `/home/munaim/srv/` directory.
    ```bash
    scp secrets_backup.tar.gz munaim@new-vps-ip:/home/munaim/srv/
    ```

2.  **Extract Secrets**:
    ```bash
    cd /home/munaim/srv
    tar -xzvf secrets_backup.tar.gz
    ```

3.  **Verify Placement**:
    Ensure the `.env` files are back in their respective application folders:
    *   `apps/lims/.env`
    *   `apps/radreport/.env`
    *   `apps/dashboard/.env`
    *   etc.

## 3. Credential Rotation (Best Practice)

If you are restoring because of a compromise, **DO NOT** reuse the old `.env` files blindly.
*   Generate new `SECRET_KEY`s.
*   Update database passwords in both the `.env` file and the database user.
*   Rotate API keys for external services (AWS, Twilio, etc.).

## 4. Emergency "Blank Slate" Restoration

If you lose the `.env` backups, you must recreate them using the `.env.example` files present in each repository:

1.  `cp apps/lims/.env.example apps/lims/.env`
2.  Edit `apps/lims/.env` and manually fill in:
    *   Database credentials (must match what you set in the new DB container).
    *   Django Secret Keys.
    *   Domain names.

---
**Verification of Current State:**
*   [x] All submodules are synced.
*   [x] Working tree is clean.
*   [x] `setup_vps.sh` is present and committed.
*   [x] `.env.example` files exist for guidance.
