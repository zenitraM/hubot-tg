package.path = package.path .. ";../?.lua"

http = require("socket.http")
ltn12 = require("ltn12")
JSON = require('JSON')
started = 0
our_id = 0
hubot_endpoint = os.getenv("TG_HUBOT_URL")
if hubot_endpoint == nil then
  hubot_endpoint = "http://localhost:8080/"
end

function vardump(value, depth, key)
  local linePrefix = ""
  local spaces = ""
  
  if key ~= nil then
    linePrefix = "["..key.."] = "
  end
  
  if depth == nil then
    depth = 0
  else
    depth = depth + 1
    for i=1, depth do spaces = spaces .. "  " end
  end
  
  if type(value) == 'table' then
    mTable = getmetatable(value)
    if mTable == nil then
      print(spaces ..linePrefix.."(table) ")
    else
      print(spaces .."(metatable) ")
        value = mTable
    end		
    for tableKey, tableValue in pairs(value) do
      vardump(tableValue, depth, tableKey)
    end
  elseif type(value)	== 'function' or 
      type(value)	== 'thread' or 
      type(value)	== 'userdata' or
      value		== nil
  then
    print(spaces..tostring(value))
  else
    print(spaces..linePrefix.."("..type(value)..") "..tostring(value))
  end
end

print ("hubot-tg lua starting")

function ok_cb(extra, success, result)
end

function get_receiver(msg)
  if msg.to.type == 'user' then
    return 'user#id'..msg.from.id
  end
  if msg.to.type == 'chat' then
    return 'chat#id'..msg.to.id
  end
end

function on_msg_receive (msg)
   if started == 0 then
    return
  end
  if msg.out then
    return
  end
  body = JSON:encode(msg)
  if(msg.from.id ~= our_id) then
    http.request {
      url = hubot_endpoint .. 'hubot_tg/msg_receive',
      method = 'POST',
      headers = { ["Content-Type"] = "application/json", ["Content-Length"] = body:len()},
      source = ltn12.source.string(JSON:encode(msg))
    }
  end

  mark_read(get_receiver(msg), ok_cb, false)

end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)
  --vardump (chat)
end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

function cron()
  -- do something
  postpone (cron, false, 1.0)
end

function on_binlog_replay_end ()
  started = 1
  postpone (cron, false, 1.0)
end
