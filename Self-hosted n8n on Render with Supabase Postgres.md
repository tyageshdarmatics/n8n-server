Yes — you can deploy **self-hosted n8n on Render** with **Supabase Postgres** so your workflows and credentials survive restarts, but there are two important limits:

Render free web services **spin down after 15 minutes of inactivity** and can take about a minute to wake up again. Also, Render persistent disks are for **paid** services; without a disk, the local filesystem is ephemeral. ([Render][1])

That means the safe pattern is:

**Render free web service + Supabase Postgres + fixed `N8N_ENCRYPTION_KEY` + custom Docker image**

With that setup, when Render restarts or sleeps, your **database-backed workflows, executions metadata, and encrypted credentials** stay available, because n8n supports PostgreSQL and lets you provide a custom encryption key instead of storing a generated one only on local disk. ([n8n Docs][2])

## What you should build

You want one Render **Web Service** using Docker, not the native Node runtime, because you want custom tools like **FFmpeg** installed. Render supports deploying from a Dockerfile or a prebuilt image. ([Render][3])

## Before you start

You need:

* a GitHub repo for your n8n Docker setup
* a Supabase project
* your own long random encryption key
* basic Render environment variables

For Supabase, get the Postgres connection string from the **Connect** panel. Supabase notes that the default direct connection is IPv6-only, and for platforms where networking can vary, pooled connection strings are available via Supavisor. ([Supabase][4])

## Folder structure

Create a new repo like this:

```text
n8n-render/
  Dockerfile
  .dockerignore
```

## Dockerfile

Use this:

```dockerfile
FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache \
    ffmpeg \
    bash \
    curl \
    git \
    python3 \
    py3-pip

USER node
```

Why this works:

* official n8n image as base
* adds FFmpeg and a few common tools
* keeps n8n as the main app

## .dockerignore

```text
node_modules
.git
.gitignore
README.md
.env
```

## Create the Render web service

In Render:

1. New
2. Web Service
3. Connect your GitHub repo
4. Choose **Docker** deploy

Render supports Docker-based deploys for web services. ([Render][3])

## Render settings

Set these:

* **Environment**: Docker
* **Instance type**: Free
* **Auto deploy**: your choice

You do not need a build command or start command if Render is using your Dockerfile.

## Environment variables in Render

Add these one by one.

Use your actual domain in the URL values.

```text
N8N_HOST=your-service-name.onrender.com
N8N_PORT=10000
N8N_PROTOCOL=https
WEBHOOK_URL=https://your-service-name.onrender.com/
N8N_EDITOR_BASE_URL=https://your-service-name.onrender.com/
N8N_SECURE_COOKIE=true

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=YOUR_SUPABASE_HOST
DB_POSTGRESDB_PORT=6543
DB_POSTGRESDB_DATABASE=postgres
DB_POSTGRESDB_USER=YOUR_SUPABASE_USER
DB_POSTGRESDB_PASSWORD=YOUR_SUPABASE_PASSWORD
DB_POSTGRESDB_SSL_ENABLED=true

N8N_ENCRYPTION_KEY=put-a-long-random-secret-here
N8N_RUNNERS_ENABLED=true
GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata
```

n8n documents PostgreSQL support through environment variables, and also documents `N8N_ENCRYPTION_KEY` for preserving encrypted credentials across restarts and across instances. ([n8n Docs][2])

## Which Supabase host and port to use

In Supabase, open **Connect** and copy the pooled Postgres URI.

Usually for pooled connections you will see a host like:

```text
aws-0-<region>.pooler.supabase.com
```

and often port:

```text
6543
```

Supabase documents pooled connection strings and explains the pooler options in the Connect panel. ([Supabase][4])

## Important note about data safety

Your workflows and credentials are safe only if both are true:

1. n8n is using **Supabase Postgres**
2. `N8N_ENCRYPTION_KEY` stays the same forever

If you change or lose the encryption key, old encrypted credentials may become unreadable. n8n explicitly warns that this key is what protects stored credentials. ([n8n Docs][5])

## What is and is not preserved on free Render

