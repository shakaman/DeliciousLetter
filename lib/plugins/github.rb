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
      @delicious = DeliciousLetter.config[:delicious]
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
    def fetchDetails(attr)
      url = attr['href'].text
      if args = url.match('https?://github\.com/(.+)/(.+)')
        begin
          data = open("https://api.github.com/repos/#{args[1]}/#{args[2]}").read
          github = Yajl::Parser.parse(data)

          tags = DeliciousLetter.buildTags(attr)

          template = Tilt.new('templates/github.haml')
          html = template.render(self, github: github, url: url, tags: tags)
          text = "#{github['name']}:\n#{github['description']}\nlink\n"

          msg = {'text' => text, 'html' => html}
        rescue => err
          msg = nil
        end
        msg
      end
    end
  end
end
