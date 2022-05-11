# frozen_string_literal: true

require 'socket'

clients = {}
actions = %w[1 2 3]
game_state = {
  matches: 33,
  lastTurn: {
    client_id: '',
    action: ''
  }
}
set_game_state = lambda { | new_matches, new_cliend_id, new_action |
  game_state[:matches] = new_matches
  game_state[:lastTurn][:client_id] = new_cliend_id
  game_state[:lastTurn][:action] = new_action
  game_state
}
reset_game = lambda {
  set_game_state.call(33, '', '')
}
two_players_appeared = -> { clients.length>1 }
action_reducer = lambda { | client_id, action |
  return false unless actions.include? action

  new_matches = game_state[:matches]
  if client_id == game_state[:lastTurn][:client_id] && game_state[:matches]>1
    new_matches += game_state[:lastTurn][:action].to_i
  end
  new_matches -= action.to_i
  set_game_state.call(new_matches, client_id, action)
  true
}


config = { host: 'localhost',
           port: 2000 }
server = TCPServer.new config[:host], config[:port]
puts "Server running on #{config[:host]}:#{config[:port]}"
begin
  loop do
    Thread.start(server.accept) do |client|
      if two_players_appeared.call
        client.puts 'Too many clients on the server. Try join later',
                    'Server connection terminated'
        client.close
        # return 0
        # break
        # else
      end

      id = :"player_#{clients.length + 1}"
      clients[id] = client
      puts "=> Client #{id} arrived."

      client.puts 'Server connection established!',
                  "Your id: #{id}"

      clients.each do |client_id, client|
        client.puts "Clients on the server right now: #{clients.length}#{two_players_appeared.call ? '. Two players appeared. GAME START!' : ''}"
      end

      while (action = client.gets.strip)
        unless two_players_appeared.call
          client.puts 'Second player did not arrived yet. Be patient!'
          next
        end
        am_i_prev_player = (id == game_state[:lastTurn][:client_id])
        if action_reducer.call(id, action)
          game_is_over = (game_state[:matches] <= 0)
          message = if game_is_over
                      "Game is over!\n#{game_state[:lastTurn][:client_id]} has taken all the matches!\nThe winner is #{clients.keys.detect { |client_id | !(client_id == game_state[:lastTurn][:client_id]) } }!"
                    else
                      "#{id} #{am_i_prev_player ? 'changes their mind and ' : ''} takes #{action} matches.\nMatches on the table: #{game_state[:matches]}"
                    end
          clients.each do |client_id, client|
            client.puts message
          end
          break if game_is_over
        else
          client.puts "Unknown action: #{action}. Try something else!"
        end
      end

      client.puts 'Server connection terminated'
      puts "<= Client #{id} has left."
      clients.delete(id)
      client.close

    end
  end
rescue Errno::ECONNRESET, Errno::EPIPE => e
  puts e.message
  retry
end