Preserved:

* workflows in Postgres
* credentials in Postgres
* settings backed by database
* anything externalized to Supabase

Not preserved:

* files stored only on local disk
* anything saved only inside the container filesystem
* generated local encryption key if you did not set `N8N_ENCRYPTION_KEY`

Render says services have an ephemeral filesystem by default, and persistent disks require paid services. ([Render][6])

## So how do you avoid losing files?

Do not keep important files only inside Render local storage.

For binary files, use external storage such as:

* Supabase Storage
* S3-compatible storage
* Cloudinary
* upload the result immediately elsewhere

This is especially important if your workflows generate videos with FFmpeg.

## Health and wake-up behavior

On free Render, n8n will sleep after 15 minutes of inactivity. First load after sleep can be slow. That is normal on the free plan. ([Render][1])

## Custom installation beyond FFmpeg

If later you want more tools, just add them to the Dockerfile.

Example:

```dockerfile
FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache \
    ffmpeg \
    imagemagick \
    bash \
    curl \
    git \
    jq \
    python3 \
    py3-pip

USER node
```

If a tool is not available via `apk`, you can install it another way inside the Dockerfile.

## Recommended minimal secure setup

I recommend these extra env vars too:

```text
N8N_DIAGNOSTICS_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
```

And if you want basic auth in front of the editor:

```text
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=youradmin
N8N_BASIC_AUTH_PASSWORD=very-strong-password
```

Check the current n8n environment variable docs for the options you use. ([n8n Docs][7])

## Exact deployment flow

1. Create the repo with the Dockerfile above.
2. Push it to GitHub.
3. Create a Supabase project.
4. Copy the pooled Postgres host, user, password, port, and database from Supabase Connect. ([Supabase][4])
5. Create a Render Web Service from the repo using Docker. ([Render][3])
6. Add all the environment variables.
7. Deploy.
8. Open the Render URL.
9. Complete n8n owner setup.
10. Create one test workflow and verify it still exists after a manual redeploy.

## What to expect on free plan

This setup is good for personal use and testing. It is not ideal for 24/7 production because free Render services sleep and have ephemeral local storage. Render’s own docs say free services are not for production use. ([Render][1])

## Biggest mistake to avoid

Do not rely on:

* SQLite
* local `.n8n` folder in the container
* auto-generated encryption key
* local files as permanent storage

That is exactly how people lose workflows or credentials after redeploys.

## If you want, I’ll give you the next piece as a copy-paste bundle:

a complete `Dockerfile`, `render.yaml`, and the exact Render environment variable list filled in with placeholders for Supabase.

[1]: https://render.com/docs/free?utm_source=chatgpt.com "Deploy for Free – Render Docs"
[2]: https://docs.n8n.io/hosting/configuration/environment-variables/database/?utm_source=chatgpt.com "Database environment variables"
[3]: https://render.com/docs/docker?utm_source=chatgpt.com "Docker on Render"
[4]: https://supabase.com/docs/guides/database/connecting-to-postgres?utm_source=chatgpt.com "Connect to your database | Supabase Docs"
[5]: https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/?utm_source=chatgpt.com "Set a custom encryption key"
[6]: https://render.com/docs/disks?utm_source=chatgpt.com "Persistent Disks"
[7]: https://docs.n8n.io/hosting/configuration/environment-variables/?utm_source=chatgpt.com "Environment Variables Overview"

Here’s the copy-paste bundle for **n8n on Render free plan + Supabase Postgres + custom tools like FFmpeg**.

This setup is designed so your **workflows, credentials, and settings survive Render restarts/sleep**, because n8n stores them in Postgres and uses a fixed `N8N_ENCRYPTION_KEY`. Render free web services still **sleep after 15 minutes of inactivity**, and their local filesystem is ephemeral, so anything saved only inside the container can still be lost. ([Render][1])

## 1) Folder structure

Create a new GitHub repo like this:

```text
n8n-render/
  Dockerfile
  .dockerignore
  render.yaml
```

---

## 2) `Dockerfile`

