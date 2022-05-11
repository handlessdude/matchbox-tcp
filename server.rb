# frozen_string_literal: true

require 'socket'

clients = {}
actions = ['1', '2', '3']
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
  return true
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
      end

      id = :"player_#{clients.length + 1}"
      clients[id] = client
      puts "=> Client #{id} arrived."

      client.puts 'Server connection established!',
                  "Your id: #{id}",
                  "Clients on the server right now: #{clients.length}#{two_players_appeared.call ? '. Two players appeared. GAME START!' : ''}"

      while (action = client.gets)
        # break if line =~ /quit/
        unless two_players_appeared.call
          client.puts 'Second player did not arrived yet. Be patient!'
          next
        end
        am_i_prev_player = (id == game_state[:lastTurn][:client_id])
        if action_reducer.call(id, action)
          game_is_over = (game_state[:matches] <= 0)
          message = if game_is_over
                      "Game is over!\n#{game_state[:lastTurn][:client_id]} has taken all the matches!\nThe winner is #{clients.detect { |client_id| client_id != game_state[:lastTurn][:client_id] } }!"
                    else
                      "client #{id} #{am_i_prev_player ? 'changes their mind and ' : ''} takes #{action} matches.\nMatches on the table: #{game_state[:matches]}"
                    end
          client.puts message
          if game_is_over
            reset_game.call
            clients.each { |client_id, client|
              client.puts 'Server connection terminated'
              puts "<= Client #{id} has left."
              client.close
              clients.delete(id)
            }
          end
        else
          client.puts "Unknown action: #{action}. Try something else!"
        end

      end

    end
  end
rescue Errno::ECONNRESET, Errno::EPIPE => e
  puts e.message
  retry
end
