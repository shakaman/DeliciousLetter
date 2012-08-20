#!/usr/bin/env ruby
# encoding: UTF-8

require 'rest_client'
require 'yajl'
require 'chronic'

module DeliciousLetter

  ##
  # @class Trello
  #
  class Trello

    def initialize(opts = {})
      @trello = DeliciousLetter.config[:trello]
      @api = RestClient::Resource.new(@trello[:api])
    end

    def get_last_news
      data = @api["/boards/#{@trello[:board]}/lists?cards=open&card_fields=name,url&key=#{@trello[:key]}&token=#{@trello[:token]}"].get
      trello = Yajl::Parser.parse(data.body)

      fromdt = DateTime.parse(Chronic.parse(@trello[:fromdt], :context => :past).to_s)
      fromdt = fromdt.strftime("%Y-%m-%d").to_s

      tpl         = Tilt.new('templates/trello.haml')
      tpl_card    = Tilt.new('templates/trello_card.haml')
      tpl_column  = Tilt.new('templates/trello_column.haml')

      column_html, column_text = ['', '']

      trello.each do |board|
        cards_html, cards_text = ['', '']

        board['cards'].each do |card|
          data = @api["/cards/#{card['id']}/actions?fields=data&since=#{fromdt}&key=#{@trello[:key]}&token=#{@trello[:token]}"].get
          activities = Yajl::Parser.parse(data.body)

          if activities.count > 0
            cards_html += tpl_card.render(self, card: card, activity: activities.first)
            cards_text += "#{card['name']}:\n#{card['url']}\n\n"
          end
        end

        column_html += tpl_column.render(self, name: board['name'], cards: cards_html)
        column_text += "# #{board['name']} #\n#{cards_text}\n\n\n"
      end

      html = tpl.render(self, title: @trello[:title], content: column_html)
      {'text' => column_text, 'html' => html}
    end
  end
end
