import express from 'express';
import fs from 'fs/promises';
import Docker from 'dockerode';
import { exec as execCb } from 'child_process';
import { promisify } from 'util';
import os from 'os';
import Ajv from 'ajv';

const exec = promisify(execCb);

const app = express();
const port = process.env.PORT || 4000;
const dockerSocket = process.env.DOCKER_SOCKET || '/var/run/docker.sock';
const caddyfilePath = process.env.CADDYFILE_PATH || '/app/Caddyfile';
const caddyAccessLog = process.env.CADDY_ACCESS_LOG || '/app/logs/access.log';
const caddyErrorLog = process.env.CADDY_ERROR_LOG || '/app/logs/error.log';
const docker = new Docker({ socketPath: dockerSocket });

let appsConfig = [];
let lastConfigLoad = null;

const ajv = new Ajv({ allErrors: true, strict: false });
const appsSchema = {
  type: 'array',
  items: {
    type: 'object',
    required: ['id', 'name'],
    properties: {
      id: { type: 'string' },
      name: { type: 'string' },
      description: { type: 'string' },
      url: { type: 'string' },
      healthUrl: { type: 'string' },
      frontendPort: { type: 'number' },
      backendPort: { type: 'number' },
      containers: { type: 'array', items: { type: 'string' } },
    },
    additionalProperties: true,
  },
};
const validateApps = ajv.compile(appsSchema);

async function loadConfig() {
  try {
    const data = await fs.readFile(new URL('./apps.config.json', import.meta.url));
    const parsed = JSON.parse(data.toString());
    const valid = validateApps(parsed);
    if (!valid) {
      console.error('apps.config.json failed validation', validateApps.errors);
      throw new Error('Invalid apps.config.json');
    }
    appsConfig = parsed;
    lastConfigLoad = new Date().toISOString();
  } catch (err) {
    console.error('Failed to load apps.config.json', err);
    appsConfig = [];
  }
}

function mapStatus(status) {
  if (!status) return 'unknown';
  const normalized = status.toLowerCase();
  if (['running', 'healthy'].includes(normalized)) return 'healthy';
  if (['exited', 'dead'].includes(normalized)) return 'stopped';
  if (['starting', 'restarting'].includes(normalized)) return 'starting';
  if (['unhealthy'].includes(normalized)) return 'unhealthy';
  return normalized;
}

async function inspectContainer(name) {
  try {
    const container = docker.getContainer(name);
    const info = await container.inspect();
    let memoryUsageBytes = null;
    let memoryLimitBytes = null;
    try {
      const stats = await container.stats({ stream: false });
      memoryUsageBytes = stats?.memory_stats?.usage ?? null;
      memoryLimitBytes = stats?.memory_stats?.limit ?? null;
    } catch (_err) {
      // Some runtimes deny stats; keep status available even without memory figures.
    }
    const baseStatus = info.State?.Status || 'unknown';
    const healthStatus = info.State?.Health?.Status;
    return {
      name,
      id: info.Id,
      shortId: info.Id ? info.Id.slice(0, 12) : null,
      imageId: info.Image,
      status: mapStatus(healthStatus || baseStatus),
      rawStatus: baseStatus,
      health: healthStatus || 'n/a',
      startedAt: info.State?.StartedAt,
      uptimeSeconds: info.State?.StartedAt ? Math.floor((Date.now() - Date.parse(info.State.StartedAt)) / 1000) : null,
      image: info.Config?.Image,
      memoryUsageBytes,
      memoryLimitBytes,
    };
  } catch (error) {
    if (error.statusCode === 404) {
      return { name, status: 'not_available', rawStatus: 'not found' };
    }
    console.error(`Error inspecting container ${name}`, error.message);
    return { name, status: 'error', rawStatus: error.message };
  }
}

