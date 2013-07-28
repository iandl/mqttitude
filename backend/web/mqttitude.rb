require 'rubygems'
require 'sinatra'
require 'warden'
require 'haml'
require 'ohm'
require 'date'
require 'json'
require 'ohm/json'



class Position < Ohm::Model
  attribute :timestamp
  attribute :lat
  attribute :long

  reference :year, :Year
      index :year

  reference :month, :Month
      index :month

  reference :day, :Day
      index :day

  def to_json(a)
    {:ts => timestamp, :lat => lat, :long => long}.to_json
  end
end

class Year < Ohm::Model
  attribute :y
  index :y

  attribute :user_id
  index :user_id
  list :positions, :Position

  def to_json(a)
    y.to_json
  end
end

class Month < Ohm::Model
  attribute :y
  index :y
  attribute :m
  index :m

  attribute :user_id
  index :user_id
  list :positions, :Position

  def to_json(a)
    m.to_json
  end

end

class Day < Ohm::Model
  attribute :y
  index :y
  attribute :m
  index :m
  attribute :d
  index :d

  attribute :user_id
  index :user_id
  list :positions, :Position

   def to_json(a)
    d.to_json
  end
end

class User < Ohm::Model
  attribute :name
  unique :name

  attribute :password
  list :positions, :Position

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

get '/' do
  haml :index
end

get '/test' do
 User.create :name=>'bucks', :password => 'test'
end

get '/users/:name' do
	@user = userFromParams()
	haml :user
end

get '/users/:name/edit' do 
  #TODO
end

put '/users/:name' do 
  #TODO
end

delete '/users/:name' do 
  #TODO
end


get '/users/:name/dates' do 
  content_type :json
  @user = userFromParams()
  Day.find(:user_id => @user.id).to_json
end
get '/users/:name/dates/years' do 
  content_type :json

  @user = userFromParams()
  @years = Year.find(:user_id => @user.id).sort_by(:y, :order => "DESC").to_json 
end

get '/users/:name/dates/years/:year/months' do 
  content_type :json
  @user = userFromParams
  Month.find(:y => params[:year], :user_id => @user.id).sort_by(:m, :order => "DESC").to_json
end

get '/users/:name/dates/years/:year/months/:month/days' do 
  content_type :json
  @user = userFromParams()
  Day.find(:y => params[:year], :m => params[:month], :user_id => @user.id).sort_by(:d, :order => "DESC").to_json
end

get '/users/:name/positions' do 
  content_type :json
	@user = userFromParams()
  if @user.positions
    positions.to_json()
  else 
    halt 404
  end
end
get '/users/:name/positions/:year' do 
  content_type :json
  @user = userFromParams()
  year = Year.find(:y => params[:year], :user_id => @user.id).first();  
  if year and year.positions 
    year.positions.sort_by(:timestamp, :order => "DESC ALPHA").to_json()
  else
    halt 404
  end
end
get '/users/:name/positions/:year/:month' do 
  @user = userFromParams()
  month = Month.find(:y => params[:year], :m => params[:month], :user_id => @user.id).first()  
  if month and month.positions 
    month.positions.sort_by(:timestamp, :order => "DESC ALPHA").to_json()
  else
    halt 404
  end
end
get '/users/:name/positions/:year/:month/:day' do 
  @user = userFromParams()
  day = Day.find(:y => params[:year], :m => params[:month], :d => params[:day], :user_id => @user.id).first()
  if day and day.positions 
    day.positions.to_json()
  else
    halt 404
  end
end





post '/users/:name/positions' do 
  user = userFromParams()

  lat = params[:lat]
  long = params[:long]
  ts = params[:timestamp]


  #TODO: parse from timestamp
  y = params[:y]
  m = params[:m]
  d = params[:d]

  print "Data: lat: #{params[:lat]}, long #{params[:long]}, y #{params[:y]} m  #{params[:m]}  d #{params[:d]} ts  #{params[:timestamp]}"
  print params


  position = Position.create :lat => lat, :long => long, :timestamp => ts
  user.positions.push(position)

  year = Year.find(:y => y, :user_id => user.id).first();  
  if year.nil?
    print "Creating year\n" 
    year = Year.create :y => y, :user_id => user.id
  end


   month = Month.find(:y => y, :m => m, :user_id => user.id).first();
   if month.nil? 
     print "Creating month" 
     month = Month.create :y => y, :m => m, :user_id => user.id
   end

   day = Day.find(:y => y, :m => m, :d => d, :user_id => user.id).first();
   if day.nil? 
     print "Creating day" 
     day = Day.create :y => y, :m => m, :d => d, :user_id => user.id
   end

   year.positions.push(position);
   month.positions.push(position);
   day.positions.push(position);

   position.year = year; 
   position.month = month; 
   position.day = day; 
end


delete '/users/:name/positions' do 
	@user = userFromParams()
	@user.positions.each do |p|
		@user.positions.delete(p)
		p.delete();
	end
	#status 200
	redirect '/users/:name/positions'
end

delete '/users/:name/positions/:id' do
	print "deleting #{params[:id]}"
	p = Position.all[params[:id]]
	unless p.nil? then 
		userFromParams().positions.delete(p)
		p.delete()
	end
	redirect "/users/#{params[:name]}/positions"
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
      redirect "/users/#{warden_handler.user.name}" 
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
