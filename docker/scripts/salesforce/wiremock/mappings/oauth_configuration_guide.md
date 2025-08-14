# Salesforce OAuth Configuration Management

## 1. For WireMock Testing (Your Current Setup)

Since you're using WireMock mocks, the OAuth endpoint (`01-oauth-token.json`) **doesn't actually validate** the client_id and client_secret. Any values will work. However, you should still use realistic values for proper testing.

### Option A: Use Dummy Values (Simplest for Mocks)
```robot
# In your test suite or resource file
${CLIENT_ID}        dummy_client_id_for_testing
${CLIENT_SECRET}    dummy_client_secret_for_testing
```

### Option B: Use Salesforce-like Format (More Realistic)
```robot
# These look like real Salesforce credentials but are fake
${CLIENT_ID}        3MVG9YDQS5WtC11paU2WcQjBB3L5w4gz52uriT8ksZ3nUVjKvrfQMrU4uvZohTftxS
${CLIENT_SECRET}    9205371019321668423
```

## 2. Environment Variables (Recommended)

### Set in your shell/Docker:
```bash
# .env file (don't commit to git)
export SALESFORCE_CLIENT_ID="3MVG9YDQS5WtC11paU2WcQjBB3L5w4gz52uriT8ksZ3nUVjKvrfQMrU4uvZohTftxS"
export SALESFORCE_CLIENT_SECRET="9205371019321668423"
export SALESFORCE_USERNAME="test@example.com"
export SALESFORCE_PASSWORD="test123"
export SALESFORCE_SECURITY_TOKEN=""  # Not needed for mocks
```

### Docker Compose:
```yaml
services:
  robot-tests:
    image: robot-framework
    environment:
      - SALESFORCE_CLIENT_ID=${SALESFORCE_CLIENT_ID:-mock_client_id}
      - SALESFORCE_CLIENT_SECRET=${SALESFORCE_CLIENT_SECRET:-mock_secret}
      - SALESFORCE_USERNAME=${SALESFORCE_USERNAME:-test@example.com}
      - SALESFORCE_PASSWORD=${SALESFORCE_PASSWORD:-test123}
```

### Robot Framework reads them:
```robot
# The %{VAR=default} syntax reads from environment with fallback
${CLIENT_ID}        %{SALESFORCE_CLIENT_ID=mock_client_id}
${CLIENT_SECRET}    %{SALESFORCE_CLIENT_SECRET=mock_secret}
```

## 3. Command Line Arguments (For CI/CD)

```bash
# Pass via command line
robot --variable CLIENT_ID:actual_client_id \
      --variable CLIENT_SECRET:actual_secret \
      --variable USERNAME:test@example.com \
      tests/
```

## 4. Configuration Files (For Different Environments)

### config/test.yaml
```yaml
salesforce:
  client_id: "test_client_id"
  client_secret: "test_secret"
  username: "test@example.com"
  password: "test123"
```

### config/sandbox.yaml
```yaml
salesforce:
  client_id: "3MVG9YDQS5WtC11paU2WcQjBB3L..."
  client_secret: "actual_sandbox_secret"
  username: "admin@company.sandbox"
  password: "real_password"
  security_token: "actual_token"
```

### Load in Robot:
```robot
*** Settings ***
Library    YamlLibrary

*** Keywords ***
Load Config
    [Arguments]    ${env}=test
    ${config}=    Load Yaml    config/${env}.yaml
    Set Suite Variable    ${CLIENT_ID}    ${config}[salesforce][client_id]
    Set Suite Variable    ${CLIENT_SECRET}    ${config}[salesforce][client_secret]
```

## 5. Vault/Secrets Management (Production)

### HashiCorp Vault:
```python
# Custom library to fetch from Vault
import hvac

def get_salesforce_credentials():
    client = hvac.Client(url='https://vault.company.com')
    response = client.secrets.kv.v2.read_secret_version(
        path='salesforce/credentials'
    )
    return response['data']['data']
```

### AWS Secrets Manager:
```python
import boto3
import json

def get_salesforce_credentials():
    client = boto3.client('secretsmanager')
    response = client.get_secret_value(SecretId='salesforce/oauth')
    return json.loads(response['SecretString'])
```

## 6. For Your WireMock Testing

Since WireMock doesn't validate credentials, you can:

### Simple Approach (Recommended for Mocks):
```robot
*** Variables ***
# These are mock values - WireMock accepts anything
${CLIENT_ID}        mock_client_id
${CLIENT_SECRET}    mock_client_secret
${USERNAME}         test@example.com
${PASSWORD}         test123
```

### Or make it configurable:
```robot
*** Variables ***
# Use environment variables with mock defaults
${CLIENT_ID}        %{SALESFORCE_CLIENT_ID=mock_client_id}
${CLIENT_SECRET}    %{SALESFORCE_CLIENT_SECRET=mock_secret}
```

## 7. Real Salesforce Credentials (When Needed)

When testing against real Salesforce sandbox:

1. **Create Connected App in Salesforce:**
   - Setup → Apps → App Manager → New Connected App
   - Enable OAuth Settings
   - Select OAuth Scopes (api, refresh_token, etc.)
   - Get Consumer Key (Client ID) and Consumer Secret

2. **Store Securely:**
   - Never commit to git
   - Use environment variables
   - Use secrets management tool
   - Rotate regularly

3. **Security Token:**
   - Real Salesforce requires: password + security_token
   - Get from: Salesforce → My Settings → Personal → Reset Security Token

## Example: Complete Setup

### .env.example (commit this)
```bash
SALESFORCE_CLIENT_ID=your_client_id_here
SALESFORCE_CLIENT_SECRET=your_secret_here
SALESFORCE_USERNAME=your_username_here
SALESFORCE_PASSWORD=your_password_here
SALESFORCE_SECURITY_TOKEN=your_token_here
```

### .env (don't commit - actual values)
```bash
SALESFORCE_CLIENT_ID=3MVG9YDQS5WtC11paU2WcQjBB3L...
SALESFORCE_CLIENT_SECRET=9205371019321668423
SALESFORCE_USERNAME=test@example.com
SALESFORCE_PASSWORD=test123
SALESFORCE_SECURITY_TOKEN=
```

### docker-compose.yml
```yaml
services:
  tests:
    env_file: .env
    command: robot tests/
```

## Summary for Your Mock Setup

Since you're using WireMock that doesn't validate credentials:

1. **Use any values** - "mock_client_id" and "mock_secret" are fine
2. **Be consistent** - Use same values across all tests
3. **Make configurable** - Use environment variables for flexibility
4. **Document** - Make it clear these are mock values
5. **Prepare for real** - Structure so you can easily switch to real credentials later