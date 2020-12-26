$: << File.expand_path('lib/', File.dirname(__FILE__))
require 'web/app'
require 'core/estimations'

use Rack::Static, :urls => ["/styles", "/fonts", "/favicon.ico", "/robots.txt"], :root => "public", :header_rules => [
  [:all, {'Cache-Control' => 'public, max-age=31536000'}]
]

run Web::App.new(Core::Estimations.new)
