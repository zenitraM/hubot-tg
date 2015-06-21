http = require 'http'
url  = require 'url'
net  = require 'net'
fs   = require 'fs'
cp   = require 'child_process'

{ Robot
, Adapter
, TextMessage
, EnterMessage
, LeaveMessage
, TopicMessage } = require 'hubot'


class Tg extends Adapter
  constructor: (robot) ->
    @robot   = robot
    @port    = process.env['HUBOT_TG_PORT'] || 1123
    @host    = process.env['HUBOT_TG_HOST'] || 'localhost'
    @tempdir = process.env['HUBOT_TG_TEMP'] || '/tmp/hubot/'

  send: (envelope, lines...) ->
    text = []
    lines.map (line) =>
      imageUrl = line.split('#')[0].split('?')[0]
      if not imageUrl.match /\.jpe?g|png$/g
        text.push line
      else
        robot.loggger.info 'Found image ' + imageUrl
        if text.length
          @send_text envelope, text
          text = []
        @get_image line, (filepath) =>
          @send_photo envelope, filepath
    @send_text envelope, text

  get_image: (imageUrl, callback) ->
    mkdir = 'mkdir -p ' + @tempdir
    cp.exec mkdir, (err, stdout, stder) =>
      throw err if err

      filename = url.parse(imageUrl).pathname.split("/").pop()
      file = fs.createWriteStream(@tempdir + filename)
      options =
        host: url.parse(imageUrl).host
        port: 80
        path: url.parse(imageUrl).pathname

      http.get options, (res) =>
        res.on("data", (data) -> file.write data).on "end", =>
          file.end()
          robot.loggger.info filename + " downloaded to " + @tempdir
          callback @tempdir + url.parse(imageUrl).pathname.split('/').pop()

  send_raw: (commands, callback) ->
    client = net.connect @port, @host, ->
      replies = []
      commands.map (i) -> client.write i+'\n'
      client.on 'data', (reply) -> replies.push reply
      0 while reply.length < commands.length
      client.end()
      callback replies

  send_photo: (envelope, filepath) ->
    client = net.connect @port, @host, ->
      message = "send_photo " + envelope.room + " " + filepath + "\n"
      client.write message, ->
        client.end ->
          fs.unlink(filepath)
          robot.loggger.infolog "File " + filepath + " deleted"

  send_text: (envelope, lines) ->
    text = lines.join "\n"
    client = net.connect @port, @host, ->
      message = "msg "+envelope.room+" \""+text.replace(/"/g, '\\"').replace(/\n/g, '\\n')+"\"\n"
      client.write message, ->
        client.end()

  emote: (envelope, lines...) ->
    @send envelope, "* #{line}" for line in lines

  reply: (envelope, lines...) ->
    lines = lines.map (s) -> "#{envelope.user.name}: #{s}"
    @send envelope, lines...

  entityToID: (entity) ->
    entity.type + "#" + entity.id

  run: ->
    self = @
    # We will listen here to incoming events from tg
    self.robot.router.post "/hubot_tg/msg_receive", (req, res) ->
      msg = req.body
      room = if msg.to.type == 'user' then self.entityToID(msg.from) else self.entityToID(msg.to)
      from = self.entityToID(msg.from)
      user = self.robot.brain.userForId from, name: msg.from.print_name, room: room
      self.receive new TextMessage user, msg.text, msg.id
      res.end ""
    self.emit 'connected'


exports.use = (robot) ->
  new Tg robot