This starts from the official n8n image and adds FFmpeg plus a few useful tools. Render supports Dockerfile-based deploys for web services. ([Render][2])

```dockerfile
FROM n8nio/n8n:latest

USER root

RUN apk add --no-cache \
    ffmpeg \
    bash \
    curl \
    git \
    jq \
    python3 \
    py3-pip \
    tzdata

USER node
```

If later you need more tools, add them in the same `apk add` line.

---

## 3) `.dockerignore`

```text
.git
.gitignore
node_modules
npm-debug.log
.env
README.md
```

---

## 4) `render.yaml`

Use this if you want Render to create the web service from your repo.

```yaml
services:
  - type: web
    name: n8n-render
    runtime: docker
    plan: free
    autoDeploy: true
    healthCheckPath: /
    envVars:
      - key: N8N_HOST
        value: n8n-render.onrender.com
      - key: N8N_PORT
        value: 5678
      - key: N8N_PROTOCOL
        value: https
      - key: WEBHOOK_URL
        value: https://n8n-render.onrender.com/
      - key: N8N_EDITOR_BASE_URL
        value: https://n8n-render.onrender.com/
      - key: N8N_SECURE_COOKIE
        value: true

      - key: DB_TYPE
        value: postgresdb
      - key: DB_POSTGRESDB_HOST
        sync: false
      - key: DB_POSTGRESDB_PORT
        value: 6543
      - key: DB_POSTGRESDB_DATABASE
        value: postgres
      - key: DB_POSTGRESDB_USER
        sync: false
      - key: DB_POSTGRESDB_PASSWORD
        sync: false
      - key: DB_POSTGRESDB_SSL_ENABLED
        value: true

      - key: N8N_ENCRYPTION_KEY
        sync: false

      - key: GENERIC_TIMEZONE
        value: Asia/Kolkata
      - key: TZ
        value: Asia/Kolkata

      - key: N8N_DIAGNOSTICS_ENABLED
        value: false
      - key: N8N_PERSONALIZATION_ENABLED
        value: false
      - key: N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS
        value: false

      - key: N8N_RUNNERS_ENABLED
        value: true

      - key: N8N_BASIC_AUTH_ACTIVE
        value: true
      - key: N8N_BASIC_AUTH_USER
        sync: false
      - key: N8N_BASIC_AUTH_PASSWORD
        sync: false
```

### What you must edit

Replace:

* `n8n-render.onrender.com` with your real Render domain after first deploy
* `DB_POSTGRESDB_HOST`
* `DB_POSTGRESDB_USER`
* `DB_POSTGRESDB_PASSWORD`
* `N8N_ENCRYPTION_KEY`
* basic auth username/password

n8n supports Postgres via environment variables, and `N8N_ENCRYPTION_KEY` is the supported way to keep encrypted credentials readable across restarts and instances. ([n8n Docs][3])

---

## 5) Supabase values to copy

In Supabase, open **Connect** and use the **pooler** connection details. Supabase documents pooled connections and notes that the pooler commonly uses port `6543`; the available connection strings are shown in the Connect panel. ([Supabase][4])

Fill these in Render:

```text
DB_POSTGRESDB_HOST=aws-0-<region>.pooler.supabase.com
DB_POSTGRESDB_PORT=6543
DB_POSTGRESDB_DATABASE=postgres
DB_POSTGRESDB_USER=postgres.<your-project-ref>
DB_POSTGRESDB_PASSWORD=<your-supabase-db-password>
DB_POSTGRESDB_SSL_ENABLED=true
```

If Supabase shows a different host/user in your Connect screen, use exactly that.

---

## 6) Generate a strong encryption key

Create a long random key and keep it forever.

Example placeholder:

```text
N8N_ENCRYPTION_KEY=replace-with-a-very-long-random-secret-string
```

Do **not** change this later unless you know how to rotate n8n encryption keys, because n8n uses it to encrypt stored credentials. ([n8n Docs][5])

---

## 7) Render setup steps

