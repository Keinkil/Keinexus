if ARGV.length != 2
  puts 'Usage: ruby bot.rb <token> <client_id>'
  exit
end
require 'rubygems'

require 'bundler/setup'
Bundler.setup(:default)

require 'fileutils'
require 'yaml'
require 'discordrb'
require 'pry'
require 'time'

# This hash will store voice channel_ids mapped to text_channel ids
# {
#   "267526886454722560": "295714345344565249",
#   etc.
# }
FileUtils.touch('associations.yaml')
ASSOCIATIONS = YAML.load_file('associations.yaml')
ASSOCIATIONS ||= Hash.new

FileUtils.touch('server_namings.yaml')
#SERVER_NAMINGS = YAML.load_file('server_namings.yaml')
SERVER_NAMINGS ||= Hash.new
SERVER_NAMINGS.default = 'voice-channel'

OLD_VOICE_STATES = Hash.new

# These are the perms given to people for a associated voice-channel
ALLOW = Discordrb::Permissions.new
ALLOW.can_read_message_history = false
ALLOW.can_read_messages = true
ALLOW.can_send_messages = true
ALLOW.can_add_reactions = true

# Set2
DENY = Discordrb::Permissions.new
DENY.can_read_message_history = true
DENY.can_read_messages = true
DENY.can_send_messages = true
DENY.can_add_reactions = true

BOT = Discordrb::Commands::CommandBot.new token: ARGV.first, client_id: ARGV[1], prefix: '!', advanced_functionality: true

BOT.ready { |event| BOT.servers.each { |_, server| setup_server(server) }; BOT.set_user_permission(152621041976344577, 3) }

BOT.server_create do |event|
  event.server.member(event.BOT.profile.id).nick = "🔗"
  event.server.owner.pm("Thank you for using **Conexus**!\nTo change the name of created associated text-channels, type **IN THE SERVER**: `set-name 'new-name-here'`")
  setup_server(event.server)
end

def setup_server(server)
  puts "\n"
  puts "#{Time.now.utc.iso8601(3)} - Setting up [#{server.name}]"
  puts "#{Time.now.utc.iso8601(3)} - Trimming associations"
  trim_associations
  puts "#{Time.now.utc.iso8601(3)} - Cleaning up after restart" + "\n\n"
  server.text_channels.select { |tc| tc.name == SERVER_NAMINGS[server.id] }.each do |tc|
    unless ASSOCIATIONS.values.include?(tc.id)
      tc.delete
      next
    end
    vc = server.voice_channels.find { |vc| vc.id == ASSOCIATIONS.key(tc) }
    tc.users.select { |u| !vc.users.include?(u) }.each do |u|
      tc.define_overwrite(u, 0, 0)
    end
  end

  everyone = server.everyone_role
  member = server.role("member")
  non_member = server.role("non_member")
  server.voice_channels.each { |vc| associate(vc) }
  server.text_channels.each { |tc| tc.name == SERVER_NAMINGS[server.id] }.each do |tc|
    if ASSOCIATIONS.values.include?(tc.id)
      if @member
        tc.define_overwrite(member, 0, DENY)
      end
      if @non_member
        tc.define_overwrite(non_member, 0, DENY)
      end
      tc.define_overwrite(everyone, 0, DENY)
    end
  end

  OLD_VOICE_STATES[server.id] = server.voice_states.clone
  BOT.set_user_permission(server.owner.id, 2)
  puts "#{Time.now.utc.iso8601(3)} - Done\n"
end

def simplify_voice_states(voice_states)
  clone = voice_states.clone
  clone.each { |user_id, state| clone[user_id] = state.voice_channel }

  return clone
end

def trim_associations
  ids = BOT.servers.map { |_, s| s.voice_channels.map { |vc| vc.id } }.flatten
  ASSOCIATIONS.delete_if { |vc_id, tc_id| !ids.include?(vc_id) }

  save
end

def associate(voice_channel)
  server = voice_channel.server
  return if voice_channel == server.afk_channel # No need for AFK channel to have associated text-channel
  return if voice_channel.id == 438451708348334080

  puts "#{Time.now.utc.iso8601(3)} - Associating '#{voice_channel.name} / #{server.name}'"
  text_channel = server.text_channels.find { |tc| tc.id == ASSOCIATIONS[voice_channel.id] }
  if text_channel.nil?
    puts "#{Time.now.utc.iso8601(3)} - Not found... creating..."
    text_channel = server.create_channel("#{voice_channel.name}", 0) # Creates a matching text-channel with the name of the voice channel
    text_channel.topic = "Private chat for all those in the voice-channel [**#{voice_channel.name}**]."
    text_channel.parent = "#{voice_channel.parent_id}" # Puts the new text channel in the same category as the voice channel

    voice_channel.users.each do |u|
      text_channel.define_overwrite(u, ALLOW, 0)
    end

    text_channel.define_overwrite(voice_channel.server.roles.find { |r| r.id == voice_channel.server.id }, 0, ALLOW) # Set default perms as invisible
    ASSOCIATIONS[voice_channel.id] = text_channel.id # Associate the two
    save
  end

  text_channel
