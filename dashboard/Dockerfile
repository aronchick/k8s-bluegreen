FROM ubuntu

RUN apt-get -y install software-properties-common && \
    apt-add-repository ppa:brightbox/ruby-ng
RUN apt-get -y update
RUN apt-get -y install build-essential \
                       ruby2.2 ruby2.2-dev \
                       ruby-switch

# Disable the below line if you don't want debugging tools
RUN apt-get -y install dnsutils curl

RUN ruby-switch --set ruby2.2
RUN gem update --system
RUN gem install bundler

# Install Thin and add defaults
RUN gem install thin
RUN thin install
RUN /usr/sbin/update-rc.d -f thin defaults
COPY thin.conf /etc/thin/app

# Expose HTTP service
EXPOSE 80

# Add app user
RUN adduser --disabled-password --home /app app

# Install bundle of gems
WORKDIR /tmp
ADD app/Gemfile /tmp/
ADD app/Gemfile.lock /tmp/
ENV RAILS_ENV production
RUN bundle install

WORKDIR /app

# Add the Rails app
ADD app /app
RUN chown -R app:app /app
RUN rm -rf /app/log

# Clean up APT and bundler when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Start Thin
CMD ["thin", "-R", "config.ru", "-C", "/etc/thin/app", "start"]
