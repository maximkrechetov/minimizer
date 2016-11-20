require_relative 'application_controller'
require_relative '../../lib/minimizer'

class IndexController < ApplicationController

  get '/' do
    if params[:site]
      begin
        minimizer = Minimizer.new(params[:site])
      rescue Minimizer::IncorrectURIError
        halt(404)
      end

      return minimizer.minimize
    end

    if params[:hash]
      begin
        minimizer = Minimizer.new(params[:hash])
      rescue Minimizer::IncorrectURIError
        halt(404)
      end

      return json minimizer.accordance_hash
    end

    haml :default
  end

end