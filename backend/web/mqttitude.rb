require 'rubygems'
require 'sinatra'
require 'warden'
require 'haml'
require 'ohm'
require 'date'

class Position < Ohm::Model
  attribute :timestamp
  attribute :lat
  attribute :long
end

class User < Ohm::Model
  attribute :name
  unique :name
  attribute :password
  list :positions, :Position
  index :name

  def authenticate(pw)
    puts "user.authenticate\n"
    puts pw.inspect() 
    puts self.password.inspect()
    puts "pw: #{password}, hash: #{hash(pw)}\n"
    puts self.password == hash(pw)
    return self.password == hash(pw);
  end

  def hash(pw) 
    return pw; # TODO: hash   
  end
end

class Mqttitude < Sinatra::Application


configure :production do
  Ohm.connect(:host => "localhost", port => 6379)
end





def userFromParams()
        User.with(:name, params[:name])
end
  def warden_handler
    env['warden']
  end
 
  def check_authentication
    print "checking auth"
    unless warden_handler.authenticated?
      "not authenticated"
      redirect '/login'
    end
  end
 
  def current_user
    warden_handler.user
  end
helpers do


end

get '/' do
  haml :index
end

get '/test' do
 User.create :name=>'bucks', :password => 'test'
end

get '/user/:name' do
  print "FOOO"
	check_authentication
	@user = userFromParams()
	haml :user
end

get '/user/:name/edit' do 

end

put '/user/:name' do 

end

delete '/user/:name' do 
end

get '/user/:name/positions' do 
	@user = userFromParams()

haml :positions
end

delete '/user/:name/positions' do 
	@user = userFromParams()
	@user.positions.each do |p|
		@user.positions.delete(p)
		p.delete();
	end
	#status 200
	redirect '/user/:name/positions'
end

delete '/user/:name/positions/:id' do
	print "deleting #{params[:id]}"
	p = Position.all[params[:id]]
	unless p.nil? then 
		userFromParams().positions.delete(p)
		p.delete()
	end
	redirect "/user/#{params[:name]}/positions"
end

  get '/admin' do
    @users = User.all
    haml :admin
  end



  get "/login" do
    print "login"
    haml :login
  end
 
  post "/session" do
    print "session post received"
    warden_handler.authenticate!
    if warden_handler.authenticated?
      print "Authenticated";
      redirect "/user/#{warden_handler.user.name}" 
    else
      print "Not authenticated";
      redirect "/"
    end
  end
 
  get "/logout" do
    warden_handler.logout
    redirect '/login'
  end
 
  post "/unauthenticated" do
    redirect "/"
  end




  use Rack::Session::Cookie, :key => 'session',
                             :domain => "localhost",
                             :expire_after => 14400, # In seconds
                             :secret => 'super_secret_for_testing'


  use Warden::Manager do |manager|
    manager.default_strategies :password
    manager.failure_app = Mqttitude
    manager.serialize_into_session {|user| user.id}
    manager.serialize_from_session {|id| User.with(:id, id)}
  end

  Warden::Manager.before_failure do |env,opts|
    env['REQUEST_METHOD'] = 'POST'
  end

  Warden::Strategies.add(:password) do
    def valid?
      params["name"] || params["password"]
    end
 
    def authenticate!
      print "authenticating\n"
    	user = User.with(:name, params["name"])
      print user
      if user && user.authenticate(params["password"])
            print "success"
        success!(user)
      else
      print "fail"

        fail!("Could not log in")
      end
    end
  end
end
