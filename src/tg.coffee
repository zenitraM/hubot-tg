{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage} = require 'hubot'
net           = require 'net'

class Tg extends Adapter
  constructor: (robot) ->
    @robot = robot
    @port = process.env['HUBOT_TG_PORT'] || 1123
    @host = process.env['HUBOT_TG_HOST'] || 'localhost'

  send: (envelope, strings...) ->
    # Flatten out strings to send, as the tg telnet interface does not allow sending newlines
    flattened = []
    for str in strings
      if typeof str != 'undefined'
        for line in str.toString().split(/\r?\n/)
          if Array.isArray line
            flattened = flattened.concat line
          else
            flattened.push line

    client = net.connect @port, @host, ->
      messages = flattened.map (str) -> "msg "+envelope.room+" \""+str.replace(/"/g, '\\"')+"\"\n"
      client.write messages.join("\n"), ->
        client.end()


  emote: (envelope, strings...) ->
    @send envelope, "* #{str}" for str in strings

  reply: (envelope, strings...) ->
    strings = strings.map (s) -> "#{envelope.user.name}: #{s}"
    @send envelope, strings...

  entityToID: (entity) ->
    entity.type + "#" + entity.id

  run: ->
    self = @
    # We will listen here to incoming events from tg - inspired on hubot-slack v2
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
