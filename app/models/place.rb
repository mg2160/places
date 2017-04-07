class Place
	include ActiveModel::Model
	attr_accessor :id, :formatted_address, :location, :address_components


	def initialize(params={})
		if !params.nil?
			if params[:_id].nil?
				@id=params[:id]
			else
				@id=params[:_id].to_s
			end
			@formatted_address=params[:formatted_address]
			@geometry_hash=params[:geometry].deep_symbolize_keys
			@location=Point.new(@geometry_hash[:geolocation])
			@address_components=Array.new
			if !params[:address_components].nil?
				params[:address_components].each do |r|
				@component=AddressComponent.new(r)
				@address_components << @component
				end
			end
		end
	end

	def self.mongo_client
		Mongoid::Clients.default
	end

	def self.collection
		self.mongo_client[:places]
	end

	def self.load_all(f)
		string_json=File.read(f)
		hash_objects=[]
		hash_objects=JSON.parse(string_json)
		collection.insert_many(hash_objects)
	end

	def self.find_by_short_name(input)
		collection.find({'address_components.short_name': input})  #nested find
		#=>{:short_name=>input}
	end

	def self.to_places(input)
		@places=Array.new
		input.each do |i|
			@place_instance=Place.new(i)
			@places << @place_instance
		end
		return @places
	end

	def self.find(id)
		if id != ''
			@id=id
			element=collection.find(_id: BSON::ObjectId(@id)).first
			if element.nil?
				return nil
			else
				return Place.new(element)
			end
		end
	end

	def self.all(offset=0, limit=0)
		@documents=collection.find.skip(offset).limit(limit)#true
		@my_documents=Array.new
		@documents.each do |d|
			@my_documents << Place.new(d)
		end
		return @my_documents
	end

	def destroy
		self.class.collection.find({_id: BSON::ObjectId(@id)}).delete_one
	end

	def self.get_address_components(sort={}, offset=0, limit=nil)
		#because limit,sort can be nil
		my_query=[ {:$project => {_id: 1, address_components: 1, formatted_address: 1, :'geometry.geolocation' => 1}},
				  {:$unwind => '$address_components'},{:$skip => offset} ]
		if sort != {}
			my_query.insert(2,{:$sort=>sort})
		end						 
		if !limit.nil?
			my_query << {:$limit=>limit}
		end
		collection.find.aggregate(my_query)
	end


	def self.get_country_names
		collection.find.aggregate([{:$unwind=>'$address_components'},
								  {:$match=>{:'address_components.types' => "country"}},
								  {:$group=>{:_id => '$address_components.long_name'}}, 
								  {:$project=>{:_id => 1}}
								  ]).to_a.map {|h| h[:_id]}
		#1-unwind   2-match    3-group    4-project
	end

	def self.find_ids_by_country_code(country_code)
		collection.find.aggregate([{:$match => {:'address_components.short_name' => ""+country_code}},
								   {:$project => {:_id => 1}}]).map {|doc| doc[:_id].to_s}
	end

	def self.near(point,max_meters=0) #class method
		collection.find({:'geometry.geolocation'=>
							{:$near=>{:$geometry=>{type: 'point', coordinates:[point.longitude,point.latitude]} , 
							 :$maxDistance=>max_meters}}})
	end

	def near(max_distance=0) #instance method
		self.class.to_places(self.class.collection.find({:'geometry.geolocation'=>{
															:$near=>{:$geometry=>{type: 'point', coordinates: [@location.longitude,@location.latitude]}, 
																	 :$maxDistance=>max_distance}}}))
	end

	def self.create_indexes
		collection.indexes.create_one({'geometry.geolocation'=>Mongo::Index::GEO2DSPHERE})
	end

	def self.remove_indexes
		collection.indexes.drop_one('geometry.geolocation_2dsphere')
	end

	def find_nearest_place_id(max_distance=0)
		
	end

	def photos(offset=0, limit=nil)
		result=Photo.find_photos_for_place(@id)
		if limit.nil?
			result = result.skip(offset)
		else
			result = result.skip(offset).limit(limit)
		end
		result = result.map {|r| Photo.new(r)}
	end

	def persisted?#returns true if the model instance has been saved to the database
		!@id.nil?
	end

	
end