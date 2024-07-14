module Sosho
  require 'rubygems'
  require 'fileutils'
  require 'nokogiri'
  require 'mini_magick'

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
    attr_reader :num, :handler, :logger, :volume_str, :viewer_path, :first_page, :last_page, :title, :overwrite
    attr_accessor :files, :download_dir

    WAIT_SEC = 0.05

    def initialize(num:, handler:, logger:, download_dir: DOWNLOAD_DIR, overwrite: false)
      @num = num
      @handler = handler
      @logger = logger
      @download_dir = download_dir
      @overwrite = overwrite
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
      files << file_to_save
      return if !overwrite && File.exist?(file_to_save)

      logger.p "downloading #{filename}..."
      File.open(file_to_save, 'wb') do |f|
        f.write handler.get(image_path, headers).body
      end

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
    attr_reader :filename, :files, :download_dir, :logger, :overwrite

    def initialize(filename:, files:, logger:, download_dir: DOWNLOAD_DIR, overwrite: false)
      @filename = filename
      @files = files
      @logger = logger
      @download_dir = download_dir
      @overwrite = overwrite
    end

    def create
      return if files.empty?
      return if !overwrite && File.exist?(pdf_path)

      logger.p 'creating pdf...'

      MiniMagick.convert do |convert|
        files.each do |file|
          convert << file
        end
        convert << pdf_path
      end
    end

    def pdf_path
      @pdf_path ||= "#{download_dir}/#{filename}.pdf"
    end
  end
end
