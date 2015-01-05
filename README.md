# hubot-tg
This is a [Hubot](http://hubot.github.com/) adapter for [Telegram](http://telegram.org). 

As there are not any fully-working Telegram client implementations in Node right now,
it uses [tg](https://github.com/vysheng/tg) to send and receive messages.

It is composed of:
- a Hubot adapter (this npm module) which exposes some endpoints on Hubot's own HTTP server
to receive messages, and connects to tg telnet interface to send them.
- a simple Lua script to be loaded inside tg which will forward incoming messages to Hubot.

## Supported features and TODO
- [x] Sending/receiving chat messages
- [x] Sending/receiving group messages
- [ ] Sending multiline messages (not supported on tg telnet interface)
- [ ] Sending/receiving secret chat messages
- [ ] Sending images and media

## Setup

You need to install [tg](https://github.com/vysheng/tg) with LUA support and [luasocket](http://w3.impa.br/~diego/software/luasocket/) (using luarocks, for example)

Setup your own Hubot and add this adapter:
- `npm install -g hubot coffee-script yo generator-hubot`
- `mkdir -p /path/to/hubot`
- `cd /path/to/hubot`
- `yo hubot`
- `npm install zenitram/hubot-tg --save`
- Initialize git and make your initial commit
- Check out the [hubot docs](https://github.com/github/hubot/tree/master/docs) for further guidance on how to build your bot


Then run telegram-cli with the included lua script:
- `telegram-cli -s hubot.lua -P 1123`


## Config parameters

### Hubot
You can set ```HUBOT_TG_HOST``` and ```HUBOT_TG_PORT``` env variables, to set how shouldn Hubot connect to tg.

### tg
You can set the env variable ```TG_HUBOT_URL``` to where to find Hubot.

## Acknowledgements
- @yagop for [telegram-bot](https://github.com/yagop/telegram-bot), which inspired this

