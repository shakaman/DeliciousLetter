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

      fromdt = Chronic.parse(@rss[:fromdt], :context => :past).to_i

      tpl      = Tilt.new('templates/rss.haml')
      tpl_post = Tilt.new('templates/rss_post.haml')

      posts = feed.entries.select {|post| fromdt <= post.updated.to_i }
      posts_html = posts.map {|post| tpl_post.render(self, post: post) }.join
      posts_text = posts.map {|post| "#{post['title']} (by #{post['author']}):\n#{post['links']}\n" }.join("\n")

      html = tpl.render(self, title: @rss[:title], content: posts_html)
      {'text' => posts_text, 'html' => html}
    end
  end
end
