require 'leveldb'
module Storage
  DB = LevelDB::DB.new(Kam::CONFIG["storage"])
  class << self
    # structure should be hash with nodeid, ip, and port
    def update_bucket(structure)
      # generate timestamp
      time            = Time.now.to_i
      # determine bucket for nodeid
      bucket          = Kam.bucket(Kam.distance(structure["nodeid"]))
      # grab current bucket members
      current_members = JSON.parse(DB.get(bucket.to_s) ) rescue []
      while current_members.length >= 20
        #remove member with oldest timestamp to make room
        marked = current_members.sort_by { |m| m["timestamp"] }.first
        current_members.delete(marked)
      end
      DB.put(bucket.to_s, current_members.to_json)
      node_ids               = current_members.map { |c| c["nodeid"] }
      structure["timestamp"] = time
       if   node_ids.include?(structure["nodeid"])
         p "#{structure} already in bucket"
       else
         current_members << structure
         DB.put(bucket.to_s, current_members.to_json)
         p "Adding #{structure} to bucket #{bucket}"
       end
    end

    def bucket_members(bucket)
      members = JSON.parse(DB.get(bucket.to_s)) rescue [].map { |m| JSON.parse m }
      if members.length < 20
        Kam.peers
      end
    end

    def find_value(key)
      DB.get(key)
    end

    def peers
      DB.each(from: "0", to: "160").map{|_,v| JSON.parse(v) rescue next}.compact.flatten
    end
  end
end