end

def handle_user_change(action, voice_channel, user)
  puts "#{Time.now.utc.iso8601(3)} - Handling user #{action} for '#{voice_channel.name} / #{voice_channel.server.name}' for #{user.distinct}"
  text_channel = associate(voice_channel) # This will create it if it doesn't exist. Pretty cool!

  # For whatever reason, maybe is AFK channel
  return if text_channel.nil?

  if action == :join
#    text_channel.send_message("**#{user.display_name}** joined the voice-channel.")
    text_channel.define_overwrite(user, ALLOW, 0)
  else
#    text_channel.send_message("**#{user.display_name}** left the voice-channel.")
    text_channel.delete_overwrite(user)
  end
end

# VOICE-CHANNEL CREATED
BOT.channel_create(type: 2) do |event|
  associate(event.channel)
end

# VOICE-CHANNEL DELETED
BOT.channel_delete(type: 2) do |event|
  event.server.text_channels.select { |tc| tc.id == ASSOCIATIONS[event.id] }.map(&:delete)
  trim_associations
end

BOT.voice_state_update do |event|
  #old = simplify_voice_states(OLD_VOICE_STATES[event.server.id])
  #current = simplify_voice_states(event.server.voice_states)
  member = event.user.on(event.server)

  if event.old_channel != event.channel #current[member.id] != old[member.id]
    # Something has happened
    handle_user_change(:leave, event.old_channel, member) unless event.old_channel.nil?
    handle_user_change(:join, event.channel, member) unless event.channel.nil?

    OLD_VOICE_STATES[event.server.id] = event.server.voice_states.clone
  end
end

BOT.command(:creator, description: 'Open console.', permission_level: 3) do |event|
  binding.pry

  nil
end

BOT.command(:conexus, description: 'Set the name of the text-channels created for each voice-channel.', usage: '`!conexus "new-name"`', min_args: 1, max_args: 1, permission_level: 2) do |event, new_name|
  new_name.downcase!
  new_name.strip!
  new_name.gsub!(/\s+/, '-')
  new_name.gsub!(/[^a-zA-Z0-9_-]/, '')
  new_name = new_name[0..30]

  # Make sure channel doesn't already exist
  return event.user.pm "Invalid name! `##{new_name}` is already used on the server." unless event.server.text_channels.find { |tc| tc.name == new_name }.nil?

  old_name = SERVER_NAMINGS[event.server]
  SERVER_NAMINGS[event.server.id] = new_name
  save

  # Rename all the old channels to the new name
  event.server.text_channels.select { |tc| tc.name == old_name }.each do |tc|
    tc.name = new_name
  end

  event.user.pm "Set text-channel name to `##{new_name}`."
  nil
end

BOT.command(:rename, description: 'Set the name of **ONE** text-channel created for a voice-channel.', usage: '`!rename "new-name"` in the special text-channel you want to rename', min_args: 1, max_args: 1, permission_level: 2) do |event, new_name|
  new_name.downcase!
  new_name.strip!
  new_name.gsub!(/\s+/, '-')
  new_name.gsub!(/[^a-zA-Z0-9_-]/, '')
  new_name = new_name[0..30]

  ids = ASSOCIATIONS.values

  # Make sure channel doesn't already exist
  return event.user.pm "Invalid name! `##{new_name}` is already used on the server." unless event.server.text_channels.find { |tc| tc.name == new_name && !ids.include?(tc.id) }.nil?

  # Make sure is associated channel
  return event.channel.send_message('You must use this in the special text-channel!') unless ids.include?(event.channel.id)

  # Rename all the old channels to the new name
  event.channel.name = new_name

  'Renamed channel!'
end

def save
  File.open('associations.yaml', 'w') {|f| f.write ASSOCIATIONS.to_yaml }
  File.open('server_namings.yaml', 'w') {|f| f.write SERVER_NAMINGS.to_yaml }
end

#BOT.invisible
puts "\nOauth url: #{BOT.invite_url}&permissions=8"

BOT.run :async
BOT.dnd
BOT.profile.name = 'Bot Ocks'
BOT.sync
