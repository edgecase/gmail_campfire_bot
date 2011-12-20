require 'gmail'
require 'yaml'

def fetch_mail_and_push_to_campfire( config, label, gmail_options = {} )
  messages = unread_gmail_messages( config['gmail']['username'], config['gmail']['password'], label, gmail_options )
  output_messages = [summary( messages, config['gmail']['username'] )] + formatted_messages( messages )
  mark_messages_as_unread( messages )
  mark_messages_with_label( messages, label )
  send_to_campfire( output_messages, config['campfire']['api_key'], config['campfire']['room'] )
end

private

def mark_messages_as_unread( messages )
  messages.each do |message|
    message.mark :unread
  end
end

def mark_messages_with_label( messages, label )
  messages.each do |message|
    message.label! label
  end
end

def html_escape(s)
  s.to_s.gsub(/&/, "&amp;").gsub(/\"/, "&quot;").gsub(/>/, "&gt;").gsub(/</, "&lt;").split("'").join
end

def unread_gmail_messages( username, password, label, options )
  Gmail.new( username, password ) do |gmail|
    all_unread_emails = gmail.inbox.emails(:unread, options )
    all_labeled_emails = gmail.label(label).emails(:unread, options )

    return [] #all_unread_emails - all_labeled_emails     -- needs work, comparitor isn't working
  end
end

def remove_mimepart_header( body )
  blacklist = ["mimepart", "Mime", "Content-", "--" ]
  result = []
  body.to_s.split( "\n" ).each do |line|
    result << line unless blacklist.any?{|item| line.include?(item)}
  end

  result.join "\n"
end

def build_output( gmail_message, index )
  result = []
  result << "----------------------------------------------------------------------------"
  result << "Message #{index}"
  result << "From   : #{gmail_message.from.join(', ')}"
  result << "To     : #{gmail_message.to.join(', ')}"
  result << "Subject: #{gmail_message.subject}"
  result << "----------------------------------------------------------------------------"
  result << remove_mimepart_header( gmail_message.body )

  html_escape result.join( "\n" )
end

def formatted_messages( messages )
  result = []
  messages.each_with_index{|message, index| result << build_output( message, index+1 )}
  result
end

def summary( messages, email_address )
  "#{messages.length} emails have arrived for #{email_address}"
end

def send_to_campfire( messages, api_key, room )
  messages.each do |message|
    xml = "<message><body>#{message}</body></message>"
    command = "curl -u #{api_key}:X -H 'Content-Type: application/xml' -d '#{xml}' #{room}/speak.xml"
    `#{command}`
  end
end



config = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'config', 'connections.yml'))[ARGV[0]]
if config
  fetch_mail_and_push_to_campfire( config, "Sent to campfire", gmail_options = {} )  #options can be :after, :before, :on, :from, :to
else
  raise RuntimeError.new("Bad Config - Check yaml file and command line args match")
end
