$: << File.expand_path('lib/', File.dirname(__FILE__))
require 'web/app'
require 'core/estimations'

use Rack::Static, :urls => ["/styles", "/fonts", "/favicon.ico", "/robots.txt"], :root => "public"

run Web::App.new(Core::Estimations.new)
