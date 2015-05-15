FROM phusion/passenger-ruby22:latest

# Update a bunch of packages
RUN apt-get -y install software-properties-common
RUN apt-add-repository ppa:brightbox/ruby-ng
RUN apt-get -y update
RUN apt-get -y install build-essential
RUN apt-get -y install ruby2.2 ruby2.2-dev
RUN apt-get -y install ruby-switch
RUN ruby-switch --set ruby2.2
RUN gem update --system
RUN gem install bundler

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
ADD dashboardapp/Gemfile /tmp/
ADD dashboardapp/Gemfile.lock /tmp/
RUN bundle install

# Install Thin and add defaults
RUN gem install thin
RUN thin install
RUN /usr/sbin/update-rc.d -f thin defaults
COPY thin.conf /etc/thin/dashboardapp
COPY 60_start_thin.sh /etc/my_init.d/60_start_thin.sh
RUN chmod ugo+x /etc/my_init.d/60_start_thin.sh

RUN gem install pry eventmachine em-http-request em-websocket pry-em


# Add the Rails app
ADD dashboardapp /home/app/dashboardapp
RUN chown -R app:app /home/app/dashboardapp
RUN rm -rf /home/app/dashboardapp/log

# Add the nginx site and config
ADD nginx.conf /etc/nginx/sites-enabled/dashboardapp.conf

# Start Nginx / Passenger
RUN rm -f /etc/service/nginx/down

# Clean up APT and bundler when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Finally, change to the right directory
WORKDIR /home/app/dashboardapp
