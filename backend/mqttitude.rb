require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

set :database_file, "config/database.yml"
set :sessions, false


class Subscription < ActiveRecord::Base
	belongs_to :from, :class_name => "User"  # The one who can read read the location
	belongs_to :to, :class_name => "User"  # The one whose location is read

	def as_json(options = { })
		{
			:type_ => "subscription",
			:id => self.id,
			:from => {:id => self.from.id, :name => self.from.name},
			:to => {:id => self.to.id, :name => self.to.name}
		}
	end
end

class User < ActiveRecord::Base
	validates_presence_of :name
	validates_presence_of :password
	has_many :locations, dependent: :destroy


	has_many :subscriptions_from, :foreign_key => "from_id", :class_name => "Subscription"
	has_many :subscriptions, :through => :subscriptions_from, :source => :from, :class_name => "User" # user that I'm receiving location updates fromq 

	has_many :subscriptions_to, :foreign_key => "to_id", :class_name => "Subscription"
	has_many :subscribers, :through => :subscriptions_to, :source => :to, :class_name => "User" # user that receive my location updates 

	before_create :setup
	after_create :addSubscriptionToSelf

	def isPwValid?(plain)
		self.isPbkdf2Valid?(plain)
	end

	def addSubscriptionFrom(user)
	s = Subscription.create(:from => user, :to => self)
	s.save()
	end

	def addSubscriptionTo(user)
	s = Subscription.create(:from => self, :to => user)
	s.save()
	end

	def as_json(options = { })
		{
			:type_ => "user",
			:id => self.id,
			:name => self.name,
		}
	end

	def self.randomString(length=12)
		o = [('a'..'z'),('A'..'Z'), (0..9)].map{|i| i.to_a}.flatten
			string  =  (0...length).map{ o[rand(o.length)] }.join
	end

		def hashPw(plain)
			User.pbkdf2Hash(plain)
		end

		def isPbkdf2Valid?(plain)
			current = pkdf2Detoken(self.password)
			puts "Current pw hash: #{current[:hashed_password]}"
			puts "Hashed input: #{User.pbkdf2Hash(plain, current[:salt], current[:iterations], current[:hash_function])}"
			self.password.eql? User.pbkdf2Hash(plain, current[:salt], current[:iterations], current[:hash_function]) 
		end

		def pkdf2Detoken(pw)
			Hash[[:marker, :hash_function, :iterations, :salt, :hashed_password].zip(pw.split('$'))]
		end
		
		def self.pbkdf2Hash(plain, salt=User.randomString, iterations=901, hash_function="sha256", key_length=24)
			hashHex = PBKDF2.new(:password=>plain, :salt=>salt, :iterations=>iterations.to_i, :hash_function=>hash_function, :key_length=>key_length).bin_string
			hashBase64 = Base64.encode64(hashHex).gsub(/\n/, ''); #base64encode seems to add a newline character
			return "PBKDF2$#{hash_function}$#{iterations}$#{salt}$#{hashBase64}"
		end

	private

		def setup
			self.password = hashPw(self.password)
			self.key = User.randomString(16)
		end

		def addSubscriptionToSelf
			addSubscriptionTo(self)
		end


end

class Location < ActiveRecord::Base
	belongs_to :user

	def as_json(options = { })
		{
			:type_ => "location",
			:id => self.id,
			:lat => self.lat,
			:lon => self.lon,
			:tst => self.tst,
			:acc => self.acc,
			:alt => self.alt,
			:vac => self.vac,
			:dir => ""
		}
	end

	def tst
		Date.new(self.tst).to_time.to_i
	end
end


mqtt = Thread.new { 
	MQTT::Client.connect({:username => "mqttitude", :password => "mqttitude", :remote_host => '127.0.0.1',  :remote_port => 8882}) do |client|
		p "MQTT thread subscribed to: /location/#"

		client.get('/location/#') do |topic,message|
			puts "MQTT received: #{Time.new} -> #{topic}: #{message}"

			json = JSON.parse(message)
			user = User.find_by name: topic.split("/")[2]
			return if user.nil?                                   
			location = Location.create(lat: json['lat'], lon: json['lon'], tst: Time.at(json['tst'].to_i), acc: json['acc'], user_id: user.id)
		end
	end
}

