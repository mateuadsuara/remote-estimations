require 'cgi'

module Web
  class App
    def initialize(estimations)
      @estimations = estimations
    end

    def call(environment)
      if environment["REQUEST_METHOD"] == "POST" && environment["PATH_INFO"] == "/add"
        params = post_params(environment)
        addition = @estimations.add(
          name: params["name"].first,
          description: ""
        )
        return redirect(addition)
      end

      if environment["REQUEST_METHOD"] == "POST" && environment["PATH_INFO"] == "/estimate"
        params = post_params(environment)
        begin
          estimate = @estimations.estimate(
            name: params["name"].first,
            user: params["user"].first,
            optimistic: Integer(params["optimistic"].first),
            realistic: Integer(params["realistic"].first),
            pessimistic: Integer(params["pessimistic"].first)
          )
        rescue
          estimate = Result.failure(:non_numeric_estimation)
        end
        return redirect(estimate)
      end

      if environment["REQUEST_METHOD"] == "POST" && environment["PATH_INFO"] == "/complete"
        params = post_params(environment)
        completion = @estimations.complete(
          name: params["name"].first
        )
        return redirect(completion)
      end

      params = get_params(environment)
      error = params["error"]&.first
      html = render('index', @estimations, error)
      ['200', {'Content-Type' => 'text/html'}, [html]]
    end

    private
    def render(template, estimations, error = nil)
      ERB.new(File.new(File.expand_path(File.dirname(__FILE__) + "/#{template}.erb")).read).result(binding)
    end

    def post_params(environment)
      CGI::parse(environment["rack.input"].gets)
    end

    def get_params(environment)
      CGI::parse(environment["QUERY_STRING"])
    end

    def redirect(result)
      result.succeeded do
        return ['302', {'Location' => '/'}, []]
      end
      result.failed do |error|
        return ['302', {'Location' => "/?error=#{error}"}, []]
      end
    end
  end
end
