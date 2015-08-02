require 'rubygems'
require 'sinatra'
require 'pry'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'my_lil_string'



get '/' do
  erb :get_name
end

post '/welcome' do
  session[:username] = params[:username]
end

get '/welcome' do
  erb :welcome
end