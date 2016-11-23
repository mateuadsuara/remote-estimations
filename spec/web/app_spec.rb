require 'web/app'

RSpec.describe Web::App do
  it 'responds ok' do
    expect(status_code(get_response({}))).to eq 200
  end

  def get_response(environment = nil)
    described_class.new.call(environment)
  end

  def status_code(response)
    Integer(response[0])
  end
end
