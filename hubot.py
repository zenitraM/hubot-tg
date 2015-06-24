from __future__ import print_function, unicode_literals

import tgl
import os
import json
import datetime
import urllib2


hubot_url = os.getenv('TG_HUBOT_URL', 'http://localhost:8080/')
robot_id = 0


def todict(obj, depth=0):
  """
  Convert a tgl.Msg or tgl.Peer object into a dictionary in
  order to be able to serialize it with JSON or pickle.
  """
  if depth > 3:
    return {}

  d      = {}
  remap  = {'dest':'to', 'src':'from', 'type_name':'type', 'type':'type_id'}
  normal = lambda x: not x.startswith('__')

  for key in filter(normal, dir(obj)):
    try:
      # telegram-cli crashes for no reason
      if key == 'user_status':
        continue

      val = getattr(obj, key)   # get the value
      key = remap.get(key, key) # renamp key name

      if callable(val):
        continue
      elif isinstance(val, (tgl.Msg, tgl.Peer)):
        d[key] = todict(val, depth+1)
      elif isinstance(val, datetime.datetime):
        d[key] = str(val)
      else:
        d[key] = val
    except tgl.PeerError:
      continue
  return d


def receive_msg(msg):
  """
  Forward received messages to the hubot endpoint
  outgoing messages and ones sent by the robot account are ignored.
  """
  if msg.out or msg.src.id == robot_id:
    return

  msg.src.mark_read(lambda _:_)

  req = urllib2.Request(hubot_url + 'hubot_tg/msg_receive')
  req.add_header('Content-Type', 'application/json')
  urllib2.urlopen(req, json.dumps(todict(msg)))

  
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