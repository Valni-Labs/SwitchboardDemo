# SwitchboardDemo

Minimal macOS chat app showing the two SDKs working together:

- [Switchboard](https://github.com/Benovi-Labs/Switchboard) routes the chat completion.
- [Linecard](https://github.com/Benovi-Labs/Linecard) supplies the model catalog that feeds the picker.

One window: pick a model, type, get a streamed reply.

## Get a key

1. Sign in to the portal at [valni.ai/platform](https://valni.ai/platform).
2. Open the **Switchboard** tab. Under API keys, name the key (for example `switchboard-demo`), leave the scope on **Company**, and mint.
3. Copy the plaintext `swb_...` from the modal — it is shown once and never again. Only a hash is stored server-side.

If the mint is rejected, complete your account entity setup (company name and entity type) on the same tab first.

## Run

```sh
SWITCHBOARD_API_KEY=swb_... swift run
```

Or open `Package.swift` in Xcode, set the environment variable in the scheme, and run the `SwitchboardDemo` target.

### Against a non-production stack

Mint the key in that stack's portal instead (dev: [dev.valni.app/platform](https://dev.valni.app/platform)) and point the app at the matching Switchboard:

```sh
SWITCHBOARD_API_KEY=swb_... SWITCHBOARD_BASE_URL=https://switchboard-dev.valni.app swift run
```

Keys are stack-specific — a dev-minted key is invalid against production and vice versa.

## Environment

| Variable | Required | Purpose |
|---|---|---|
| `SWITCHBOARD_API_KEY` | Yes, to chat | Your `swb_...` key. The app launches without it but tells you to set it. |
| `SWITCHBOARD_BASE_URL` | No | Defaults to `https://switchboard.valni.app`. |
| `SWITCHBOARD_END_USER_ID` | No | Attributes usage to an end user on your account. |

The `swb_` key is a server credential. This demo calls Switchboard directly because it is a local development tool; do not ship a key inside a distributed client.

## Requirements

macOS 14+, Swift 6 toolchain.