function normalizeImageRepo(imageRef) {
  if (!imageRef || typeof imageRef !== 'string') return null;
  const withoutDigest = imageRef.split('@')[0];
  const lastSlash = withoutDigest.lastIndexOf('/');
  const lastColon = withoutDigest.lastIndexOf(':');
  const hasTag = lastColon > lastSlash;
  return hasTag ? withoutDigest.slice(0, lastColon) : withoutDigest;
}

async function collectResourceUsage(app, containers) {
  const runtimeMemoryBytes = containers.reduce((sum, c) => sum + (Number(c.memoryUsageBytes) || 0), 0);
  const runtimeMemoryLimitBytes = containers.reduce((sum, c) => sum + (Number(c.memoryLimitBytes) || 0), 0);

  const imageIdSet = new Set((containers || []).map(c => c.imageId).filter(Boolean));
  const imageRefSet = new Set((containers || []).map(c => c.image).filter(Boolean));
  const imageRepos = new Set(Array.from(imageRefSet).map(normalizeImageRepo).filter(Boolean));

  const appImages = [];
  const seenImageIds = new Set();
  for (const imageId of imageIdSet) {
    try {
      const details = await docker.getImage(imageId).inspect();
      if (!details?.Id || seenImageIds.has(details.Id)) continue;
      seenImageIds.add(details.Id);
      appImages.push({
        id: details.Id,
        sizeBytes: details.Size || 0,
        tags: details.RepoTags || [],
        created: details.Created || null,
      });
    } catch (_err) {
      // Ignore missing image metadata; continue with remaining images.
    }
  }

  let purgeCandidates = [];
  try {
    const allImages = await docker.listImages();
    purgeCandidates = allImages
      .filter(image => (image.Containers || 0) === 0)
      .filter(image => {
        const tags = image.RepoTags || [];
        return tags.some(tag => imageRepos.has(normalizeImageRepo(tag)));
      })
      .map(image => ({
        id: image.Id,
        shortId: image.Id ? image.Id.replace('sha256:', '').slice(0, 12) : 'unknown',
        sizeBytes: image.Size || 0,
        tags: image.RepoTags || [],
        created: image.Created ? new Date(image.Created * 1000).toISOString() : null,
        reason: 'Unused image for app repository (candidate for docker image prune/removal).',
      }));
  } catch (_err) {
    // Keep app status healthy even if image listing is unavailable.
  }

  const totalImageBytes = appImages.reduce((sum, image) => sum + (image.sizeBytes || 0), 0);
  const reclaimableBytes = purgeCandidates.reduce((sum, image) => sum + (image.sizeBytes || 0), 0);

  return {
    appId: app.id,
    runtimeMemoryBytes,
    runtimeMemoryLimitBytes,
    totalImageBytes,
    appImageCount: appImages.length,
    reclaimableBytes,
    purgeCandidatesCount: purgeCandidates.length,
    purgeCandidates,
  };
}

async function purgeAppUnusedImages(app) {
  const containers = await Promise.all((app.containers || []).map(inspectContainer));
  const usage = await collectResourceUsage(app, containers);
  const candidates = usage.purgeCandidates || [];
  const results = [];

  for (const candidate of candidates) {
    try {
      await docker.getImage(candidate.id).remove();
      results.push({
        id: candidate.id,
        tags: candidate.tags,
        sizeBytes: candidate.sizeBytes || 0,
        success: true,
      });
    } catch (err) {
      results.push({
        id: candidate.id,
        tags: candidate.tags,
        sizeBytes: candidate.sizeBytes || 0,
        success: false,
        error: err.message,
      });
    }
  }

  const removed = results.filter(r => r.success);
  const failed = results.filter(r => !r.success);
  const reclaimedBytes = removed.reduce((sum, r) => sum + (r.sizeBytes || 0), 0);

  return {
    totalCandidates: candidates.length,
    removedCount: removed.length,
    failedCount: failed.length,
    reclaimedBytes,
    results,
  };
}

