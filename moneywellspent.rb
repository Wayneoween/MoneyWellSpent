#!/usr/bin/env ruby
# encoding: utf-8

require 'rubygems'
require 'mechanize'
require 'optparse'
require 'yaml'
require 'highline/import'
require 'logger'

# Logger
$log = Logger.new(STDOUT)
$log.level = Logger::WARN
$log.formatter = proc do |severity, datetime, progname, msg|
  "#{msg}\n"
end


class MoneyWellSpent
  def self.run()
    parseopts

    agent = Mechanize.new
    agent.user_agent_alias = 'Linux Firefox'
    agent.cookie_jar.clear!
    agent.follow_meta_refresh = true
    agent.redirect_ok = true

    page = agent.get(@@cfg[:url])
    login_form = page.form('signIn')
    login_form.email = @@cfg[:login]
    login_form.password = @@cfg[:password]

    puts "Logging in to #{@@cfg[:site]}"
    page = agent.submit(login_form, login_form.buttons.last)

    print "Retrieving order history"
    arr=[]
    arr = page.parser.xpath('//*[@class="price"]').xpath('text()').to_a
    while !(page.link_with(:text => 'Weiter »').nil?)
      page = page.link_with(:text => 'Weiter »').click
      arr.concat(page.parser.xpath('//*[@class="price"]').xpath('text()').to_a)
      print "."
    end

    sum=0
    arr.each do |price|
      if @@cfg[:site] == "amazon.de"
        value = price.content.split(' ')[1].gsub(/\./, '').gsub(/,/, '.').to_f
      elsif @@cfg[:site] == "amazon.com"
        value = price.content.gsub(/\$/, '').to_f
      end
      sum += value
    end
    puts
    puts sum.round(2)
  end

  def self.parseopts()
    # Option/ configuration parsing

    # Parse the command line options
    attrs = {}
    options = OptionParser.new do |opts|
      opts.banner = "Usage: #{$0} [OPTION]..."
      opts.separator "A script to summarize your money spent on Amazon"
      opts.separator "Options:"
      opts.on("-l [LOGIN]", "--login [LOGIN]",
        "Specify the username (e-mail) of your Amazon account") do |login|
        attrs[:login] = login
      end
      opts.on("-p [PASSWORD]", "--password [PASSWORD]",
        "Specify the password of your Amazon account") do |password|
        attrs[:password] = password
      end
      opts.on("-y [YEAR]", "--year [YEAR]",
        "Specify the year to be summed up") do |year|
        attrs[:year] = year
      end
      opts.on("-s [SITE]", "--site [SITE]",
        "Specify the site to be queried. " +
        "Currently only Amazon.de is supproted") do |site|
        attrs[:site] = site
      end
      opts.on("-d", "--debug", "Enable debug output") do
        $log.level = Logger::DEBUG
      end
      opts.on("-v", "--verbose", "Enable verbose output") do
        $log.level = Logger::INFO
      end
      opts.on("-h", "--help", "Show this help") do
        puts options
        exit 0
      end
    end
    options.parse!

    # Read the default configuration file at ~/.moneywellspentrc
    configf = {}
    f = File.expand_path("~/.moneywellspentrc")
    if File.exist?(f)
      begin
        $log.debug "Loading configuration file #{f}"
        configf = YAML.load(File.read(f))
      rescue => e
        $log.warn "Error loading configuration file #{f}."
        $log.info e.message
        exit 1
      end
    else
      $log.info "No configuration file #{f} found."
    end
    # Make sure configf["default"] exists
    configf["default"] ||= {}
    @@cfg = configf["default"].merge(attrs)

    # Ask for the settings if not given via command line or configuration file
    unless @@cfg[:site]
      $log.debug "No site given using amazon.de as default"
      @@cfg[:site] = "amazon.de"
    end
    unless @@cfg[:login]
      $log.debug "No logininfo given, asking"
      @@cfg[:login] = ask("Enter your #{@@cfg[:site]} username:  ") { |q|
        q.echo = true
      }
    end
    unless @@cfg[:password]
      $log.debug "No password given, asking"
      @@cfg[:password] = ask("Enter your #{@@cfg[:site]} password:  ") { |q|
        q.echo = "*"
      }
    end
    unless @@cfg[:year]
      $log.debug "No year given, asking"
      @@cfg[:year] = ask("Enter the year to be summed up: ") { |q|
        q.echo = true
      }
    end

    # Determine the URL
    if @@cfg[:site] == "amazon.de"
      @@cfg[:url] = "https://www.amazon.de/gp/css/order-history?opt=ab&" +
        "digitalOrders=1&unifiedOrders=0&orderFilter=year-#{@@cfg[:year]}"
    elsif @@cfg[:site] == "amazon.com"
      @@cfg[:url] = "https://www.amazon.com/gp/css/order-history?opt=ab&" +
        "digitalOrders=1&unifiedOrders=0&orderFilter=year-#{@@cfg[:year]}"
    else
        $log.warn "Invalid site specified"
        exit 1
    end
  end
end

MoneyWellSpent.run
