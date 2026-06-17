---
description: Test TTS question notification (Cursor)
---

Simulate the question template the same way the AskQuestion hook would speak:

**Windows:** `pwsh -NoLogo -File $env:USERPROFILE\.claude\hooks\cc-tts-notify.ps1 -State question -Source cursor -Foreground`

Report whether you heard **Cursor.** followed by the question template.