async function checkHealth(url) {
  if (!url) return { status: 'not_configured' };
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 4000);
  try {
    const res = await fetch(url, { signal: controller.signal });
    clearTimeout(timeout);
    const ok = res.ok;
    return {
      status: ok ? 'healthy' : 'unhealthy',
      statusCode: res.status,
      ok,
      url,
    };
  } catch (error) {
    clearTimeout(timeout);
    return {
      status: 'down',
      error: error.name === 'AbortError' ? 'timeout' : error.message,
      url,
    };
  }
}

function computeOverall(containers, health) {
  if (!containers.length) return health?.status === 'healthy' ? 'healthy' : 'unknown';
  const hasMissing = containers.some(c => c.status === 'not_available');
  const hasError = containers.some(c => ['down', 'error', 'unhealthy'].includes(c.status));
  if (hasError) return 'degraded';
  if (hasMissing) return 'partial';
  if (health?.status && ['down', 'unhealthy'].includes(health.status)) return 'degraded';
  const allHealthy = containers.every(c => c.status === 'healthy');
  return allHealthy ? 'healthy' : 'partial';
}

async function buildAppStatus(app, options = {}) {
  const includeResourceUsage = !!options.includeResourceUsage;
  const containers = await Promise.all((app.containers || []).map(inspectContainer));
  const health = await checkHealth(app.healthUrl);
  const urlStatus = await verifyPublicUrl(app);
  const overall = computeOverall(containers, health);
  const resourceUsage = includeResourceUsage
    ? await collectResourceUsage(app, containers)
    : null;
  return {
    ...app,
    overall,
    health,
    urlStatus,
    containers,
    resourceUsage,
    lastChecked: new Date().toISOString(),
  };
}

async function doContainerAction(name, action) {
  const allowed = ['start', 'stop', 'restart'];
  if (!allowed.includes(action)) {
    return { success: false, name, action, error: 'Invalid action: ' + action };
  }
  const container = docker.getContainer(name);
  try {
    await container.inspect();
  } catch (err) {
    if (err.statusCode === 404) {
      return { success: false, name, action, error: 'Container not found.' };
    }
    return { success: false, name, action, error: 'Failed to inspect container: ' + err.message };
  }

  try {
    if (action === 'start') await container.start();
    else if (action === 'stop') await container.stop();
    else if (action === 'restart') await container.restart();
    
    const updated = await inspectContainer(name);
    return { success: true, name, action, result: 'ok', status: updated.status };
  } catch (err) {
    return { success: false, name, action, error: 'Failed to perform ' + action + ': ' + err.message };
  }
}

async function restartAppContainers(app) {
  const results = [];
  for (const name of app.containers || []) {
    const actionResult = await doContainerAction(name, 'restart');
    results.push(actionResult);
  }
  return results;
}

async function stopAppContainers(app) {
  const results = [];
  for (const name of app.containers || []) {
    const actionResult = await doContainerAction(name, 'stop');
    results.push(actionResult);
  }
  return results;
}

async function pullAndRestart(app) {
  const pullResults = [];
  for (const name of app.containers || []) {
    try {
      const container = await docker.getContainer(name).inspect();
      const image = container.Config?.Image;
      if (image) {
        const pullStream = await docker.pull(image);
        await new Promise((resolve, reject) => {
          docker.modem.followProgress(pullStream, (err) => err ? reject(err) : resolve());
        });
        pullResults.push({ success: true, name, image, action: 'pull' });
      } else {
        pullResults.push({ success: false, name, error: 'Image not found for container ' + name, action: 'pull' });
      }
    } catch (err) {
      pullResults.push({ success: false, name, error: err.message, action: 'pull' });
    }
  }
  const restartResults = await restartAppContainers(app);
  return { pull: pullResults, restart: restartResults };
}

async function verifyPublicUrl(app) {
  if (!app.url) return { status: 'not_configured' };
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 5000);
  try {
    const res = await fetch(app.url, { signal: controller.signal });
    clearTimeout(timeout);
    return { status: res.ok ? 'reachable' : 'unhealthy', statusCode: res.status };
  } catch (err) {
    clearTimeout(timeout);
    const errorMessage = err.name === 'AbortError' ? 'timeout' : (typeof err.message === 'string' ? err.message : String(err));
    return { status: 'unreachable', error: errorMessage };
  }
}

