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
        rescue => err
          github = nil
        end
        github
      end
    end
  end
end
