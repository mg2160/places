class Point
	attr_accessor :latitude, :longitude

	def initialize(params)
		if params[:type].nil?
			@latitude=params[:lat]
			@longitude=params[:lng]
		else
			params=params.deep_symbolize_keys
			@longitude=params[:coordinates][0]
			@latitude=params[:coordinates][1]	
		end	
	end

	def to_hash
		@hash={}
		@hash[:type] = "Point"
		@hash[:coordinates] = [@longitude,@latitude]
		return @hash
	end
end