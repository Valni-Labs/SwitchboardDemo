# SwitchboardDemo

Minimal macOS chat app showing the two SDKs working together:

- [Switchboard](https://github.com/Benovi-Labs/Switchboard) routes the chat completion.
- [Linecard](https://github.com/Benovi-Labs/Linecard) supplies the model catalog that feeds the picker.

One window: pick a model, type, get a streamed reply.

## Run

```sh
SWITCHBOARD_API_KEY=swb_... swift run
```

Or open `Package.swift` in Xcode, set the environment variable in the scheme, and run the `SwitchboardDemo` target.

## Environment

| Variable | Required | Purpose |
|---|---|---|
| `SWITCHBOARD_API_KEY` | Yes, to chat | Your `swb_...` key. The app launches without it but tells you to set it. |
| `SWITCHBOARD_BASE_URL` | No | Defaults to `https://switchboard.valni.app`. |
| `SWITCHBOARD_END_USER_ID` | No | Attributes usage to an end user on your account. |

The `swb_` key is a server credential. This demo calls Switchboard directly because it is a local development tool; do not ship a key inside a distributed client.

## Requirements

macOS 14+, Swift 6 toolchain.
