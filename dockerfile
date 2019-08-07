FROM ruby:2.6.1-alpine3.9
COPY Gemfile .
COPY Gemfile.lock .
RUN apk update \
    && apk add build-base \
    && gem install bundler \
   # && bundle update \
    && bundle \
    && apk del build-base
COPY . .
CMD ruby bot.rb ${TOKEN} ${CLIENT_ID}