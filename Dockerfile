FROM ruby

WORKDIR /app

COPY . .

EXPOSE 2000

CMD ["ruby", "server.rb"]