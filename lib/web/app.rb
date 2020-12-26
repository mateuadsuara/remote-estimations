require 'cgi'

module Web
  class App
    def initialize(estimations)
      @estimations = estimations
    end

    def call(environment)
      method = environment["REQUEST_METHOD"]
      url = environment["PATH_INFO"]

      if method == "POST"
        action = post_action(environment)
        params = post_params(environment)
        result = @estimations.send(action, **params)

        room_url = room_url(room_name(environment))
        location = result.unwrap(room_url) do |failure_reason|
          "#{room_url}?error=#{failure_reason}"
        end
        cookie_header = set_cookie(user: params[:user]) if params[:user]
        return redirect_to(location, cookie_header)
      end

      if url == "/take_to_room"
        room_name = CGI::escape(get_params(environment)["room_name"].first || "")
        return redirect_to(room_url(room_name))
      end

      return redirect_to("#{url}/") unless url.end_with?('/')

      ok(render('index', environment))
    end

    private
    def render(template, environment)
      estimations = @estimations
      maybe_error = parse_error(environment)
      maybe_room_name = room_name(environment)
      maybe_user = get_cookie(environment)[:user]
      ERB.new(File.new(File.expand_path(File.dirname(__FILE__) + "/#{template}.erb")).read).result(binding)
    end

    def escape(string)
      ERB::Util.html_escape(string)
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

    def room_url(room_name)
      if room_name.nil? || room_name.empty?
        '/'
      else
        "/#{room_name}/"
      end
    end

    def url_split(environment)
      environment["PATH_INFO"].rpartition('/')
    end

    def parse_error(environment)
      get_params(environment)["error"]&.first
    end

    def get_params(environment)
      CGI::parse(environment["QUERY_STRING"])
    end

    def redirect_to(location, additional_headers = nil)
      additional_headers ||= {}
      ['302', {'Location' => location}.merge(additional_headers), []]
    end

    def ok(body)
      ['200', {'Content-Type' => 'text/html'}, [body]]
    end

    def set_cookie(values = {})
      cookie = values.map do |k,v|
        "#{k}=#{v}; Path=/; HttpOnly"
      end.join("\n")
      {'Set-Cookie' => cookie}
    end

    def get_cookie(environment)
      CGI::parse(environment["HTTP_COOKIE"] || "").map do |key, values|
        [key.strip.to_sym, values.first]
      end.to_h
    end
  end
end
