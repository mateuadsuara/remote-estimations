module Web
  class App
    def call(environment)
      ['200', {'Content-Type' => 'text/html'}, ['A barebones rack app.']]
    end
  end
end
