require_relative '../kam'
# alphas are 3 contacts from kbucket
# alphas make up 'shortlist'
# send FIND_* request to  alphas in parallel add responses to shortlist
p "bootstrapping: #{Kam.bootstrap}"
Kam::CONFIG["keys"].each do |key|
  puts "Storing #{key}"
  Storage::DB.put Kam.sha1(key), key
end rescue nil

p Kam.lookup(Kam.sha1("monster"))
RpcServer.start
