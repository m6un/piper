# VPS Setup

The Ubuntu VPS has one job: run an hourly cron that detects interrupted builds
and re-triggers them.

## How it works

```
VPS cron (every hour)
  → pulls latest repo state
  → checks if .build-state.json exists (left behind by an interrupted build)
  → if stale: runs `claude --remote "/build <spec>"`
      → Claude Code CLI on VPS sends the task to Anthropic's cloud VM
      → Anthropic VM clones the repo from GitHub
      → /build skill runs on Anthropic's infrastructure
      → PR gets created/updated as normal
```

Claude Code CLI is installed on the VPS purely to invoke `claude --remote`.
The actual build work happens on Anthropic's VM, not on the VPS.

> Note: iOS builds (`xcodebuild`) require macOS. The GitHub Actions self-hosted
> runner for iOS must be set up on your Mac, not the VPS. See the iOS Runner
> section below.

---

## Prerequisites

```bash
# jq — for parsing .build-state.json
sudo apt install -y jq

# GitHub CLI
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt update && sudo apt install -y gh

# Claude Code
npm install -g @anthropic-ai/claude-code
```

---

## One-time Setup

### 1. Authenticate GitHub CLI
```bash
gh auth login
```

### 2. Authenticate Claude Code
```bash
claude login
```
Follow the prompts to connect your Anthropic account. This persists across sessions.

### 3. Clone the repo
```bash
git clone https://github.com/<your-username>/piper.git ~/piper
```

### 4. Set the repo owner in resume-build.sh
Open `.claude/scripts/resume-build.sh` and replace `{owner}/{repo}` with your
actual GitHub repo path (e.g. `midhun/piper`):

```bash
gh api "repos/midhun/piper/branches/$BRANCH" \
  --jq '.commit.commit.author.date'
```

### 5. Set environment variable
Add to `~/.bashrc` or `~/.profile`:
```bash
export PIPER_REPO_DIR="$HOME/piper"
```

---

## Cron Job

```bash
crontab -e
```

Add this line — runs every hour:
```
0 * * * * cd $HOME/piper && git pull --quiet && bash .claude/scripts/resume-build.sh >> $HOME/piper-resume.log 2>&1
```

Logs go to `~/piper-resume.log`. Check it if something seems stuck:
```bash
tail -f ~/piper-resume.log
```

---

## iOS Self-Hosted Runner (Mac only)

This must be set up on your Mac, not the VPS.

### 1. Go to your GitHub repo
Settings → Actions → Runners → New self-hosted runner

### 2. Select macOS and follow the instructions
GitHub will give you a download + configure + run sequence. The runner label
must include `piper` to match the workflow:

```bash
./config.sh --url https://github.com/<your-username>/piper \
            --token <token> \
            --labels self-hosted,macos,piper
```

### 3. Run as a service (auto-starts on login)
```bash
./svc.sh install
./svc.sh start
```

The runner will now pick up iOS build jobs automatically whenever your Mac is on.

---

## Verify Everything Works

```bash
# Check cron is registered
crontab -l

# Check Claude Code is authenticated
claude --version

# Check gh is authenticated
gh auth status

# Dry-run the resume script (should exit cleanly with no state file present)
bash ~/piper/.claude/scripts/resume-build.sh
```
