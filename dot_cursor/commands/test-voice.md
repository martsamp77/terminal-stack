---
description: Test local TTS voice (Cursor Agent path)
---

Run the Cursor TTS end-to-end test and confirm audio played.

**Windows PowerShell:** `pwsh -NoLogo -File $env:USERPROFILE\.claude\hooks\cc-tts-test.ps1 -Source cursor`

**WSL (if hooks are deployed):** `CC_TTS_FOREGROUND=1 ~/.claude/hooks/cc-tts-test.sh --source cursor`

Use the platform-appropriate command. Report whether you heard speech prefixed with **Cursor.**
