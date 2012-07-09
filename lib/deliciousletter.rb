# encoding: utf-8

require 'pathname'
require 'yaml'
require 'rest_client'
require 'nokogiri'
require 'chronic'
require 'net/smtp'
require 'open-uri'

require 'tilt'
require 'haml'
require 'pony'
require 'premailer'

require 'plugins/github'
require 'plugins/twitter'

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

      fetchLastBookmarks()
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
    #def fetchLastBookmarks(fromdt, todt, opts={})
    def fetchLastBookmarks
      opts = {}
      fromdt =  DateTime.parse(Chronic.parse('monday', :context => :past).to_s)
      fromdt = fromdt.strftime("%Y-%m-%dT%H:%M:%SZ").to_s

      todt   =  DateTime.parse(Chronic.parse('monday', :context => :future).to_s)
      todt = todt.strftime("%Y-%m-%dT%H:%M:%SZ").to_s
      begin
        response = api["/v1/posts/all?fromdt=#{fromdt}&todt=#{todt}"].post opts
        results = Nokogiri::XML::Document.parse(response.body)
        orderLinks(results)
      rescue => e
        $stderr.puts e.inspect
        false
      end
    end



    def buildTags(attr)
      tags = Array.new
      list = attr['tag'].text
      tags = list.split(' ')
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
      RestClient::Resource.new(@delicious[:api], @delicious[:username], @delicious[:password])
    end


    def orderLinks(links)
      posts = links.root.xpath("//post")
      self.builContent(posts)
    end

    ##
    # Build email content
    #
    def builContent(posts)
      msgText = "\n"
      msgHtml = ''

      posts.each{ |post|
        github = DeliciousLetter::Github.new
        twitter = DeliciousLetter::Twitter.new

        if github.isGithub(post.attributes['href'].text)
          github = github.fetchDetails(post.attributes)
          msgText += github['text']
          msgHtml += github['html']

        elsif twitter.isTwitter(post.attributes['href'].text)
          tweet = twitter.fetchDetails(post.attributes)
          msgText += tweet['text']
          msgHtml += tweet['html']

        else
          title = checkTitle(post.attributes)

          tags = buildTags(post.attributes)

          template = Tilt.new(@theme[:link_row])
          msgHtml += template.render(self, title: title, url: post.attributes['href'].text, tags: tags)
          msgText += "#{title}\n#{post.attributes['href'].text}\n\n"
        end
      }

      buildEmail(msgText, msgHtml)
    end

    ##
    # Build email with template
    #
    def buildEmail(text, html)
      template = Tilt.new(@theme[:layout])
      title = 'Le menu de la semaine proposé par MrPorte'

      # Open css file to inject in html
      css = File.open(@theme[:css])
      content = template.render(self, title: title, content: html, css: css.read)
      css.close

      # Create a temporary file with html
      tmp = File.open("tmp/input.html", "w")
      tmp.puts content
      tmp.close

      # Use premailer to add css inline
      premailer = Premailer.new('tmp/input.html', :warn_level => Premailer::Warnings::SAFE)
      html = premailer.to_inline_css

      # Remove temporary file
      File.delete('tmp/input.html')

      sendEmail(title, html, text)
    end


    ##
    # Send email
    #
    def sendEmail(title, html, text)
      Pony.mail({
        :from               => @email[:from_email],
        :to                 => @email[:to_email],
        :subject            => title,
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
    # Check if title is the best ;)
    #
    def checkTitle(attr)
      if attr['href'].text == attr['description'].text
        begin
          doc = Nokogiri::HTML(open(attr['href'].text))
          title = doc.xpath('//title').text
        rescue => err
          title = attr['href'].text
        end
      else
        title = attr['description'].text
      end
      return title
    end

  end
end
