import tgl
import os
import json
import datetime
import urllib.request as request


robot_id  = 0
hubot_url = os.getenv('TG_HUBOT_URL', 'http://localhost:8080/')

msg_keys  = ['action', 'date', 'dest', 'flags', 'fwd_date', 'fwd_src',
             'id', 'media', 'mention', 'out', 'reply', 'reply_id',
             'service', 'src', 'text', 'unread']
chat_keys = ['first_name', 'id', 'info', 'last_name', 'name',
             'phone', 'type', 'type_name', 'user', 'user_id',
             'user_status', 'username']
user_keys = ['id', 'name', 'type', 'type_name']       


def todict(obj):
  """
  Convert a tgl.Msg or tgl.Peer object into a dictionary in
  order to be able to serialize it with JSON or pickle.
  """

  res   = {}
  remap = {'dest':'to', 'src':'from',
           'type_name':'type', 'type':'type_id'}

  if isinstance(obj, tgl.Peer):
    if obj.type_name == 'user':
      keys = user_keys
    if obj.type_name == 'chat':
      keys = chat_keys
  elif isinstance(obj, tgl.Msg):
    keys = msg_keys

  for key in keys:
    val = getattr(obj, key)
    key = remap.get(key, key)
    if isinstance(val, (tgl.Msg, tgl.Peer)):
      res[key] = todict(val)
    elif isinstance(val, datetime.datetime):
      res[key] = str(val)
    else:
      res[key] = val
    
  return res


def receive_msg(msg):
  """
  Forward received messages to the hubot endpoint
  outgoing messages and ones sent by the robot account are ignored.
  """
  if msg.out or msg.src.id == robot_id:
    return

  msg.src.mark_read(lambda _:_)

  req = request.Request(hubot_url + 'hubot_tg/msg_receive')
  req.add_header('Content-Type', 'application/json')
  request.urlopen(req, json.dumps(todict(msg)).encode())

  
def update_chat(chat, changes):
  """
  Chat changes event
  """
  pass


def update_id(id):
  """
  Update the robot id when available
  """
  global robot_id
  robot_id = id


def main():
  # Set callbacks
  tgl.set_on_our_id(update_id)
  tgl.set_on_chat_update(update_chat)
  tgl.set_on_msg_receive(receive_msg)

  print("hubot-tg started")


main()