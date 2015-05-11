Deploying to Heroku
===================

Install some gems:

    gem install bundler
    gem install heroku
    gem install foreman

Run the app locally (optional):

    foreman start

Create a Heroku app on the Cedar stack:

    heroku create --stack cedar

Create a git project and push to Heroku:

    git init
    git add .
    git commit -m "First import"

    git push heroku master

Visit your app's URL in your browser and load a URL:

    http://quiet-sunrise-271.herokuapp.com/?url=http://peepcode.com



