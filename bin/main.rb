require_relative '../kam'
# alphas are 3 contacts from kbucket
# alphas make up 'shortlist'
# send FIND_* request to  alphas in parallel add responses to shortlist
p "bootstrapping: #{Kam.bootstrap}"
Kam::CONFIG["keys"].each do |key|
  puts "Storing #{key}"
  Storage::DB.put Kam.sha1(key), key
end rescue nil

puts "peers: #{Kam.peers}"
puts "alphas: #{alphas = Kam.alphas(Kam.sha1("boom"))}"

nodes = alphas
found_values = []
counter = 0
while found_values.empty?
  counter += 1
  puts "found nodes: #{nodes = Kam.find_value(nodes, Kam.sha1("boom"))}"
  puts "found value: #{found_values = nodes.select { |n| n["nodeid"] == Kam.sha1("boom") } }"
  break if counter > 5
end
p "value: #{found_values}"

#puts "closer nodes: #{Kam.find_value(found, Kam.sha1("monkey"))}"
#puts "peers: #{Kam.peers}"
RpcServer.start
