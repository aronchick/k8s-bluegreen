# From: https://rossfairbanks.com/2015/03/06/rails-app-on-docker-using-passenger-image.html

FROM phusion/passenger-ruby21:0.9.15
MAINTAINER Ross Fairbanks "ross.fairbanks@gmail.com"

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

# Expose Nginx HTTP service
EXPOSE 80

# Remove the default site
RUN rm /etc/nginx/sites-enabled/default

# Install bundle of gems
WORKDIR /tmp
ADD dashapp/Gemfile /tmp/
ADD dashapp/Gemfile.lock /tmp/
RUN bundle install

# Install Thin and add defaults
RUN gem install thin
RUN thin install
RUN /usr/sbin/update-rc.d -f thin defaults
COPY thin.conf /etc/thin/dashapp
COPY 60_start_thin.sh /etc/my_init.d/60_start_thin.sh
RUN chmod ugo+x /etc/my_init.d/60_start_thin.sh

RUN gem install pry eventmachine em-http-request em-websocket pry-em


# Add the Rails app
ADD dashapp /home/app/dashapp
RUN chown -R app:app /home/app/dashapp

# Add the nginx site and config
ADD nginx.conf /etc/nginx/sites-enabled/dashapp.conf

# Start Nginx / Passenger
RUN rm -f /etc/service/nginx/down

# Clean up APT and bundler when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Finally, change to the right directory
WORKDIR /home/app/dashapp
