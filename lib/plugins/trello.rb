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
      data = @api["/boards/#{@trello[:board]}/lists?cards=open&card_fields=name,due,url&key=#{@trello[:key]}&token=#{@trello[:token]}"].get
      trello = Yajl::Parser.parse(data.body)

      fromdt = DateTime.parse(Chronic.parse(@trello[:fromdt], :context => :past).to_s).to_time.to_i
      todt   = DateTime.parse(Chronic.parse(@trello[:todt], :context => :future).to_s).to_time.to_i

      tpl         = Tilt.new('templates/trello.haml')
      tpl_card    = Tilt.new('templates/trello_card.haml')
      tpl_column  = Tilt.new('templates/trello_column.haml')

      column_html, column_text = ['', '']

      trello.each do |board|
        cards_html, cards_text = ['', '']

        board['cards'].each do |card|
          if card.include?('due')
            d = DateTime.parse(card['due']).to_time.to_i
            if fromdt <= d && d <= todt
              cards_html += tpl_card.render(self, card: card)
              cards_text += "#{card['name']}:\n#{card['url']}\n\n"
            end
          end
        end

        column_html += tpl_column.render(self, name: board['name'], cards: cards_html)
        column_text += "# #{board['name']} #\n#{cards_text}\n\n\n"
      end

      html = tpl.render(self, content: column_html)
      {'text' => column_text, 'html' => html}
    end
  end
end
