require 'sinatra/base'

Dir.glob('./app/{controllers}/*.rb').each { |file| require_relative file }
map('/') { run IndexController }