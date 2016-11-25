require 'web/app'
require 'rack/test'
require 'nokogiri'

RSpec.describe Web::App do
  include  Rack::Test::Methods
  let(:estimations) { spy(Core::Estimations) }
  let(:app) { described_class.new(estimations) }

  let(:html) { Nokogiri::HTML(last_response.body) }

  def given(method, return_value)
    expect(estimations).to receive(method).and_return(return_value)
  end

  before(:each) do
    [:add, :estimate, :complete].each do |action|
      allow(estimations).to receive(action).and_return(Result.success)
    end
  end

  it 'on index shows in progress estimations' do
    given(:in_progress, [
      {name: "name1", estimates: ["user1", "user2"]},
      {name: "name2", estimates: ["user1"]}
    ])

    get "/"

    in_progress = html.css('[data-in-progress]')

    expect(in_progress[0].css('[data-estimation-name]').map(&:text)).to eq ["name1"]
    expect(in_progress[0].css('[data-user-name]').map(&:text)).to eq ["user1", "user2"]

    expect(in_progress[1].css('[data-estimation-name]').map(&:text)).to eq ["name2"]
    expect(in_progress[1].css('[data-user-name]').map(&:text)).to eq ["user1"]
  end

  it 'on index shows completed estimations' do
    given(:completed, [
      {
        name: "name1",
        estimate: 6.5,
        estimates: {
          "user1" => {
            optimistic: 1,
            realistic: 4,
            pessimistic: 8
          },
          "user2" => {
            optimistic: 4,
            realistic: 4,
            pessimistic: 4
          }
        }
      },
      {
        name: "name2",
        estimate: nil,
        estimates: {}
      }
    ])

    get "/"

    completed = html.css('[data-completed]')

    expect(completed[0].css('[data-estimation-name]').map(&:text)).to eq ["name1"]
    expect(completed[0].css('[data-final-estimate]').map(&:text)).to eq ["6.5"]

    expect(completed[0].css('[data-user-estimate]').length).to eq 2

    expect(completed[0].css('[data-user-estimate]')[0].css('[data-user-name]').map(&:text)).to eq ["user1"]
    expect(completed[0].css('[data-user-estimate]')[0].css('[data-user-estimates]').map(&:text)).to eq ["1/4/8"]

    expect(completed[0].css('[data-user-estimate]')[1].css('[data-user-name]').map(&:text)).to eq ["user2"]
    expect(completed[0].css('[data-user-estimate]')[1].css('[data-user-estimates]').map(&:text)).to eq ["4/4/4"]

    expect(completed[1].css('[data-user-estimate]').length).to eq 0

    expect(completed[1].css('[data-estimation-name]').map(&:text)).to eq ["name2"]
    expect(completed[1].css('[data-final-estimate]').map(&:text)).to eq ["-"]
  end

  it 'adds an estimation' do
    post "/add", {"name"=>"::the name::"}

    expect(estimations).to have_received(:add).with(
      name: "::the name::",
      description: ""
    )
  end

  it 'submits an estimate' do
    post "/estimate", {
      "name"=>"::the name::",
      "user"=>"::the user::",
      "optimistic"=>"1",
      "realistic"=>"4",
      "pessimistic"=>"8"
    }

    expect(estimations).to have_received(:estimate).with(
      name: "::the name::",
      user: "::the user::",
      optimistic: 1,
      realistic: 4,
      pessimistic: 8
    )
  end

  it 'does not submit an invalid estimate' do
    post "/estimate", {
      "name"=>"::the name::",
      "user"=>"::the user::",
      "optimistic"=>"",
      "realistic"=>"",
      "pessimistic"=>""
    }

    expect(estimations).to_not have_received(:estimate)
  end

  it 'completes an estimation' do
    post "/complete", {"name"=>"::the name::"}

    expect(estimations).to have_received(:complete).with(
      name: "::the name::"
    )
  end

  it 'has a way to add estimations' do
    get "/"

    form = html.css('form[action="add"][method="post"]').first
    expect(form).not_to eq nil
    expect(form.css('input[type="submit"]').length).to eq 1
    expect(form.css('input[name="name"]').length).to eq 1
  end

  it 'has a way to submit an estimate' do
    given(:in_progress, [
      {name: "name1", estimates: []}
    ])

    get "/"

    form = html.css('form[action="estimate"][method="post"]').first
    expect(form).not_to eq nil
    expect(form.css('input[type="submit"]').length).to eq 1
    expect(form.css('input[name="name"]').length).to eq 1
    expect(form.css('input[name="user"]').length).to eq 1
    expect(form.css('input[name="optimistic"]').length).to eq 1
    expect(form.css('input[name="realistic"]').length).to eq 1
    expect(form.css('input[name="pessimistic"]').length).to eq 1
  end

  it 'has a way to complete an estimation' do
    given(:in_progress, [
      {name: "name1", estimates: []}
    ])

    get "/"

    form = html.css('form[action="complete"][method="post"]').first
    expect(form).not_to eq nil
    expect(form.css('input[type="submit"]').length).to eq 1
    expect(form.css('input[name="name"]').length).to eq 1
  end

  it 'displays the errors' do
    get "/?error=the_error"

    expect(html.css('[data-error]').map(&:text)).to eq ["the_error"]
  end

  it 'does not display error' do
    get "/"

    expect(html.css('[data-error]').length).to eq 0
  end
end
