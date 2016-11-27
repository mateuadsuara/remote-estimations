require 'cgi'

module Web
  class App
    def initialize(estimations)
      @estimations = estimations
    end

    def call(environment)
      if environment["REQUEST_METHOD"] == "POST"
        action = post_action(environment)
        params = parse_post_params(environment)
        result = @estimations.send(action, **params)
        return redirect(result)
      end

      maybe_error = parse_error(environment)
      html = render('index', @estimations, maybe_error)
      ['200', {'Content-Type' => 'text/html'}, [html]]
    end

    private
    def render(template, estimations, maybe_error)
      ERB.new(File.new(File.expand_path(File.dirname(__FILE__) + "/#{template}.erb")).read).result(binding)
    end

    def post_action(environment)
      environment["PATH_INFO"].scan(/\/([a-z]*)/).first.first.to_sym
    end

    def parse_post_params(environment)
      body = environment["rack.input"].gets

      params = CGI::parse(body).map do |key, values|
        [key.to_sym, values.first]
      end.to_h

      [:optimistic, :realistic, :pessimistic].each do |f|
        params[f] = Integer(params[f]) if params[f]
      end

      params
    end

    def parse_error(environment)
      get_params = CGI::parse(environment["QUERY_STRING"])
      get_params["error"]&.first
    end

    def redirect(result)
      location ||= result.succeeded { '/' }
      location ||= result.failed { |reason| "/?error=#{reason}" }

      return ['302', {'Location' => location}, []]
    end
  end
end