1. Push the three files above to GitHub.
2. In Render, create a **Web Service** from that repo.
3. Choose **Docker** runtime. Render supports both Dockerfile builds and prebuilt images for web services. ([Render][2])
4. Add all env vars from the `render.yaml` or UI.
5. Deploy.
6. Open your Render URL.
7. Complete n8n owner signup.

---

## 8) What survives and what does not

### Safe across restart/sleep

* workflows
* credentials
* executions metadata
* users/settings stored in the n8n database

That’s because n8n supports Postgres as its main database backend. ([n8n Docs][3])

### Not safe on free Render local storage

* local files you save inside the container
* generated videos/images kept only in the filesystem
* anything written only to `.n8n` inside the container without external backing

Render free services spin down on idle, and the filesystem is ephemeral unless you use a persistent disk, which is a separate feature not available as part of the free sleeping-service pattern. ([Render][1])

So for files, use:

* Supabase Storage
* S3 / Cloudflare R2
* Telegram upload immediately
* another external storage target

---

## 9) Best env var set for your use case

Here is the full list again in plain copy-paste format for Render’s Environment tab:

```text
N8N_HOST=n8n-render.onrender.com
N8N_PORT=5678
N8N_PROTOCOL=https
WEBHOOK_URL=https://n8n-render.onrender.com/
N8N_EDITOR_BASE_URL=https://n8n-render.onrender.com/
N8N_SECURE_COOKIE=true

DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=aws-0-REGION.pooler.supabase.com
DB_POSTGRESDB_PORT=6543
DB_POSTGRESDB_DATABASE=postgres
DB_POSTGRESDB_USER=postgres.PROJECTREF
DB_POSTGRESDB_PASSWORD=YOUR_SUPABASE_DB_PASSWORD
DB_POSTGRESDB_SSL_ENABLED=true

N8N_ENCRYPTION_KEY=YOUR_LONG_RANDOM_SECRET

GENERIC_TIMEZONE=Asia/Kolkata
TZ=Asia/Kolkata

N8N_DIAGNOSTICS_ENABLED=false
N8N_PERSONALIZATION_ENABLED=false
N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=false
N8N_RUNNERS_ENABLED=true

N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=CHANGE_THIS_PASSWORD
```

n8n’s environment variable docs cover deployment, database, and security-related settings. ([n8n Docs][6])

---

## 10) Important free-plan warning

This works for testing and light personal use, but on Render free:

* the service sleeps after 15 minutes idle
* wake-up takes time
* it is not a 24/7 production-grade setup without paid infrastructure ([Render][1])

---

## 11) Custom tools later

To add more packages later, just edit the Dockerfile:

```dockerfile
RUN apk add --no-cache \
    ffmpeg \
    imagemagick \
    bash \
    curl \
    git \
    jq \
    python3 \
    py3-pip \
    tzdata
```

Then push again and Render will rebuild the image. Docker-based Render deploys support this pattern directly. ([Render][2])

---

## 12) Biggest mistakes to avoid

Do not use:

* SQLite only
* auto-generated encryption key only
* local file storage for important data
* changing `N8N_ENCRYPTION_KEY` after you already saved credentials

Those are the common reasons people lose access to workflows or credentials after redeploys. n8n’s docs explicitly note the role of the custom encryption key. ([n8n Docs][5])

If you want, next I’ll give you a **fully filled Render checklist screen-by-screen**, including exactly what to paste into each Render field.

[1]: https://render.com/docs/free?utm_source=chatgpt.com "Deploy for Free – Render Docs"
[2]: https://render.com/docs/docker?utm_source=chatgpt.com "Docker on Render"
[3]: https://docs.n8n.io/hosting/configuration/environment-variables/database/?utm_source=chatgpt.com "Database environment variables"
[4]: https://supabase.com/docs/guides/database/connecting-to-postgres?utm_source=chatgpt.com "Connect to your database | Supabase Docs"
[5]: https://docs.n8n.io/hosting/configuration/configuration-examples/encryption-key/?utm_source=chatgpt.com "Set a custom encryption key"
[6]: https://docs.n8n.io/hosting/configuration/environment-variables/?utm_source=chatgpt.com "Environment Variables Overview"
