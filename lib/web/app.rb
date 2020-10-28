require 'cgi'

module Web
  class App
    def initialize(estimations)
      @estimations = estimations
    end

    def call(environment)
      if environment["REQUEST_METHOD"] == "POST"
        action = post_action(environment)
        params = post_params(environment)
        result = @estimations.send(action, **params)
        return redirect_action(environment, result)
      end

      if environment["REQUEST_METHOD"] == "GET" &&
        url = environment["PATH_INFO"]
        unless url.end_with?('/')
          return ['302', {'Location' => "#{url}/"}, []]
        end
      end

      maybe_error = parse_error(environment)
      maybe_room_name = room_name(environment)
      html = render('index', @estimations, maybe_error, maybe_room_name)
      ['200', {'Content-Type' => 'text/html'}, [html]]
    end

    private
    def render(template, estimations, maybe_error, maybe_room_name)
      ERB.new(File.new(File.expand_path(File.dirname(__FILE__) + "/#{template}.erb")).read).result(binding)
    end

    def escape_quotes(string)
      string.gsub('"', "&quot;")
    end

    def post_action(environment)
      url_split(environment).last.to_sym
    end

    def post_params(environment)
      body = environment["rack.input"].gets

      params = CGI::parse(body).map do |key, values|
        [key.to_sym, values.first]
      end.to_h

      [:optimistic, :realistic, :pessimistic].each do |f|
        params[f] = Integer(params[f]) if params[f]
      end

      params.merge(room: room_name(environment))
    end

    def room_name(environment)
      url_split(environment).first[1..-1]
    end

    def room_url(environment)
      room = room_name(environment)
      if room
        "/#{room}/"
      else
        '/'
      end
    end

    def url_split(environment)
      environment["PATH_INFO"].rpartition('/')
    end

    def parse_error(environment)
      get_params = CGI::parse(environment["QUERY_STRING"])
      get_params["error"]&.first
    end

    def redirect_action(environment, result)
      room_url = room_url(environment)

      location ||= result.succeeded { room_url }
      location ||= result.failed { |reason| "#{room_url}?error=#{reason}" }

      return ['302', {'Location' => location}, []]
    end
  end
end
