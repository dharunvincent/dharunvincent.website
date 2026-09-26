#!/usr/bin/env bash
#
# renew_key.sh — rotate the ANTHROPIC_API_KEY secret for the "dv-chatbot" Cloudflare Worker.
#
# The worker reads this key at runtime as env.ANTHROPIC_API_KEY (see src/chat.js).
# The key itself is never stored in this repo — it lives only in Cloudflare's
# encrypted secret store, and is only ever piped through this script, never
# echoed, logged, or written to disk.

# Fail fast: stop on any error, on use of an unset variable, and on a failed
# command anywhere in a pipeline (so a failed `wrangler secret put` isn't hidden).
set -euo pipefail

# Run from the script's own folder, so this works no matter where it's invoked from.
cd "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# npx (bundled with Node) is what runs wrangler; without it we can't upload the secret.
if ! command -v npx >/dev/null 2>&1; then
  echo "Error: npx is not installed. Install Node.js/npm, then re-run this script." >&2
  exit 1
fi

# Prompt for the new key with hidden input (-s) so it never appears on screen.
echo "Paste the new Anthropic API key (input hidden), then press Enter:"
read -r -s NEW_KEY
echo

# Basic sanity check: refuse empty input or a key that doesn't look like an
# Anthropic key, so we don't upload garbage as the worker's secret.
if [[ -z "${NEW_KEY}" || "${NEW_KEY}" != sk-ant-* ]]; then
  echo "Error: that doesn't look like a valid Anthropic API key (expected it to start with 'sk-ant-'). Aborting." >&2
  unset NEW_KEY
  exit 1
fi

# Upload the key straight into Wrangler's stdin — it's never written to a file,
# printed, or passed as a command-line argument (which could leak via shell history/ps).
if printf '%s' "${NEW_KEY}" | npx wrangler secret put ANTHROPIC_API_KEY; then
  unset NEW_KEY
  echo "Success: ANTHROPIC_API_KEY has been rotated for the dv-chatbot worker."
else
  unset NEW_KEY
  echo "Error: wrangler failed to set the secret. The key was NOT saved — check the output above and try again." >&2
  exit 1
fi

# Reminders for the manual follow-up steps this script doesn't (and shouldn't) do.
echo
echo "Next steps:"
echo "  1. Test the chatbot live on https://dharunvincent.com to confirm it's working with the new key."
echo "  2. Log the new expiry date in the #anthropic-key-status Slack channel."
