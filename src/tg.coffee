{ Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage } = require 'hubot'
net   = require 'net'
fs    = require 'fs'
url   = require 'url'
http  = require 'http'
prog  = require 'child_process'
path  = require 'path'

class Tg extends Adapter

  constructor: (robot) ->  
    @robot = robot
    @socket = "/tmp/#{Date.now()}.sock"
    @imageExtensions = [".jpg", ".jpeg", ".png", ".gif"]
    @tempdir = process.env['HUBOT_TG_TMPDIR'] || '/tmp/tg'

    # creating @tempdir or use /tmp
    mkdir = "mkdir -p #{@tempdir}"
    child = prog.exec mkdir, (err, stdout, stderr) ->
      @tempdir = "/tmp" if err

    # start telegram-cli
    @bindCli()

  bindCli: ->
  
    args = [
      '-k', '/etc/tg-server.pub',
      '-s', "#{__dirname}/../hubot.lua",
      '-S', @socket,
      '-W',
      '-R',
      '-C'
    ]
  
    cli = prog.spawn 'telegram-cli', args, { detached: true }
    cli.unref()
    
    cli.stdout.on 'data', (data) ->
      console.log data.toString().replace(/\r?\n/g, '')
      
    cli.stderr.on 'data', (data) ->
      console.log data.toString().replace(/\r?\n/g, '')
      
    cli.on 'close', (code) ->
      console.log "*** Cli exit with code: #{code}"
      process.exit(1) # relaunch all the things

    process.on 'exit', (options, err) ->
      cli.kill()
    
  send: (envelope, strings...) ->
    if strings.length < 2 and (@imageExtensions.some (word) -> ~strings.toString().indexOf word)
      _strings = strings.toString()
      @get_image(envelope, _strings, @socket, @send_photo)
      return

    # Flatten out strings to send, as the tg telnet interface does not allow sending newlines
    flattened = []
    for str in strings
      if str?
        for line in str.toString().split(/\r?\n/)
          if Array.isArray line
            flattened = flattened.concat line
          else
            flattened.push line

      client = net.connect { path: @socket }, ->
        messages = flattened.map (str) -> "msg #{envelope.room} \"#{str.replace(/"/g, '\\"')}\"\n"
        client.write messages.join("\n"), ->
          client.end()

  get_image: (envelope, image_url, socket, callback) ->

    DOWNLOAD_DIR = @tempdir

    options =
      host: url.parse(image_url).host
      path: url.parse(image_url).pathname

    filename = Date.now() + path.extname(options.path)
    fileFullPath = "#{DOWNLOAD_DIR}/#{filename}"
    http.get options, (res) ->
      image_data = ''
      res.setEncoding 'binary'
      res.on 'data', (chunk) ->
        image_data += chunk
      .on 'end', ->
        fs.writeFile fileFullPath, image_data, 'binary', (err) ->
          if err
            console.log "*** Error saving image"
          else
            callback(envelope, socket, fileFullPath)

  send_photo: (envelope, socket, fileLocation) ->
    message = "send_photo #{envelope.room} #{fileLocation}\n"
    client = net.connect { path: socket }, ->
      client.write message, ->
        setTimeout ->
          fs.unlink fileLocation      
          client.end()
        , 3000

  emote: (envelope, strings...) ->
    @send envelope, "* #{str}" for str in strings

  reply: (envelope, strings...) ->
    strings = strings.map (s) -> "#{envelope.user.name}: #{s}"
    @send envelope, strings...

  entityToID: (entity) ->
    entity.type + "#" + entity.id

  run: ->
    self = @
    self.robot.router.post "/hubot_tg/msg_receive", (req, res) ->
      msg  = req.body
      room = if msg.to.type == 'user' then self.entityToID(msg.from) else self.entityToID(msg.to)
      from = self.entityToID(msg.from)
      user = self.robot.brain.userForId from, name: msg.from.print_name, room: room
      self.receive new TextMessage user, msg.text, msg.id if msg.text
      res.end ""
    self.emit 'connected'

exports.use = (robot) ->
  new Tg robot
