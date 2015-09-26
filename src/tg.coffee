ne  = require 'needle'
cr  = require 'crypto'
gm  = require 'gm'
net = require 'net'
url = require 'url'
fs  = require 'fs'
cp  = require 'child_process'

{ Adapter
, TextMessage } = require 'hubot'

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
      if not imageUrl.match /\.jpe?g|png|tiff$/ig
        text.push line
      else
        @robot.logger.info 'Found image ' + imageUrl
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

      ne.get imageUrl, (err, res, body) =>
        gm(body)
        .noProfile()
        .quality(70)
        .resize(360000,'@>')
        .toBuffer (err, buffer) =>
          ext = '.' + url.parse(imageUrl).pathname.split('.').pop()
          filename = (cr.createHash('sha1').update(buffer).digest 'hex') + ext

          fs.writeFile @tempdir + filename, buffer, (err) =>
            return @robot.logger.error 'failed to save image:\n' + err if err
            @robot.logger.info filename + ' downloaded to ' + @tempdir
            setTimeout (=> callback @tempdir + filename), 250

  send_photo: (envelope, filepath) ->
    client = net.connect @port, @host, =>
      message = "send_photo #{envelope.room} #{filepath} \n"
      client.write message, =>
        client.end =>
          @robot.logger.info filepath + ' sent, delete scheduled'
          setTimeout (=>
            fs.unlink filepath
            @robot.logger.info "File #{filepath} deleted"
          ), 120000

  send_text: (envelope, lines) ->
    text = lines.join("\n").replace(/"/g, '\\"').replace(/\n/g, '\\n')
    client = net.connect @port, @host, ->
      message = "msg #{envelope.room} \"#{text}\"\n"
      client.write message, -> client.end()

  emote: (envelope, lines...) ->
    @send envelope, "* #{line}" for line in lines

  reply: (envelope, lines...) ->
    lines = lines.map (s) -> "#{envelope.user.name}: #{s}"
    @send envelope, lines...

  get_id: (entity) ->
    entity.type + '#' + entity.id

  run: ->
    self = @
    self.robot.router.post '/hubot_tg/msg_receive', (req, res) ->
      msg  = req.body
      room = if msg.to.type == 'user' then msg.from else msg.to
      from = self.get_id msg.from
      user = self.robot.brain.userForId from,
             name: msg.from.name,
             room: self.get_id room
      self.receive new TextMessage user, msg.text or '', msg.id
      res.end ''
    self.emit 'connected'

exports.use = (robot) ->
  new Tg robot
