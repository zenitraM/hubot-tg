{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, TopicMessage} = require 'hubot'
net = require('net')
fs = require('fs')
url = require('url')
http = require('http')
exec = require('child_process').exec
spawn = require('child_process').spawn
fileType = require('file-type')


class Tg extends Adapter

  constructor: (robot) ->
    @robot = robot
    @port = process.env['HUBOT_TG_PORT'] || 1123
    @host = process.env['HUBOT_TG_HOST'] || 'localhost'
    @imageExtensions = ["jpg", "png"]
    @tempdir = process.env['HUBOT_TG_TMPDIR'] || '/srv/hubot/bin/downloads/'


  send: (envelope, strings...) ->
    if strings.length < 2 and strings.toString().match(/^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=!]*)/i)
      file_url = strings.toString()
      agent = if file_url.match(/^https/i) then https else http
      agent.get file_url, (res) =>
        res.once 'data', (chunk) =>
          res.destroy()
          # fileType(chunk)
          # => {ext: 'gif', mime: 'image/gif'}
          if ~@imageExtensions.indexOf fileType(chunk)?.ext
            @get_image(envelope, file_url, @host, @port, @send_photo)
          else
            @send_text(envelope, strings)

        res.on 'error', (err) =>
          @send_text(envelope, strings)
    else
      @send_text(envelope, strings)


  send_text: (envelope, strings...) ->
    # Send multiline text using double quotes:
    # msg <user> "first\nsecond\nthird"
    client = net.connect @port, @host, ->
      flattened = strings.join('\n').replace(/\n/g, '\\n').replace(/"/g, '\\"')
      messages = "msg #{envelope.room} \"#{flattened}\"\n"
      client.write messages, ->
        client.end()


  get_image: (envelope, imageURL, destHost, destPort, callback) ->
        # App variables
        file_url = imageURL
        DOWNLOAD_DIR = @tempdir
        # We will be downloading the files to a directory, so make sure it's there
        # This step is not required if you have manually created the directory
        mkdir = 'mkdir -p ' + DOWNLOAD_DIR
        child = exec(mkdir, (err, stdout, stderr) ->
          if err
            throw err
          else
            download_file_httpget file_url
          return
        )
        # Function to download file using HTTP.get

        download_file_httpget = (file_url) ->
          agent = if file_url.match(/^https/i) then https else http
          file_name = url.parse(file_url).pathname.split('/').pop()
          file = fs.createWriteStream(DOWNLOAD_DIR + file_name)
          agent.get options, (res) ->
            res.on('data', (data) ->
              file.write data
              return
            ).on 'end', ->
              file.end()
              console.log file_name + ' downloaded to ' + DOWNLOAD_DIR
              callback(envelope, destHost, destPort, fileFullPath)
              return
            return
          return
        fileFullPath = DOWNLOAD_DIR + url.parse(file_url).pathname.split('/').pop()
        fileFullPath


  send_photo: (envelope, destHost, destPort, fileLocation) ->
      #console.log 'Connecting to: ' + destHost + ':' + destPort
      #console.log 'Sending photo ' + fileLocation + ' for: ' + envelope.room
      client = net.connect destPort, destHost, ->
          message = "send_photo " + envelope.room + " " + fileLocation + "\n"
          client.write message, ->
              client.end ->
                fs.unlink(fileLocation)
                console.log 'File ' + fileLocation + ' deleted'


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
