# encoding: utf-8

require 'pathname'
require 'yaml'
require 'rest_client'
require 'nokogiri'
require 'chronic'

require 'tilt'
require 'haml'
require 'pony'
require 'premailer'

require 'plugins/github'
require 'plugins/twitter'
require 'plugins/trello'

module DeliciousLetter
  @@config = nil
  @@env    = 'development'

  class << self
    attr_accessor :config
    attr_accessor :env


    def run(*args)
      config ||= load_config

      @delicious  = config[:delicious]
      @email      = config[:email]
      @smtp       = config[:smtp]
      @theme      = config[:theme]
      @trello     = config[:trello]
      @static     = config[:static]

      fetch_last_bookmarks()
    end


    # Where I am?
    # @return [ Pathname ] Application root
    def root
      return @root_path if @root_path
      @root_path = Pathname File.join(File.dirname(__FILE__), '..')
    end


    # Fetch bookmarks of this week
    # @param  [String]  fromdt={CCYY-MM-DDThh:mm:ssZ} (optional) Filter for posts on this date or later
    # @param  [String]  todt={CCYY-MM-DDThh:mm:ssZ} (optional) Filter for posts on this date or earlier
    # @return [Boolean]
    #def fetch_last_bookmarks(fromdt, todt, opts={})
    def fetch_last_bookmarks
      opts = {}
      fromdt = DateTime.parse(Chronic.parse(@delicious[:fromdt], :context => :past).to_s)
      fromdt = fromdt.strftime("%Y-%m-%dT%H:%M:%SZ").to_s

      todt   = DateTime.parse(Chronic.parse(@delicious[:todt], :context => :future).to_s)
      todt   = todt.strftime("%Y-%m-%dT%H:%M:%SZ").to_s
      begin
        response = api["/v1/posts/all?fromdt=#{fromdt}&todt=#{todt}"].post opts
        results = Nokogiri::XML::Document.parse(response.body)
        order_links(results)
      rescue => e
        $stderr.puts e.inspect
        false
      end
    end


    def build_tags(attrs)
      attrs['tag'].text.split(' ')
    end


    protected

    # Load configuration file
    # @param  [ String ] file optional config file path
    # @return [ Hash ]   config options
    def load_config(file = nil)
      self.config = YAML.load_file(file || config_file)
      self.config[:app_dir] ||= root
      self.config
    end


    # Where's my config file?
    # @return [ Pathname ]
    def config_file
      root.join 'config', @@env + '.yml'
    end


    # Delicious v1 API resource. Restful... kinda.
    # @return [RestClient::Resource]
    def api
      RestClient::Resource.new(@delicious[:api],
                               @delicious[:username],
                               @delicious[:password])
    end


    def order_links(links)
      posts = links.root.xpath("//post")
      self.build_content(posts)
    end

    ##
    # Build email content
    #
    def build_content(posts)
      msg_text = "\n"
      msg_html = ''

      posts.each{ |post|
        # got to next post if private == false
        next if post.attributes['private'].text == "yes" && !@delicious[:private]

        github = DeliciousLetter::Github.new
        twitter = DeliciousLetter::Twitter.new

        plugin = [github, twitter].find {|plugin| plugin.is?(post.attributes['href'].text) }

        if plugin.nil?
          title = check_title(post.attributes)

          tags = build_tags(post.attributes)

          template = Tilt.new(@theme[:link_row])
          msg_html += template.render(self, title: title,
                                      url: post.attributes['href'].text,
                                      tags: tags)
          msg_text += "#{title}\n#{post.attributes['href'].text}\n[ #{tags.join ' '} ]\n\n"
        else
          details = plugin.fetch_details(post.attributes)
          msg_text += details['text']
          msg_html += details['html']
        end
      }

      template = Tilt.new(@theme[:delicious])
      msg_html = template.render(self, title: @delicious[:title], content: msg_html)

      if @trello[:activate]
        trello = DeliciousLetter::Trello.new
        content_trello = trello.get_last_news
        msg_text += content_trello['text']
        msg_html += content_trello['html']
      end

			if @static[:activate]	
				static_page = build_html(msg_html)
			else
				static_page = nil
			end
      build_email(msg_text, msg_html, static_page)
    end

    ##
    # Build email with template
    #
    def build_email(text, html, static_page)
      template = Tilt.new(@theme[:email_layout])
      d = DateTime.now()
      month = d.strftime('%B').to_s
      day = d.strftime('%d').to_s

      # Open css file to inject in html
      css = File.read(@theme[:css])
      content = template.render(self, email_title: @email[:email_title],
                                      title: @email[:title],
                                      month: month,
                                      day: day,
                                      content: html,
                                      css: css,
																			static_page: static_page,
																			domain: @static[:domain])

      # Create a temporary file with html
      File.open("tmp/input.html", "w") {|f| f.write content }

      # Use premailer to add css inline
      premailer = Premailer.new('tmp/input.html', :warn_level => Premailer::Warnings::SAFE)
      html = premailer.to_inline_css

      # Remove temporary file
      File.delete('tmp/input.html')

      send_email(html, text)
    end

    ##
    # Send email
    #
    def send_email(html, text)
      Pony.mail({
        :from               => @email[:from_email],
        :to                 => @email[:to_email],
        :subject            => @email[:email_title],
        :body               => text,
        :html_body          => html,
        :charset            => 'utf-8',
        :text_part_charset  => 'utf-8',
        :via => :smtp,
        :via_options => {
          :address              => @smtp[:server],
          :port                 => @smtp[:port],
          :enable_starttls_auto => true,
          :user_name            => @smtp[:login],
          :password             => @smtp[:password],
          :authentication       => :login, # :plain, :login, :cram_md5, no auth by default
          :domain               => @smtp[:domain] # the HELO domain provided by the client to the server
        }
      })
    end

		##
		# Build static html page
		#
		def build_html(html)
      template = Tilt.new(@theme[:html_layout])
      d = DateTime.now()
      month = d.strftime('%B').to_s
      day = d.strftime('%d').to_s

      content = template.render(self, title: @email[:title],
                                      month: month,
                                      day: day,
                                      content: html,
                                      css: @theme[:css],
																			domain: @static[:domain])

			file_name = "#{d.strftime('%d-%m-%Y')}.html"
      # Create static html page
      File.open("tmp/#{file_name}", "w") {|f| f.write content }

			return file_name
		end

    ##
    # Check if title is the best ;)
    #
    def check_title(attr)
      if attr['href'].text == attr['description'].text
        begin
          doc = Nokogiri::HTML(open(attr['href'].text))
          doc.xpath('//title').text
        rescue => err
          attr['href'].text
        end
      else
        attr['description'].text
      end
    end
  end
end