async function runCaddyAdapt() {
  try {
    const { stdout } = await exec(`caddy adapt --config ${caddyfilePath} --pretty --validate`);
    const parsed = JSON.parse(stdout);
    const stats = await fs.stat(caddyfilePath);
    const routes = extractRoutes(parsed);
    return { status: 'ok', lastReload: stats.mtime.toISOString(), routes, raw: parsed };
  } catch (err) {
    return { status: 'error', error: err.message, raw: null };
  }
}

function extractRoutes(adaptedJson) {
  if (!adaptedJson || !adaptedJson.apps || !adaptedJson.apps.http) return [];
  const servers = adaptedJson.apps.http.servers || {};
  const routes = [];
  Object.values(servers).forEach(server => {
    (server.routes || []).forEach(r => {
      const hosts = (r.match || []).flatMap(m => m.host || []);
      const upstreams = (r.handle || [])
        .filter(h => h.handler === 'reverse_proxy')
        .flatMap(h => h.upstreams || [])
        .map(u => u.dial);
      if (hosts.length || upstreams.length) {
        routes.push({ hosts, upstreams });
      }
    });
  });
  return routes;
}

async function tailLog(filePath, lines = 200) {
  try {
    const { stdout } = await exec(`tail -n ${lines} ${filePath}`);
    return { success: true, data: stdout.split('\n').filter(Boolean) };
  } catch (err) {
    return { success: false, error: err.message };
  }
}

function toPercent(value, total) {
  if (!Number.isFinite(value) || !Number.isFinite(total) || total <= 0) return null;
  return Number(((value / total) * 100).toFixed(1));
}

function snapshotCpuTimes() {
  const cpus = os.cpus() || [];
  return cpus.reduce((acc, cpu) => {
    const t = cpu.times || {};
    acc.user += t.user || 0;
    acc.nice += t.nice || 0;
    acc.sys += t.sys || 0;
    acc.idle += t.idle || 0;
    acc.irq += t.irq || 0;
    return acc;
  }, { user: 0, nice: 0, sys: 0, idle: 0, irq: 0 });
}

async function getCpuUsagePercent(sampleMs = 250) {
  const start = snapshotCpuTimes();
  await new Promise(resolve => setTimeout(resolve, sampleMs));
  const end = snapshotCpuTimes();
  const startTotal = start.user + start.nice + start.sys + start.idle + start.irq;
  const endTotal = end.user + end.nice + end.sys + end.idle + end.irq;
  const totalDiff = endTotal - startTotal;
  const idleDiff = end.idle - start.idle;
  if (totalDiff <= 0) return null;
  return Number((((totalDiff - idleDiff) / totalDiff) * 100).toFixed(1));
}

async function getDiskStats(path = '/') {
  try {
    const { stdout } = await exec(`df -kP ${path}`);
    const lines = stdout.trim().split('\n');
    const dataLine = lines[lines.length - 1] || '';
    const parts = dataLine.trim().split(/\s+/);
    if (parts.length < 6) return null;
    const totalKB = Number(parts[1]);
    const usedKB = Number(parts[2]);
    const availableKB = Number(parts[3]);
    return {
      mount: parts[5],
      totalBytes: Number.isFinite(totalKB) ? totalKB * 1024 : null,
      usedBytes: Number.isFinite(usedKB) ? usedKB * 1024 : null,
      availableBytes: Number.isFinite(availableKB) ? availableKB * 1024 : null,
      usedPercent: toPercent(usedKB, totalKB),
    };
  } catch (_err) {
    return null;
  }
}

