---
description: Test local TTS voice (Claude Code path)
---

Run the Claude Code TTS end-to-end test and confirm audio played.

**WSL / bash:** `CC_TTS_FOREGROUND=1 ~/.claude/hooks/cc-tts-test.sh --source claude`

**Windows PowerShell:** `pwsh -NoLogo -File $env:USERPROFILE\.claude\hooks\cc-tts-test.ps1 -Source claude`

Use the platform-appropriate command for this environment. Report whether Kokoro responded and you heard speech prefixed with **Claude.**
