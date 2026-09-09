# Qwen 3.8 27B llama.cpp LaunchAgent for macOS

This guide runs a `llama.cpp` server as a per-user macOS LaunchAgent. The server starts when the user logs in and is restarted by `launchd` if it exits.

## Prerequisites

Install `llama` using MacPorts before proceeding:

```
$ sudo port install llama.cpp
```

- macOS with `launchd`
- `llama.cpp` installed, with the executable at `/opt/local/bin/llama`
- Access to the Hugging Face model repositories used below
- The IP address `192.168.x.x` assigned to a network interface on the Mac

Confirm the executable and IP address before installing:

```bash
test -x /opt/local/bin/llama && /opt/local/bin/llama --version
ifconfig | grep 'inet 192.168.x.x'
```

If the executable or IP address differs, update the corresponding values in the property list below.

## Install the LaunchAgent

Create the LaunchAgents directory if necessary:

```bash
mkdir -p ~/Library/LaunchAgents
```

Create `~/Library/LaunchAgents/com.local.llama-qwen.plist` with the following contents. Replace `REPLACE_WITH_API_KEY` with the server API key before loading it.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.local.llama-qwen</string>

    <key>ProgramArguments</key>
    <array>
        <string>/opt/local/bin/llama</string>
        <string>server</string>
        <string>-hf</string>
        <string>ggml-org/Qwen3.8-27B-GGUF:Q4_K_M</string>
        <string>-hfd</string>
        <string>ggml-org/Qwen3.8-27B-GGUF:Q4_0</string>
        <string>--alias</string>
        <string>qwen3.8-27b</string>
        <string>--metrics</string>
        <string>--spec-default</string>
        <string>--spec-type</string>
        <string>draft-mtp</string>
        <string>--reasoning-preserve</string>
        <string>--host</string>
        <string>192.168.x.x</string>
        <string>--port</string>
        <string>9931</string>
        <string>-lv</string>
        <string>2</string>
        <string>--image-min-tokens</string>
        <string>1024</string>
        <string>--api-key</string>
        <string>REPLACE_WITH_API_KEY</string>
    </array>

    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ProcessType</key>
    <string>Interactive</string>

    <key>StandardOutPath</key>
    <string>/tmp/llama-qwen.stdout.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/llama-qwen.stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
```

Restrict access because the property list contains the API key, then validate it:

```bash
chmod 600 ~/Library/LaunchAgents/com.local.llama-qwen.plist
plutil -lint ~/Library/LaunchAgents/com.local.llama-qwen.plist
```

Load the service:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.llama-qwen.plist
```

The initial model download can take some time. Follow the logs to monitor progress:

```bash
tail -f /tmp/llama-qwen.stderr.log /tmp/llama-qwen.stdout.log
```

## Verify the Service

Inspect the LaunchAgent:

```bash
launchctl print gui/$(id -u)/com.local.llama-qwen
```

Test the OpenAI-compatible models endpoint from a machine that can reach the Mac:

```bash
curl --fail --silent --show-error \
  -H 'Authorization: Bearer REPLACE_WITH_API_KEY' \
  http://192.168.x.x:9931/v1/models
```

Metrics are available at:

```text
http://192.168.x.x:9931/metrics
```

## Service Management

Restart the service after changing its configuration:

```bash
launchctl kickstart -k gui/$(id -u)/com.local.llama-qwen
```

Stop and unload it:

```bash
launchctl bootout gui/$(id -u)/com.local.llama-qwen
```

Load it again:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.llama-qwen.plist
```

## Updating the Configuration

After editing the property list, validate and reload it so `launchd` sees all changes:

```bash
plutil -lint ~/Library/LaunchAgents/com.local.llama-qwen.plist
launchctl bootout gui/$(id -u)/com.local.llama-qwen 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.local.llama-qwen.plist
```

## Troubleshooting

- **`Bootstrap failed: 5: Input/output error`**: the agent may already be loaded. Run `bootout`, then `bootstrap` again.
- **The process repeatedly exits**: inspect both files in `/tmp/llama-qwen.*.log` and verify the command-line options are supported by the installed `llama.cpp` version.
- **Cannot bind the address**: confirm `192.168.x.x` is assigned to the Mac, or change `--host` to the correct address. Use `127.0.0.1` for local-only access or `0.0.0.0` for all interfaces.
- **Clients cannot connect**: check the macOS firewall, network routing, port `9931`, and whether the server is listening with `lsof -nP -iTCP:9931 -sTCP:LISTEN`.
- **Model access fails**: verify the repository names, network access, available disk space, and any Hugging Face credentials required for the models.

## Security Notes

- Never commit or publish a real API key. This README intentionally uses a placeholder.
- Anyone who has the key and can reach the listening address can call the server.
- Prefer `127.0.0.1` if remote access is unnecessary.
- Restrict inbound access to port `9931` to trusted hosts or networks.
- Rotate any key that has been accidentally shared.

## Uninstall

Unload the LaunchAgent and remove its property list:

```bash
launchctl bootout gui/$(id -u)/com.local.llama-qwen 2>/dev/null || true
rm ~/Library/LaunchAgents/com.local.llama-qwen.plist
```

The log files in `/tmp` are temporary and may be removed separately if desired.

