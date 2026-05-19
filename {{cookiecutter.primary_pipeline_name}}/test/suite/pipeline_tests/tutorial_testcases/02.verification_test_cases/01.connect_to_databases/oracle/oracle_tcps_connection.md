# Oracle Wallet Directory

Drop your Oracle wallet files here to enable **TCPS (encrypted) connections** to a customer Oracle database.

## When to use this

- ❌ **Skip this entirely** if you're testing against the local Docker Oracle (plain TCP on port 1521). The framework defaults to plain-TCP mode when this directory is empty.
- ✅ **Use this** when connecting to a customer Oracle that requires TCPS on port 2484.

## What to put here

At minimum:

- `cwallet.sso` — auto-login wallet (no password required)

Optional / sometimes also needed:

- `ewallet.p12` — password-protected wallet (fallback / re-keying)
- `sqlnet.ora` — Oracle Net configuration referencing this directory

The customer's DBA team provides these files. Don't generate them yourself.

## How the framework uses them

When `ORACLE_WALLET_LOCATION` is set in `env_files/database_accounts/.env.oracle`, the `Connect to Oracle Database` keyword (in `test/resources/common/database.resource`) switches to TCPS mode and passes the wallet path to the `oracledb` Python driver.

To enable TCPS mode, set both values in `.env.oracle`:

```
ORACLE_WALLET_LOCATION=/app/test/suite/test_data/wallets/oracle
ORACLE_CONFIG_DIR=/app/test/suite/test_data/wallets/oracle
```

The `/app/...` prefix is the path **inside** the Docker container — the host `test/` directory is bind-mounted at `/app/test/` per `docker-compose.yml`, so wallet files placed here are visible to the framework at runtime.

## Security

All wallet files (`*.sso`, `*.p12`, `sqlnet.ora`) in this directory are git-ignored via `.gitignore`. Never commit a wallet to source control — they grant TLS-level trust to whatever Oracle CA issued them.
