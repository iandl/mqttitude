
require 'rubygems'
require 'mqtt'
require 'sinatra/base'
require 'thin'


class App < Sinatra::Base


end


mqtt = Thread.new { 
  MQTT::Client.connect({:username => "scrubber", :password => "scrubber", :remote_host => '127.0.0.1',  :remote_port => 8882}) do |client|
    p "MQTT thread subscribed to: /locations/#"

    client.get('/location/#') do |topic,message|
      puts "MQTT thread received: #{Time.new} -> #{topic}: #{message}"
    end
  end
}

Thin::Server.start App, '0.0.0.0', 8080
c