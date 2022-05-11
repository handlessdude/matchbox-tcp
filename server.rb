# frozen_string_literal: true

require 'socket'

clients = {}

config = { host: 'localhost',
                  port: 2000 }

server = TCPServer.new config[:host], config[:port]
puts "Server running on #{config[:host]}:#{config[:port]}"
begin
  loop do
    Thread.start(server.accept) do |client|
      id = :"player_#{clients.length + 1}"
      clients[id] = client
      puts "=> Client #{id} arrived."

      client.puts 'Server connection established!',
                  "Clients on the server right now: #{clients.length}",
                  "Your id: #{id}"
      while (line = client.gets)
        break if line =~ /quit/

        puts "Client #{id} says: #{line}"
        client.puts 'Received!'
      end

      client.puts 'Server connection terminated'
      client.close
      puts "<= Client #{id} has left."
      clients.delete(id)
    end
  end
rescue Errno::ECONNRESET, Errno::EPIPE => e
  puts e.message
  retry
end
