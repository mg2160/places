class Photo

	include Mongoid::Document
	include ActiveModel::Model

	attr_accessor :id, :location
	attr_writer :contents

	belongs_to :place

	def self.mongo_client
		Mongoid::Clients.default
	end

	def initialize(params={})
		if params != {}
			meta=params[:metadata]
			loc=meta[:location]
			pt=Point.new(loc)
			@id=params[:_id].to_s
			@location=pt
			@place=params[:metadata][:place]
		end
	end

	def place
      	return Place.find(@place.to_s)
	end

	def place= i
		if i != ''
			if i.class == String
				@place = BSON.ObjectId.from_string(i)
			elsif i.class == Place
				@place = BSON.ObjectId(i.id.to_s)
			else
				@place = i
			end
		end
	end

	def persisted?
		if @id.nil?
			return false
		else
			return true
		end
	end

	def save
		if !persisted?
			description = {}
      		description[:filename] = @contents.to_s
		    description[:content_type] = "image/jpeg"
		    description[:metadata] = {}
		    gps = EXIFR::JPEG.new(@contents).gps
      		@contents.rewind #to the beginning of input
			@location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)
			description[:metadata][:location] = @location.to_hash 

			if !@contents.nil?
        		grid_file = Mongo::Grid::File.new(@contents.read,description)
        		@id = self.class.mongo_client.database.fs.insert_one(grid_file).to_s
      		end
		else
			#@location=Point.new(:lng=>gps.longitude, :lat=>gps.latitude)
			update_hash={}
			update_hash[:metadata] = {}
			update_hash[:metadata][:location] = @location.to_hash
			update_hash[:metadata][:place] = @place
			self.class.mongo_client.database.fs.find(:_id => BSON.ObjectId(@id)).update_one(update_hash)
   
		end
		#return @id
	end

	def self.all(offset=0,limit=nil)
		data=self.mongo_client.database.fs.find.skip(offset)
		if !limit.nil?
			data=data.limit(limit)
		end
		data.map {|doc| Photo.new(doc) }
	end

	def self.find(id)
		result=self.mongo_client.database.fs.find(:_id=>BSON::ObjectId(id)).first
		if result.nil?
			return nil
		else
			return Photo.new(result)
		end
	end

	def contents
		my_data = self.class.mongo_client.database.fs.find_one(:_id=> BSON::ObjectId(@id))

    	if !my_data.nil?
      		buffer = ""
      		my_data.chunks.reduce([]) do |x, chunk|
        		buffer << chunk.data.data
        	end
      	end
      	return buffer
	end

	def destroy
		self.class.mongo_client.database.fs.find(:_id=>BSON::ObjectId(@id)).delete_one
	end

	def find_nearest_place_id(max_distance)
		places_ids = Place.near(@location,max_distance).limit(1).projection(_id: 1).map { |doc| doc[:_id] }[0]#[0] bec nearest
		if places_ids.nil?
			return nil
		else
			return BSON::ObjectId(places_ids)
		end
	end

	def self.find_photos_for_place(id)
		if id.class == String
			id = BSON.ObjectId(id)
		end
		self.mongo_client.database.fs.find(:'metadata.place' => id)
	end



end