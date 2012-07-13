#!/usr/bin/env ruby
# encoding: UTF-8

require 'typhoeus'
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
    def is?(url)
      return true if url.match('https?://github\.com/(.+)/(.+)')
    end


    # Fetch details from github
    # @param  [String]  url
    # @return github
    #
    def fetch_details(attr)
      url = attr['href'].text
      if args = url.match('https?://github.com/([^\/]+)/([^\/]+)/?$')
        data = Typhoeus::Request.get("https://api.github.com/repos/#{args[1]}/#{args[2]}").body
        github = Yajl::Parser.parse(data)

        tags = DeliciousLetter.build_tags(attr)

        template = Tilt.new('templates/github.haml')
        html = template.render(self, github: github, url: url, tags: tags)
        text = "#{github['name']}:\n#{github['description']}\n#{url}\n\n"

        {'text' => text, 'html' => html}
      end
    end
  end
end
