module Sosho
  require 'rubygems'
  require 'fileutils'
  require 'nokogiri'
  require 'rmagick'

  NIDS_DOMAIN = 'www.nids.mod.go.jp'
  DOWNLOAD_DIR = 'downloads'

  class Logger
    attr_reader :verbose

    def initialize(verbose)
      @verbose = verbose
    end

    def p(str)
      puts str if verbose
    end
  end

  class Volume
    attr_reader :num, :handler, :logger, :volume_str, :viewer_path, :first_page, :last_page, :title
    attr_accessor :files, :download_dir

    WAIT_SEC = 0.05

    def initialize(num:, handler:, logger:, download_dir: DOWNLOAD_DIR)
      @num = num
      @handler = handler
      @logger = logger
      @download_dir = download_dir
      @volume_str = num.to_s.rjust(3, '0')
      @viewer_path = "/military_history_search/SoshoView?kanno=#{volume_str}"
      @files = []
    end

    def get
      puts "downloading ##{num}"

      create_dir
      parse

      logger.p "found page ##{first_page} to ##{last_page}"
      (first_page..last_page).each do |num|
        get_image(num)
        wait
      end
    end

    def get_image(num)
      filename = "#{volume_str}_#{num.to_s.rjust(3, '0')}.jpg"
      image_path = "/military_history_search/GetImage?s=#{volume_str}/#{filename}"
      file_to_save = File.join(download_dir, volume_str, filename)

      logger.p "downloading #{filename}..."
      File.open(file_to_save, 'wb') do |f|
        f.write handler.get(image_path, headers).body
      end

      files << file_to_save
    end

    def create_dir
      FileUtils.mkdir_p File.join(download_dir, volume_str)
    end

    def parse
      opts = doc.css('#pageselector > select').children.search('option')
      @title = doc.css('head > title').inner_text
      @first_page = opts.first.attr('value').to_i
      @last_page = opts.last.attr('value').to_i
    end

    def doc
      @doc ||= Nokogiri::HTML(handler.get(viewer_path).body)
    end

    def headers
      @headers ||= {
        Referer: URI::HTTPS.build(host: NIDS_DOMAIN, path: '/military_history_search/SoshoView',   query: "kanno=#{volume_str}").to_s
      }
    end

    def wait
      sleep WAIT_SEC
    end
  end

  class PDF
    attr_reader :filename, :files, :download_dir, :logger

    def initialize(filename:, files:, logger:, download_dir: DOWNLOAD_DIR)
      @filename = filename
      @files = files
      @download_dir = download_dir
      @logger = logger
    end

    def create
      logger.p 'creating pdf...'

      r = Magick::ImageList.new
      files.each do |file|
        r.push(Magick::Image.read(file)[0])
      end
      r.write "#{download_dir}/#{filename}.pdf"
    end
  end
end