async function getSystemStatus() {
  const cpuUsagePercent = await getCpuUsagePercent();
  const totalMemoryBytes = os.totalmem();
  const freeMemoryBytes = os.freemem();
  const usedMemoryBytes = totalMemoryBytes - freeMemoryBytes;
  const memoryUsagePercent = toPercent(usedMemoryBytes, totalMemoryBytes);
  const disk = await getDiskStats('/');

  return {
    status: 'ok',
    hostname: os.hostname(),
    checkedAt: new Date().toISOString(),
    cpu: {
      usagePercent: cpuUsagePercent,
      cores: (os.cpus() || []).length,
    },
    memory: {
      totalBytes: totalMemoryBytes,
      usedBytes: usedMemoryBytes,
      freeBytes: freeMemoryBytes,
      usagePercent: memoryUsagePercent,
    },
    disk: disk || {
      mount: '/',
      totalBytes: null,
      usedBytes: null,
      availableBytes: null,
      usedPercent: null,
    },
    uptimeSeconds: os.uptime(),
  };
}

app.use(express.json());
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,POST,OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');
  if (req.method === 'OPTIONS') return res.sendStatus(204);
  next();
});

app.get('/api/apps', async (_req, res) => {
  await loadConfig();
  const results = await Promise.all(appsConfig.map(app => buildAppStatus(app, { includeResourceUsage: false })));
  res.json({ apps: results });
});

app.get('/api/caddy', async (_req, res) => {
  const result = await runCaddyAdapt();
  res.json(result);
});

app.get('/api/system', async (_req, res) => {
  try {
    const status = await getSystemStatus();
    res.json(status);
  } catch (err) {
    res.status(500).json({ status: 'error', error: err.message });
  }
});

app.get('/api/caddy/logs', async (req, res) => {
  const type = req.query.type === 'error' ? 'error' : 'access';
  const lines = Math.min(parseInt(req.query.lines, 10) || 200, 1000);
  const file = type === 'error' ? caddyErrorLog : caddyAccessLog;
  const result = await tailLog(file, lines);
  if (!result.success) return res.status(500).json({ error: result.error });
  res.json({ type, lines: result.data.length, log: result.data });
});

app.get('/api/apps/:id', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  const result = await buildAppStatus(appConfig, { includeResourceUsage: true });
  res.json(result);
});

app.post('/api/apps/:id/refresh', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  const result = await buildAppStatus(appConfig, { includeResourceUsage: true });
  res.json(result);
});

app.post('/api/apps/:id/restart', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  try {
    const result = await restartAppContainers(appConfig);
    res.json({ result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/apps/:id/restart-app', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  try {
    const result = await restartAppContainers(appConfig);
    res.json({ result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/apps/:id/pull-restart', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  try {
    const result = await pullAndRestart(appConfig);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/apps/:id/pull-restart-app', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  try {
    const result = await pullAndRestart(appConfig);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/apps/:id/stop', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  try {
    const result = await stopAppContainers(appConfig);
    res.json({ result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/apps/:id/stop-app', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  try {
    const result = await stopAppContainers(appConfig);
    res.json({ result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/api/apps/:id/verify-url', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  const result = await verifyPublicUrl(appConfig);
  res.json(result);
});

app.post('/api/apps/:id/verify-url', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  const result = await verifyPublicUrl(appConfig);
  res.json(result);
});

app.post('/api/apps/:id/verify-public', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  const result = await verifyPublicUrl(appConfig);
  res.json(result);
});

app.post('/api/apps/:id/purge-images', async (req, res) => {
  await loadConfig();
  const appConfig = appsConfig.find(a => a.id === req.params.id);
  if (!appConfig) return res.status(404).json({ error: 'App not found' });
  try {
    const result = await purgeAppUnusedImages(appConfig);
    res.json({
      message: `Purge complete. Removed ${result.removedCount} image(s), failed ${result.failedCount}.`,
      ...result,
    });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post('/api/containers/:name/:action', async (req, res) => {
  const { name, action } = req.params;
  try {
    const result = await doContainerAction(name, action);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', time: new Date().toISOString(), lastConfigLoad });
});

app.listen(port, () => {
  console.log(`Status API listening on ${port}`);
});

await loadConfig();
