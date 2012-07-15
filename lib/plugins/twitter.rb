#!/usr/bin/env ruby
# encoding: UTF-8

require 'rest_client'
require 'yajl'

module DeliciousLetter

  ##
  # @class Twitter
  #
  class Twitter

    def initialize(opts = {})
      @delicious = DeliciousLetter.config[:delicious]
      @api = RestClient::Resource.new("http://api.twitter.com/1")
    end

    # Check if url is twitter
    # @param  [String]  url
    # @return true/false
    #
    def is?(url)
      return true if url.match('https?://twitter\.com.*status/(\d+)')
    end


    # Fetch details from twitter
    # @param  [String]  url
    # @return github
    #
    def fetch_details(attr)
      url = attr['href'].text
      if args = url.match('https?://twitter\.com.*status/(\d+)')
        data = @api["/statuses/show/#{args[1]}.json"].get
        tweet = Yajl::Parser.parse(data.body)

        tags = DeliciousLetter.build_tags(attr)

        template = Tilt.new('templates/twitter.haml')
        html = template.render(self, tweet: tweet, url: url, tags: tags)
        text = "#{tweet['user']['name']}:\n#{tweet['text']}\n#{url}\n\n"

        {'text' => text, 'html' => html}
      end
    end
  end
end
