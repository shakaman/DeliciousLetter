#!/usr/bin/env ruby
# encoding: UTF-8

require 'open-uri'
require 'yajl'

module DeliciousLetter

  ##
  # @class Github
  #
  class Github

    def initialize(opts = {})
    end

    # Check if url is github
    # @param  [String]  url
    # @return true/false
    #
    def isGithub(url)
      return true if url.match('https?://github\.com/(.+)/(.+)')
    end


    # Fetch details from github
    # @param  [String]  url
    # @return github
    #
    def fetchDetails(url)
      if args = url.match('https?://github\.com/(.+)/(.+)')
        begin
          data = open("https://api.github.com/repos/#{args[1]}/#{args[2]}").read
          github = Yajl::Parser.parse(data)

          text = "#{github['name']}:\n#{github['description']}\nlink\n"
          html = "<h3 style='margin: 15px 0 0 0; font: bold 14px/16px Helvetica; color: #000;'><a style='color: #000;' href='#{url}'>#{github['name']}</a> <span style='font: normal 12px Helvetica'>(github)</span></h3><p style='margin: 0; font: normal 12px/14px Helvetica; color: #000;'>#{github['description']}</p>"

          msg = {'text' => text, 'html' => html}
        rescue => err
          msg = nil
        end
        msg
      end
    end
  end
end
