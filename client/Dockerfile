# From: https://rossfairbanks.com/2015/03/06/rails-app-on-docker-using-passenger-image.html

FROM phusion/passenger-ruby21:0.9.15

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
ADD clientapp/Gemfile /tmp/
ADD clientapp/Gemfile.lock /tmp/
RUN bundle install

# Add the Rails app
ADD clientapp /home/app/clientapp
RUN chown -R app:app /home/app/clientapp

# Add the nginx site and config
ADD nginx.conf /etc/nginx/sites-enabled/clientapp.conf

# Install Thin and add defaults
RUN gem install thin
RUN thin install
RUN /usr/sbin/update-rc.d -f thin defaults
COPY thin.conf /etc/thin/clientapp
COPY 60_start_thin.sh /etc/my_init.d/60_start_thin.sh
RUN chmod ugo+x /etc/my_init.d/60_start_thin.sh

# Start Nginx / Passenger
RUN rm -f /etc/service/nginx/down

# Clean up APT and bundler when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Finally, change to the right directory
WORKDIR /home/app/clientapp
