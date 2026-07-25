# docker-compose smoke test

QA harness for the ownCloud + Collabora CODE docker-compose example that ships in
the admin manual
(`modules/admin_manual/examples/installation/docker/docker-compose.yml`).

The example is written for a **production, internet-facing** deployment: it pulls
an image tag that Antora fills in at build time and it obtains real Let's Encrypt
certificates, which needs public DNS. Neither works on a throwaway machine, so
this harness layers two small files on top of the shipped example to make it
bootable **locally and in CI without changing the example itself**:

| File | Purpose |
| --- | --- |
| `docker-compose.override.yml` | Drops the Let's Encrypt / ACME command flags so Traefik serves its built-in self-signed certificate. Everything else — split networks, no DB/Redis host ports, Collabora admin allowlist, HSTS — is inherited unchanged. |
| `test.env` | Concrete image pins, `*.localhost` hostnames, and throwaway credentials. |
| `smoke-test.sh` | Boots the merged stack, waits for health, and asserts the endpoints and the security invariants. |

## Running

```
npm run test:compose
```

or directly:

```
tests/docker-compose/smoke-test.sh
```

Requires Docker with the Compose plugin, plus `curl` and `bash`. The script
always tears the stack down (`docker compose down -v`) on exit, including on
failure, and dumps container status + logs when something fails.

## What it asserts

1. **ownCloud is up** — `https://owncloud.localhost/status.php` returns JSON with
   `"installed":true`.
2. **Collabora is up** — `https://collabora.localhost/hosting/discovery` returns a
   WOPI `<wopi-discovery>` document.
3. **Data tier is private (security regression guard)** — the merged
   `docker compose config` publishes no `3306`/`6379` host binding, and neither
   port answers on `127.0.0.1`. This guards the hardening that removed the
   MariaDB/Redis host ports from the example.

TLS is served with Traefik's self-signed certificate, so all requests use
`curl -k --resolve <host>:443:127.0.0.1`.