class Mqttitude < Sinatra::Application
	register Sinatra::Can

	ability do |user|
		  alias_action :create, :read, :update, :destroy, :to => :crud

		puts "- Checking authoriztion for user id: #{user.id} "
		can :crud, User do |u|
	  	user && u.id == user.id
	  end
	end

	before do
		content_type :json
	end

	helpers do
		def json(json)
			MultiJson.dump(json, pretty: true)
		end
		def current_user
			@current_user
		end
		def auth_key?
			params[:user_id] && params[:user_key]
		end
		def auth_hmac?
			false
		end
	  def authenticate!
	  	puts "Authenticating API call"

	  	if auth_key?
	  	puts "- via key (#{params[:user_id]}, #{params[:user_key]}"

	  		u = User.find(params[:user_id])
	  		if u.nil? || u.key != params[:user_key]
	  			puts "- auth failed"
	  			error 401
	  		else 
	  			puts "- auth succeeded"
	  			@current_user = u
	  			puts "- @current_user == #{current_user()}"
	  		end
	  	elsif auth_hmac?
	  		puts "- via hmac"
	  		error 401
	  	else
	  		puts "- no auth schemes left"
	  		error 401
	  	end
	  end
	end

	namespace "/api/v1" do
			# API root for API version 1
		get "/" do
			json({type_: "api", version: 1, namespace: "/v1"})
		end

		namespace "/users" do 

			# Create user
			post '/' do
				User.create(name: params[:name], password: params[:password])
			end

			# Get user according to auth parameters
			get '/me' do 
				authenticate!
				current_user().to_json()
			end 

			# Get user 
			get '/:id' do	
				authenticate!
				load_and_authorize! User
				@user.to_json()
			end

			# Delete user
			delete '/:id' do
				authenticate!
				load_and_authorize! User
				User.remove(:id)
			end


			# Get locations of user
			get '/:id/locations' do
				authenticate!
				load_and_authorize! User
				@user.locations.to_json()
			end

			# Get people that user is sharing his location with 
			get '/:id/subscribers' do
				authenticate!
				load_and_authorize! User
				s = Subscription.where(to_id: params[:id])
				s.to_json()
			end

			# Share location with other user 
			post '/:id/subscribers' do
				authenticate!
				load_and_authorize! User

				from = User.find(params[:from_id])
				@user.shareTo(@from)
			end 

			# Revoke location sharing with other user 
			delete '/:id/subscribers/:subscription_id' do
				authenticate!
				load_and_authorize! User

				s = Subscription.destroy(:subscription_id)
			end 

			# Get people that are sharing their location with user 
			get '/:id/subscriptions' do
				authenticate!
				load_and_authorize! User
				s = Subscription.where(from_id: params[:id])
				s.to_json()
			end

			# Unsubscribe from a users locations
			delete '/:id/subscriptions/:subsciption_id' do
				authenticate!
				load_and_authorize! User

				s = Subscription.destroy(:subscription_id)
			end 
		end 

		# Authenticate to receive API access to protecte resources
		post '/authenticate' do
			content_type :json
			@user = User.find_by name: params[:name]
			error 401 if @user.nil?
			if @user.isPwValid?(params[:password]) 
				json({id: @user.id, key: @user.key})
			end
		end
	end
	
	# API root
	get "/api" do
		json({apis: [{type_: "api", version: 1, namespace: "/api/v1"}]})
	end



	# Catch all for unspecified routes to throw 404
	wildcard = lambda do
			error 404
	end
	get  '/*', &wildcard
	post '/*', &wildcard
	put '/*', &wildcard
	patch '/*', &wildcard
	delete '/*', &wildcard

	error 404 do
		json(type_: "error", code: 404, message: "ressource not found")
	end

	# User authenticated but no privileges to access ressource or wrong credentials
	error 401 do
		json(type_: "error", code: 401, message: "access denied")
	end

	# User not authenticated
	error 403 do
		json(type_: "error", code: 403, message: "forbidden")
	end
end

