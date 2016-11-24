$: << File.expand_path('lib/', File.dirname(__FILE__))
require 'web/app'
require 'core/estimations'

run Web::App.new(Core::Estimations.new)
