# cmd2telegram

## Installation

1. Create a new bot as explained here: https://core.telegram.org/bots#6-botfather
2. Edit `_cmd2telegram`, insert your bot token and save it as `.cmd2telegram`
3. Run `./cmd2telegram.pl status` or `./cmd2telegram update` to check that your bot can connect to the telegram servers
4. Start a conversation with your bot in telegram, send it some text
5. Run `./cmd2telegram.pl update` - you should see your conversation and your numerical user id, add the id in `.cmd2telegram`

### Prerequisites

On a debian system, the following might come handy:
```
apt install liblwp-protocol-https-perl libjson-perl libconfig-simple-perl liburi-encode-perl
```

## Usage

- Run `./cmd2telegram.pl update` to get things sent to your bot
- Run `./cmd2telegram.pl send` to send messages to telegram

## Caution

This is all work in progress.
