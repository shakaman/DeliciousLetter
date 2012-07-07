# encoding: utf-8

require 'pathname'
require 'yaml'
require 'rest_client'
require 'nokogiri'
require 'chronic'
require 'net/smtp'

require 'plugins/github'

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

      self.fetchLastBookmarks()
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
        DeliciousLetter.orderLinks(results)
      rescue => e
        $stderr.puts e.inspect
        false
      end
    end

    protected

    # Load configuration file
    # @param  [ String ] file optional config file path
    # @return [ Hash ]   config options
    def load_config(file = nil)
      self.config = YAML.load_file(file || DeliciousLetter.config_file)
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
      RestClient::Resource.new('https://api.del.icio.us', @delicious[:username], @delicious[:password])
    end


    def orderLinks(links)
      posts = links.root.xpath("//post")
      self.sendEmail(posts)
    end

    def sendEmail(posts)
      email_text = ''
      email_html = ''

      posts.each{ |post|
        github = DeliciousLetter::Github.new

        if github.isGithub(post.attributes['href'].text)
          github = github.fetchDetails(post.attributes['href'].text)

          email_text += "#{github['name']}:\n#{github['description']}\nlink\n"
          email_html += "<h3 style='margin: 15px 0 0 0; font: bold 14px/16px Helvetica; color: #000;'><a style='color: #000;' href='#{post.attributes['href'].text}'>#{github['name']}</a></h3><p style='margin: 0; font: normal 12px/14px Helvetica; color: #000;'>#{github['description']}</p>"
        else
          email_text += "#{post.attributes['description'].text} : #{post.attributes['href'].text} \n"
          email_html += "<h3 style='margin: 15px 0 0 0; font: bold 14px/16px Helvetica; color: #000;'><a style='color: #000;' href='#{post.attributes['href'].text}'>#{post.attributes['description'].text}</a></h3>"
        end
      }

      message = <<MESSAGE_END
From: #{@email[:from_name]} <#{@email[:from_email]}>
To: Nerds <#{@email[:to_email]}>
MIME-Version: 1.0
Content-type: text/html
Subject: Mr Porte vous propose cette semaine

<h1 style="font: bold 20px/30px 'Helvetica'; color: #000;">Mr Porte vous propose cette semaine</h1>#{email_html}
MESSAGE_END

      smtp = Net::SMTP.new 'smtp.gmail.com', 587
      smtp.enable_starttls
      smtp.start(@smtp[:domain], @smtp[:login], @smtp[:password], :login) do
        smtp.send_message(message, @email[:from_email], @email[:to_email])
      end
    end
  end
end
