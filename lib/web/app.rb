require 'cgi'

module Web
  class App
    def initialize(estimations)
      @estimations = estimations
    end

    def call(environment)
      if environment["REQUEST_METHOD"] == "POST" && environment["PATH_INFO"] == "/add"
        params = params(environment)
        @estimations.add(
          name: params["name"].first,
          description: ""
        )
        return ['302', {'Location' => '/'}, []]
      end

      if environment["REQUEST_METHOD"] == "POST" && environment["PATH_INFO"] == "/estimate"
        params = params(environment)
        begin
          @estimations.estimate(
            name: params["name"].first,
            user: params["user"].first,
            optimistic: Integer(params["optimistic"].first),
            realistic: Integer(params["realistic"].first),
            pessimistic: Integer(params["pessimistic"].first)
          )
        rescue
        end
        return ['302', {'Location' => '/'}, []]
      end

      if environment["REQUEST_METHOD"] == "POST" && environment["PATH_INFO"] == "/complete"
        params = params(environment)
        @estimations.complete(
          name: params["name"].first
        )
        return ['302', {'Location' => '/'}, []]
      end

      html = render('index', @estimations)
      ['200', {'Content-Type' => 'text/html'}, [html]]
    end

    private
    def render(template, estimations)
      ERB.new(File.new(File.expand_path(File.dirname(__FILE__) + "/#{template}.erb")).read).result(binding)
    end

    def params(environment)
      CGI::parse(environment["rack.input"].gets)
    end
  end
end
