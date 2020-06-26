FROM ruby:2.7.1

WORKDIR /opt/remote-estimations

COPY ./Gemfile /opt/remote-estimations
COPY ./Gemfile.lock /opt/remote-estimations
RUN bundle install

COPY . /opt/remote-estimations

CMD rackup --host 0.0.0.0
