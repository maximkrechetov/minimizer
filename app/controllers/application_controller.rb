require 'sinatra/base'
require 'sinatra/namespace'
require 'sinatra/json'
require 'haml'

class ApplicationController < Sinatra::Base

  set :haml, :format => :html5
  set :views, File.expand_path('../../views', __FILE__)
  set :public_folder, File.expand_path('../../../public', __FILE__)
  enable :sessions, :method_override

  not_found do
    status 404
    haml :not_found
  end

end