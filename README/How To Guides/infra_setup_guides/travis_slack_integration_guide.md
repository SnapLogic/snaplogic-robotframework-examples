# Travis CI Slack Integration Setup Guide

This guide explains how to set up Slack notifications for Travis CI builds using the built-in Slack integration.

## Prerequisites
- Travis CI account with access to your repository
- Slack workspace admin permissions
- Travis CLI installed locally

---

## Step 1: Add Travis CI to Slack

1. Go to https://my.slack.com/services/new/travis
2. Click **Add to Slack**
3. Select the channel where you want notifications posted
4. Click **Add Travis CI Integration**
5. Copy the provided token (format: `workspace:token`)

---

## Step 2: Encrypt Your Credentials

### For Single Channel
```bash
# Navigate to your repository
cd /path/to/your/repo

# Encrypt the token
travis encrypt "workspace:token" --add notifications.slack.rooms
```

### For Multiple Channels
```bash
# First channel
travis encrypt "workspace:token#general" --add notifications.slack.rooms

# Additional channels (use --append flag)
travis encrypt "workspace:token#builds" --append notifications.slack.rooms
travis encrypt "workspace:token#dev-alerts" --append notifications.slack.rooms
```

---

## Step 3: Configure .travis.yml

### Basic Configuration
```yaml
notifications:
  slack:
    rooms:
      - secure: "encrypted_string_here"
    on_success: always
    on_failure: always
    on_error: always
```

### Advanced Configuration with Custom Templates
```yaml
notifications:
  slack:
    rooms:
      - secure: "encrypted_string_here"
    on_success: always
    on_failure: always
    on_error: always
    template:
      - "Build <%{build_url}|#%{build_number}> (<%{compare_url}|%{commit}>) of %{repository_slug}@%{branch}"
      - "by %{author} %{result} in %{duration}"
      - "Message: %{commit_message}"
```

### Conditional Notifications
```yaml
notifications:
  slack:
    rooms:
      - secure: "encrypted_string_here"
    on_success: change  # Only notify when build status changes to success
    on_failure: always  # Always notify on failure
    on_error: always    # Always notify on error
    on_start: never     # Don't notify when build starts
```

---

## Understanding the Format

### Token Format
- **Basic**: `workspace:token`
- **With Channel**: `workspace:token#channel-name`

### Example Breakdown
```yaml
snaplogic-all:yn5PYgzgNT5NAyTNkUCZlCNh#general
```
- `snaplogic-all` = Slack workspace subdomain
- `yn5PYgzgNT5NAyTNkUCZlCNh` = Integration token
- `#general` = Target channel

---

## Notification Options

### When to Send
- `always`: Send notifications every time
- `never`: Never send notifications
- `change`: Only when the build status changes
- `failure`: Only on failures (deprecated, use on_failure: always)

### Message Variables
Available variables for templates:
- `%{repository_slug}` - owner/repo format
- `%{branch}` - Git branch name
- `%{commit}` - Git commit SHA
- `%{author}` - Commit author
- `%{commit_message}` - Commit message
- `%{result}` - Build result (passed/failed)
- `%{duration}` - Build duration
- `%{build_number}` - Travis build number
- `%{build_url}` - Link to Travis build
- `%{compare_url}` - Link to commit comparison

---

## Examples

### Simple Setup
```yaml
notifications:
  slack: workspace:token
```

### Multiple Channels
```yaml
notifications:
  slack:
    rooms:
      - secure: "encrypted_token_for_general"
      - secure: "encrypted_token_for_builds"
      - secure: "encrypted_token_for_alerts"
```

### Different Templates for Success/Failure
```yaml
notifications:
  slack:
    rooms:
      - secure: "encrypted_token"
    on_success:
      template:
        - "✅ <%{build_url}|Build #%{build_number}> passed on branch %{branch}"
    on_failure:
      template:
        - "❌ <%{build_url}|Build #%{build_number}> failed on branch %{branch}"
        - "Commit <%{compare_url}|%{commit}> by %{author}"
```

---

## Troubleshooting

### Common Issues

1. **Notifications not appearing**
   - Verify Travis CI app is added to your Slack workspace
   - Check if the bot has access to the specified channel
   - Ensure the encrypted token is in the correct format

2. **Invalid token errors**
   - Tokens are repository-specific - encrypt in each repo
   - Make sure you're using the correct Travis endpoint (.com vs .org)

3. **Channel access issues**
   - For private channels, manually invite the Travis CI bot
   - Check channel permissions in Slack workspace settings

### Debugging Commands
```bash
# Verify Travis CLI is using correct endpoint
travis endpoint

# Check if encryption was successful
travis env list

# Re-encrypt with verbose output
travis encrypt "workspace:token" --add notifications.slack.rooms --debug
```

---

## Best Practices

1. **Use specific channels** for different purposes (e.g., #builds, #prod-alerts)
2. **Customize templates** to include relevant information for your team
3. **Use conditional notifications** to reduce noise
4. **Encrypt tokens per repository** for security
5. **Document your notification setup** in your project README

---

## Additional Resources

- [Travis CI Slack Notifications Documentation](https://docs.travis-ci.com/user/notifications/#configuring-slack-notifications)
- [Travis CI Environment Variables](https://docs.travis-ci.com/user/environment-variables/)
- [Slack App Directory - Travis CI](https://slack.com/apps/A0F81FP4N-travis-ci)