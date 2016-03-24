ne  = require 'needle'
syn = require 'async'
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
    [..., last] = lines
    if typeof last is 'function'
       callback = lines.pop()
    text = []
    syn.eachSeries lines, (@parse_line envelope, text), =>
      @send_text envelope, text, -> callback() if callback?

  parse_line: (envelope, text) -> (line, done) =>
    accepted = ['image/jpeg', 'image/png', 'image/tiff']
    push = ->
      text.push line
      done()

    return push() if not url.parse(line).hostname?

    ne.head line, (err, res) =>
      @robot.logger.info 'found url ' + line
      if err?
        @robot.logger.warning "headers download failed:\n#{err}"
        return push()
      if not (res.headers['content-type'].split(';')[0] in accepted)
        @robot.logger.warning 'url ignored'
        return push()
      @robot.logger.info 'found image: downloading...'
      if text.length
        @send_text envelope, text
        text = []
      @get_image line, (filepath) =>
        @send_photo envelope, filepath, -> done()

  get_image: (imageUrl, callback) ->
    mkdir = 'mkdir -p ' + @tempdir
    cp.exec mkdir, (err, stdout, stder) =>
      throw err if err

      ne.get imageUrl, follow_max: 5, (err, res, body) =>
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

  send_photo: (envelope, filepath, callback) ->
    client = net.connect @port, @host, =>
      message = "send_photo #{envelope.room} #{filepath} \n"
      client.write message
      client.on 'data', =>
        client.end()
        @robot.logger.info filepath + ' sent, delete scheduled'
        setTimeout (=>
          fs.unlink filepath
          @robot.logger.info "file #{filepath} deleted"
        ), 120000
        callback() if callback?

  send_text: (envelope, lines, callback) ->
    text = lines.join("\n").replace(/"/g, '\\"').replace(/\n/g, '\\n')
    client = net.connect @port, @host, ->
      message = "msg #{envelope.room} \"#{text}\"\n"
      client.write message
      client.on 'data', ->
        client.end()
        callback() if callback?

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
