# Conexus 🔗
~ A simple Discord bot to link voice channels to private text channels.  
~ Modified somewhat from the
[original Apexal/Conexus bot](https://github.com/Apexal/conexus)  

## Changelog
Since I forked:  
```TEXT_PERMS.can_read_message_history = false```  
```TEXT_PERMS.can_add_reactions = true```  
Updated the [discordrb](https://github.com/meew0/discordrb) dependencies to
access the new API call  
- channel.parent_id to access voice-channel categories  

~ Added timestamps to output  
![https://i.imgur.com/W5D3uIu.png](https://i.imgur.com/W5D3uIu.png)  

## Uses
- Provides a place for messages only pertaining to the people in a
voice-channel (so you don't clutter #general or some place and confuse people)
- Allows people in voice-channels who cannot use voice to talk to the other
people in a voice-channel without cluttering another text-channel
- Tracks people entering/leaving voice-channels
- Allows customization of associated channel names

This bot creates a hidden text-channel that shares the name of the
voice-channel that spawned it for every non-AFK voice channel on a server.  
Only users in a voice-channel can view and message in a hidden text-channel.

The original by Apexal allows read message history, but this version has  
```TEXT_PERMS.can_read_message_history = false```  
because what I wanted from this bot was to emulate Teamspeak3 text
channels.

This version also allows all users to use reaction emotes in a text channel.  
```TEXT_PERMS.can_add_reactions = true```

## Commands

- [deprecated, will not work] `!conexus "new-default-name"` Set's the default
name for created text-channels  
This won't work because this version uses the voice-channel's name for the text
channel.
- `!rename "new-name"` Set's the name of **one** associated text-channel
(you must use the command in that channel)

## Run Yourself
This will require you to have a working ruby installation.

To run the program yourself, just clone it and run the following:
```sh
$ git clone git@github.com:Keinkil/conexus.git && cd conexus
$ bundle
$ ruby bot.rb <token> <client-id>
```
