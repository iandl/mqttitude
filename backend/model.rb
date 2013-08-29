require "base64"
require 'sinatra/base'

module Sinatra
	module Model


		class Subscription < ActiveRecord::Base
			belongs_to :from, :class_name => "User"  # The one who can read read the location
			belongs_to :to, :class_name => "User"  # The one whose location is read
		end

		class User < ActiveRecord::Base
			validates_presence_of :name
			validates_presence_of :password
			has_many :locations, dependent: :destroy


			has_many :subscriptions_from, :foreign_key => "from_id", :class_name => "Subscription"
			has_many :following, :through => :subscriptions_from, :source => :from, :class_name => "User"

			has_many :subscriptions_to, :foreign_key => "to_id", :class_name => "Subscription"
			has_many :follower, :through => :subscriptions_to, :source => :to, :class_name => "User"

			before_create :setup
			after_create :shareToSelf

			def shareToSelf
				shareTo(self)
			end

			def shareTo(user)
			s = Subscription.create(:from => user, :to => self)
			s.save()
			end

			def isPwValid?(plain)
				self.isPbkdf2Valid?(plain)
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
			


			def self.pbkdf2Hash(plain, salt="iX/E7I6P+bdLhxOG", iterations=901, hash_function="sha256", key_length=24)
			hashHex = PBKDF2.new(:password=>plain, :salt=>salt, :iterations=>iterations.to_i, :hash_function=>hash_function, :key_length=>key_length).bin_string
			hashBase64 = Base64.encode64(hashHex).gsub(/\n/, ''); #base64encode seems to add a newline character
			#puts "HashBase64: #{hashBase64}hashBase64"
			return "PBKDF2$#{hash_function}$#{iterations}$#{salt}$#{hashBase64}"
			end

			def to_json(*a)
			{
				"name" => self.name,
				"key" => self.key
			}.to_json(*a)
			end

			def self.randomString(length=12)
				o = [('a'..'z'),('A'..'Z'), (0..9)].map{|i| i.to_a}.flatten
					string  =  (0...length).map{ o[rand(o.length)] }.join
			end
		private
			def setup

				self.password = hashPw(self.password)
				self.key = User.randomString(16)
			end
		end

		class Location < ActiveRecord::Base
			belongs_to :user
		end  

	end
end