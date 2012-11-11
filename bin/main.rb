require_relative '../lib/kam'

p "bootstrapping: #{Kam.bootstrap}"
p "peers: #{Kam.peers}"

WebServer.run
