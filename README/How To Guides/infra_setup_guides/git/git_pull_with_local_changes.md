# Git Pull with Local Changes

> Quick reference for updating your local repo while preserving your configuration changes.

---

## At a glance

| | |
|---|---|
| **Options available** | 4 |
| **Recommended approach** | Stash |
| **`.env` safety** | Usually safe (gitignored) |
| **Time to complete** | ~3 minutes |

---

## Pro Tip — Use a `backup/` Folder for Your Custom Files

> 💡 **Best practice:** Keep ALL your customized files (modified test configs, custom `.env` overrides, pipeline tweaks, SQL scripts, etc.) in a `backup/` folder inside the project. This folder is listed in `.gitignore`, so git will **never touch it** during pull/merge.

### One-time setup

```bash
# Create the backup folder
mkdir -p backup

# Verify it's gitignored (should print "backup/")
git check-ignore backup/
```

> ⚠️ **If `git check-ignore backup/` prints nothing**, add it to `.gitignore`:
> ```bash
> echo "backup/" >> .gitignore
> ```

### Save your customized files

```bash
# Copy any files you've customized into backup/
cp .env backup/.env
cp test/suite/pipeline_tests/oracle/my_custom_test.robot backup/
cp env_files/database_accounts/.env.oracle backup/.env.oracle
cp src/pipelines/my_pipeline.slp backup/
```

### Now git pull is painless

```bash
# Pull with confidence — backup/ is invisible to git
git pull origin main

# Restore your files from backup
cp backup/.env .env
cp backup/my_custom_test.robot test/suite/pipeline_tests/oracle/
cp backup/.env.oracle env_files/database_accounts/
```

### Why this works

| Without backup/ | With backup/ |
|---|---|
| Edit files in place → git pull conflicts | Edit files in place → copy to backup/ → git pull → copy back |
| Must remember which files you changed | backup/ folder IS the list of changed files |
| Stash/unstash can be confusing | Simple `cp` commands, no git knowledge needed |
| Lose track of your overrides across updates | backup/ persists across all git operations |

> 💡 **Tip:** You can also keep notes in `backup/README.txt` describing what each file overrides and why. Since the whole folder is gitignored, it's your private workspace.

---

## Before You Start

> 🔍 **Check if `.env` is tracked by git:**
> ```bash
> git check-ignore .env
> ```
>
> - If it prints `.env` → your `.env` is gitignored and `git pull` will NOT touch it. You only need to worry about other files you changed.
> - If it prints nothing → `.env` IS tracked. Use one of the options below to save it.

### See what you changed

```bash
# Show which files you modified
git status

# Show the actual changes (line by line)
git diff

# Show only filenames that changed
git diff --name-only
```

---

## Option 1 — Git Stash ✅ Recommended

Temporarily saves your changes, pulls the latest code, then re-applies your changes on top.

### Step 1: Save your local changes

```bash
git stash
```

This removes your changes from the working directory and saves them in a temporary stash.

### Step 2: Pull latest code

```bash
git pull origin main
```

### Step 3: Re-apply your changes

```bash
git stash pop
```

Your local changes are now applied on top of the latest code.

### If you get merge conflicts

```bash
# See which files have conflicts
git status

# Open the conflicted file in your editor — look for <<<<< and >>>>> markers
# Resolve the conflict manually, then:
git add <filename>
git stash drop
```

---

## Option 2 — Manual Backup & Restore (Simple)

Best when you only changed a few specific files (like `.env` or test config).

### Step 1: Copy your changed files somewhere safe

```bash
cp .env .env.backup
cp path/to/your/file path/to/your/file.backup
```

### Step 2: Pull latest code

```bash
git pull origin main
```

### Step 3: Copy your files back

```bash
cp .env.backup .env
cp path/to/your/file.backup path/to/your/file
```

---

## Option 3 — Save Changes to a Branch (Best for Long-Term)

Creates a permanent record of your changes that you can merge with any future update.

### Step 1: Create a branch with your changes

```bash
git checkout -b my-local-changes
```

### Step 2: Commit your changes

```bash
git add -A
git commit -m "My local config changes"
```

### Step 3: Switch back to main and pull

```bash
git checkout main
git pull origin main
```

### Step 4: Merge your changes on top

```bash
git merge my-local-changes
```

---

## Option 4 — Discard Local Changes ⚠️ Destructive

> 🚨 **Warning:** This permanently deletes your local changes. Only use if you don't need them.

```bash
# Throw away ALL local changes and match the remote exactly
git checkout -- .
git pull origin main
```

---

## Quick Reference

| Situation | Command |
|---|---|
| I just changed `.env` | `.env` is usually in `.gitignore` — just `git pull origin main`. It won't be touched. |
| I changed test files or Makefiles | `git stash` → `git pull origin main` → `git stash pop` |
| I want to see what I changed | `git diff` (unstaged) or `git diff --cached` (staged) |
| I want to throw away everything | `git checkout -- .` → `git pull origin main` |
| I want to see if `.env` is safe | `git check-ignore .env` (prints `.env` if gitignored) |
| I stashed but want to see what's in the stash | `git stash show -p` |
| I stashed but want to throw it away | `git stash drop` |
| I have multiple stashes | `git stash list` to see all, `git stash pop stash@{1}` to apply a specific one |

---

## Common Errors & Fixes

### `error: Your local changes would be overwritten by merge`

Git is telling you that files you changed locally were also changed in the remote. Use **Option 1 (stash)** to save your changes first.

```bash
git stash
git pull origin main
git stash pop
```

### `CONFLICT (content): Merge conflict in <filename>`

Both you and the remote changed the same lines. Open the file, find the `<<<<<<<` markers, keep the version you want, delete the markers, then:

```bash
git add <filename>
git commit -m "Resolved merge conflict"
```

### `Already up to date` but I know there are changes

You might be on the wrong branch:

```bash
# Check which branch you're on
git branch

# Switch to main if needed
git checkout main
git pull origin main
```

---

## Why `git pull origin main` instead of just `git pull`?

Both work in most cases, but `git pull origin main` is **explicit and safer**:

- ✅ Tells git **which remote** (`origin`) and **which branch** (`main`) to pull from
- ✅ Works even if your local branch has no upstream tracking set
- ✅ Avoids accidentally pulling into the wrong branch
- ❌ Plain `git pull` fails with "no tracking information" if upstream isn't configured

If your default branch is `master` (older repos) instead of `main`, substitute accordingly: `git pull origin master`.

---

*SnapLogic QA Automation — Git Quick Reference — Last updated: May 2026*
