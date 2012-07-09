#!/usr/bin/env ruby
# encoding: UTF-8

require 'open-uri'
require 'yajl'

module DeliciousLetter

  ##
  # @class Twitter
  #
  class Twitter

    def initialize(opts = {})
      @delicious = DeliciousLetter.config[:delicious]
    end

    # Check if url is twitter
    # @param  [String]  url
    # @return true/false
    #
    def isTwitter(url)
      return true if url.match('https?://twitter\.com.*status/(\d+)')
    end


    # Fetch details from twitter
    # @param  [String]  url
    # @return github
    #
    def fetchDetails(attr)
      url = attr['href'].text
      if args = url.match('https?://twitter\.com.*status/(\d+)')
        begin
          data = open("http://api.twitter.com/1/statuses/show/#{args[1]}.json").read
          tweet = Yajl::Parser.parse(data)

          tags = DeliciousLetter.buildTags(attr)

          template = Tilt.new('templates/twitter.haml')
          html = template.render(self, tweet: tweet, url: url, tags: tags)
          text = "#{tweet['user']['name']}:\n#{tweet['text']}\n#{url}\n\n"

          msg = {'text' => text, 'html' => html}
        rescue => err
          msg = nil
        end
        msg
      end
    end
  end
end
