class WebApp
  def call(environment)
    ['200', {'Content-Type' => 'text/html'}, ['A barebones rack app.']]
  end
end
