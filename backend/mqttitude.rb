require 'rubygems'
require 'mqtt'
require 'mysql2'
require 'yaml'
require 'json'
require 'sinatra' 
require 'sinatra/activerecord'

set :database_file, "config/database.yml"

class User < ActiveRecord::Base
  validates_presence_of :name
  validates_presence_of :password
  has_many :locations, dependent: :destroy
end

class Location < ActiveRecord::Base
	belongs_to :user
end


mqtt = Thread.new { 
  MQTT::Client.connect({:username => "scrubber", :password => "scrubber", :remote_host => '127.0.0.1',  :remote_port => 8882}) do |client|
    p "MQTT thread subscribed to: /location/#"

    client.get('/location/#') do |topic,message|
      puts "MQTT received: #{Time.new} -> #{topic}: #{message}"

      json = JSON.parse(message)
      user = User.find_by_name(topic.split("/")[2])                                           
      location = Location.create(lat: json['lat'], lon: json['lon'], tst: Time.at(json['tst'].to_i), acc: json['acc'])
    end
  end
}


class Mqttitude < Sinatra::Application

  get '/users' do
  	@users = User.all
	end

	get '/users/:id' do
  	@user = User.find(params[:id])
	end
end


