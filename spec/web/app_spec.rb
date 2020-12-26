require 'core/estimations'
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
    [:add, :estimate, :complete, :cancel].each do |action|
      allow(estimations).to receive(action).and_return(Result.success)
    end
  end

  it 'redirects to the correct room url when not ending with "/"' do
    get "/room_name"

    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/room_name/'
    })
  end

  it 'on index (in the default room) shows a form to go to a separate room' do
    get "/"

    form = html.css('form[action="/take_to_room"][method="get"]').first
    expect(form).not_to eq nil
    expect(form.css('input[type="submit"]').length).to eq 1
    room_name = form.css('input[name="room_name"]')
    expect(room_name.length).to eq 1
    expect(room_name.first.attributes).to include "required"
  end

  it 'take to a specific room redirects to the room' do
    get "/take_to_room?room_name= specific /room"

    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/+specific+%2Froom/'
    })
  end

  it 'take to empty room redirects to the default room' do
    get "/take_to_room?room_name="

    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/'
    })
  end

  it 'take to nil room redirects to the default room' do
    get "/take_to_room"

    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/'
    })
  end

  it 'on index shows in progress estimations (in the default room)' do
    allow(estimations).to receive(:in_progress)
      .and_return([
        {name: "name1", estimates: ["user1", "user2"]},
        {name: "name2", estimates: ["user1"]}
      ])

    get "/"

    expect(estimations).to have_received(:in_progress)
      .with(hash_including(
        room: nil
      ))

    in_progress = html.css('[data-in-progress]')

    expect(in_progress[0].css('.story-to-estimate [data-estimation-name]').map(&:text)).to eq ["name1"]
    expect(in_progress[0].css('[data-user-name]').map(&:text)).to eq ["user1", "user2"]

    expect(in_progress[1].css('.story-to-estimate [data-estimation-name]').map(&:text)).to eq ["name2"]
    expect(in_progress[1].css('[data-user-name]').map(&:text)).to eq ["user1"]
  end

  it 'shows in progress estimations in a specific room' do
    allow(estimations).to receive(:in_progress)
      .and_return([
        {name: "name1", estimates: ["user1"]},
      ])

    get "/specific/room/"

    expect(estimations).to have_received(:in_progress)
      .with(hash_including(
        room: "specific/room"
      ))

    in_progress = html.css('[data-in-progress]')

    expect(in_progress[0].css('.story-to-estimate [data-estimation-name]').map(&:text)).to eq ["name1"]
    expect(in_progress[0].css('[data-user-name]').map(&:text)).to eq ["user1"]
  end

  it 'on index shows completed estimations in reverse order (in the default room)' do
    allow(estimations).to receive(:completed)
      .and_return([
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

    expect(estimations).to have_received(:completed)
      .with(hash_including(
        room: nil
      ))

    completed = html.css('[data-completed]')

    expect(completed[0].css('[data-user-estimate]').length).to eq 0

    expect(completed[0].css('[data-estimation-name]').map(&:text)).to eq ["name2"]
    expect(completed[0].css('[data-final-estimate]').map(&:text)).to eq ["-"]

    expect(completed[1].css('[data-estimation-name]').map(&:text)).to eq ["name1"]
    expect(completed[1].css('[data-final-estimate]').map(&:text)).to eq ["6.5"]

    expect(completed[1].css('[data-user-estimate]').length).to eq 2

    expect(completed[1].css('[data-user-estimate]')[0].css('[data-user-name]').map(&:text)).to eq ["user1"]
    expect(completed[1].css('[data-user-estimate]')[0].css('[data-user-estimates]').map(&:text)).to eq ["1/4/8"]

    expect(completed[1].css('[data-user-estimate]')[1].css('[data-user-name]').map(&:text)).to eq ["user2"]
    expect(completed[1].css('[data-user-estimate]')[1].css('[data-user-estimates]').map(&:text)).to eq ["4/4/4"]
  end

  it 'adds an estimation (in the default room)' do
    post "/add", {"name"=>"::the name::", "description"=>""}

    expect(estimations).to have_received(:add).with(
      room: nil,
      name: "::the name::",
      description: ""
    )
    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/'
    })
  end

  it 'adds an estimation in a specific room' do
    post "/specific/room/add", {"name"=>"::the name::", "description"=>""}

    expect(estimations).to have_received(:add).with(
      room: "specific/room",
      name: "::the name::",
      description: ""
    )
    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/specific/room/'
    })
  end

  it 'fails to add an estimation (in the default room)' do
    given(:add, Result.failure(:the_reason))

    post "/add", {"name"=>"::the name::", "description"=>""}

    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/?error=the_reason'
    })
  end

  it 'fails to add an estimation in a specific room' do
    given(:add, Result.failure(:the_reason))

    post "/specific/room/add", {"name"=>"::the name::", "description"=>""}

    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/specific/room/?error=the_reason'
    })
  end

  ["&", "<", ">", '"', "'"].each do |problematic_input|
    it "escapes the user input (#{problematic_input}) in html (to avoid XSS attacks)" do
      user_input = "xss#{problematic_input}xss"

      given(:in_progress, [
        {
          name: user_input,
          estimates: []
        },
        {
          name: user_input,
          estimates: [
            user_input
          ]
        }
      ])
      given(:completed, [
        {
          name: user_input,
          estimate: 1,
          estimates: {
            user_input => {
              optimistic: 1,
              realistic: 1,
              pessimistic: 1
            }
          }
        }
      ])

      get "/", nil, {
        cookie: " user=#{user_input}"
      }

      expect(last_response.body).not_to include user_input
    end
  end

  it 'cancels an estimation (in the default room)' do
    post "/cancel", {
      "name"=>"::the name::"
    }

    expect(estimations).to have_received(:cancel).with(
      room: nil,
      name: "::the name::"
    )
    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/'
    })
  end

  it 'submits an estimate (in the default room)' do
    user = "::the user::"

    post "/estimate", {
      "name"=>"::the name::",
      "user"=>user,
      "optimistic"=>"1",
      "realistic"=>"4",
      "pessimistic"=>"8"
    }

    expect(estimations).to have_received(:estimate).with(
      room: nil,
      name: "::the name::",
      user: user,
      optimistic: 1,
      realistic: 4,
      pessimistic: 8
    )
    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/',
      'Set-Cookie'=>"user=#{user}; Path=/; HttpOnly"
    })
  end

  ["optimistic", "realistic", "pessimistic"].each do |estimate|
    it "requires the #{estimate} estimate" do
      given(:in_progress, [
        {name: "name1", estimates: []}
      ])

      get "/"

      attributes = html.css("input[name=#{estimate}]").first.attributes
      expect(attributes).to include "required"
    end
  end

  it 'completes an estimation (in the default room)' do
    post "/complete", {"name"=>"::the name::"}

    expect(estimations).to have_received(:complete).with(
      room: nil,
      name: "::the name::"
    )
    expect(last_response.status).to eq(302)
    expect(last_response.headers).to eq({
      'Location'=>'/'
    })
  end

  it 'has a way to add estimations' do
    get "/"

    form = html.css('form[action="add"][method="post"]').first
    expect(form).not_to eq nil
    expect(form.css('input[type="submit"]').length).to eq 1
    expect(form.css('input[name="name"]').length).to eq 1
  end

  it 'has a way to cancel estimations' do
    given(:in_progress, [
      {name: "name1", estimates: []}
    ])

    get "/"

    form = html.css('form[action="cancel"][method="post"]').first
    expect(form).not_to eq nil
    expect(form.css('input[type="submit"]').length).to eq 1
    expect(form.css('input[name="name"]').length).to eq 1
  end

  it 'has a way to submit an estimate' do
    user = "::the user::"

    given(:in_progress, [
      {name: "name1", estimates: []}
    ])

    get "/", nil, {
      cookie: " user=#{user}"
    }

    form = html.css('form[action="estimate"][method="post"]').first
    expect(form).not_to eq nil
    expect(form.css('input[type="submit"]').length).to eq 1
    expect(form.css('input[name="name"]').length).to eq 1
    user_input = form.css('input[name="user"]')
    expect(user_input.length).to eq 1
    expect(user_input.first.attributes["value"].value).to eq user
    expect(form.css('input[name="optimistic"]').length).to eq 1
    expect(form.css('input[name="realistic"]').length).to eq 1
    expect(form.css('input[name="pessimistic"]').length).to eq 1
  end

  it 'has a way to complete an estimation' do
    given(:in_progress, [
      {name: "name1", estimates: ["user1"]}
    ])

    get "/"

    form = html.css('.complete-estimation').first
    expect(form).not_to eq nil
    expect(form.css('input[type="submit"]').length).to eq 1
    expect(form.css('input[name="name"]').length).to eq 1
  end

  it 'displays the errors' do
    get "/?error=the_error"

    expect(html.css('[data-error]').map(&:text)).to eq ["Error: the_error"]
  end

  it 'does not display error' do
    get "/"

    expect(html.css('[data-error]').length).to eq 0
  end
end
