require_relative '../kam'

p "bootstrapping: #{Kam.bootstrap}"
p "peers: #{Kam.peers}"

WebServer.run
