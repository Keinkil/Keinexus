from ruby:2.6.1-alpine3.9
copy . .
RUN apk update \
    && apk add build-base \
    && gem install bundler \
    && bundle update \
    && bundle \
    && apk del build-base
CMD ruby bot.rb ${TOKEN} ${CLIENT_ID}