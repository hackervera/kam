require_relative '../kam'
# alphas are 3 contacts from kbucket
# alphas make up 'shortlist'
# send FIND_* request to  alphas in parallel add responses to shortlist
p "bootstrapping: #{Kam.bootstrap}"
p "peers: #{Kam.peers}"
(Kam::CONFIG["files"] || []).each do |file|
  f = File.read(file)
  key = Kam.sha1(f)
  puts "Storing #{key}"
  Storage::DB.put key, f
end

WebServer.run
