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
puts "found nodes: #{found = Kam.find_value(alphas, Kam.sha1("boom"))}"
puts "found value: #{found.select{|n| n["nodeid"] == Kam.sha1("boom") } }"
#puts "closer nodes: #{Kam.find_value(found, Kam.sha1("monkey"))}"
puts "peers: #{Kam.peers}"
RpcServer.start
