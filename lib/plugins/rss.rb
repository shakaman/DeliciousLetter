#!/usr/bin/env ruby
# encoding: UTF-8

require 'feedzirra'
require 'chronic'

module DeliciousLetter

  ##
  # @class Rss
  #
  class Rss

    def initialize(opts = {})
      @rss = DeliciousLetter.config[:rss]
    end

    def get_last_posts
      feed = Feedzirra::Feed.fetch_and_parse(@rss[:url])

      fromdt = DateTime.parse(Chronic.parse(@rss[:fromdt], :context => :past).to_s).to_time.to_i

      tpl         = Tilt.new('templates/rss.haml')
      tpl_post    = Tilt.new('templates/rss_post.haml')
      posts_html, posts_text = ['', '']

      feed.entries.each do |post|
        if fromdt < post.updated.to_time.to_i
          posts_html += tpl_post.render(self, post: post)
          posts_text += "#{post['title']} (by #{post['author']}):\n#{post['links']}\n\n"
        end
      end

      html = tpl.render(self, title: @rss[:title], content: posts_html)
      {'text' => posts_text, 'html' => html}
    end
  end
end
