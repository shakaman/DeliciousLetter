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
    end

    # Check if url is twitter
    # @param  [String]  url
    # @return true/false
    #
    def isTwitter(url)
      return true if url.match('https?://twitter\.com.*status/(\d+)')
    end


    # Fetch details from github
    # @param  [String]  url
    # @return github
    #
    def fetchDetails(url)
      if args = url.match('https?://twitter\.com.*status/(\d+)')
        begin
          data = open("http://api.twitter.com/1/statuses/show/#{args[1]}.json").read
          tweet = Yajl::Parser.parse(data)

          text = "#{tweet['user']['name']}:\n#{tweet['text']}\nlink\n"
          html = "<h3 style='margin: 15px 0 0 0; font: bold 14px/16px Helvetica; color: #000;'><a style='color: #000;' href='#{url}'>#{tweet['user']['name']}</a> <span style='font: normal 12px Helvetica'>(twitter)</span></h3><p style='margin: 0; font: normal 12px/14px Helvetica; color: #000;'>#{tweet['text']}</p>"

          msg = {'text' => text, 'html' => html}
        rescue => err
          msg = nil
        end
        msg
      end
    end
  end
end
