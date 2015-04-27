{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage} = require 'hubot'
{exec, spawn} = require('child_process')
net  = require 'net'
fs   = require('fs')
url  = require('url')
http = require('http')


class Tg extends Adapter
  constructor: (robot) ->
    @robot = robot
    @port = process.env['HUBOT_TG_PORT'] || 1123
    @host = process.env['HUBOT_TG_HOST'] || 'localhost'
    @tempdir = process.env['HUBOT_TG_TMPDIR'] || '/tmp/hubot'
    @imageExtensions = [".jpg", ".png", ".jpeg"]

  send: (envelope, strings...) ->
    if strings.length < 2 and (@imageExtensions.some (word) -> ~strings.toString().indexOf word)
      myString = strings.toString()
      @get_image(envelope, myString, @host, @port, @send_photo)
      return

    str = strings.join "\n"
    client = net.connect @port, @host, ->
      message = "msg "+envelope.room+" \""+str.replace(/"/g, '\\"').replace(/\n/g, '\\n')+"\"\n"
      client.write message, ->
        client.end()
  
  get_image: (envelope, imageURL, destHost, destPort, callback) ->
    file_url = imageURL
    DOWNLOAD_DIR = @tempdir
    
    mkdir = 'mkdir -p ' + DOWNLOAD_DIR
    child = exec(mkdir, (err, stdout, stderr) ->
      if err
        throw err
      else
        download_file_httpget file_url
      return
    )

    download_file_httpget = (file_url) ->
      options =
        host: url.parse(file_url).host
        port: 80
        path: url.parse(file_url).pathname
      file_name = url.parse(file_url).pathname.split("/").pop()
      file = fs.createWriteStream(DOWNLOAD_DIR + file_name)
      http.get options, (res) ->
        res.on("data", (data) ->
          file.write data
          return
        ).on "end", ->
          file.end()
          console.log file_name + " downloaded to " + DOWNLOAD_DIR
          callback(envelope, destHost, destPort, fileFullPath)
          return
        return
      return
    fileFullPath = DOWNLOAD_DIR + url.parse(file_url).pathname.split('/').pop()
    fileFullPath

  send_photo: (envelope, destHost, destPort, fileLocation) ->
    client = net.connect destPort, destHost, ->
      message = "send_photo " + envelope.room + " " + fileLocation + "\n"
      client.write message, ->
        client.end ->
          fs.unlink(fileLocation)
          console.log "File " + fileLocation + " deleted"

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
