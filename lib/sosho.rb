module Sosho
  require 'rubygems'
  require 'fileutils'
  require 'nokogiri'
  require 'mini_magick'

  NIDS_DOMAIN = 'www.nids.mod.go.jp'

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
    attr_reader :volume_str, :viewer_path, :first_page, :last_page, :title
    attr_accessor :files

    WAIT_SEC = 0.05

    def initialize(config) #num:, handler:, logger:, download_dir: DOWNLOAD_DIR, overwrite: false)
      %i[num handler logger overwrite download_dir].each do |key|
        self.class.define_method(key) { config[key] }
      end
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
    def initialize(config)
      %i[logger overwrite volume_str files title download_dir].each do |key|
        self.class.define_method(key) { config[key] }
      end
    end

    def create
      return if images.empty?
      return if overwrite && File.exist?(pdf_path)

      logger.p 'creating pdf...'

      MiniMagick.convert do |convert|
        images.each do |file|
          convert << file
        end
        convert << pdf_path
      end
    end

    def images
      files
    end

    def pdf_path
      @pdf_path ||= "#{download_dir}/#{title}.pdf"
    end
  end

  class Split < PDF
    attr_accessor :images

    def initialize(...)
      super
      @images = []
    end

    def create
      return if files.empty?

      logger.p 'split images...'

      create_split_dir
      files.each_with_index do |file, idx|
        right_img = MiniMagick::Image.open(file)
        if right_img.width == 1920
          extname = File.extname(file)
          basename = File.basename(file, extname)

          right_img.crop('960x+960+0')
          right_path = File.join(split_dir, "#{basename}-a#{extname}")
          right_img.write(right_path)
          images << right_path

          logger.p "right: #{right_path}"

          left_img = MiniMagick::Image.open(file)
          left_img.crop('960x+0+0')
          left_path = File.join(split_dir, "#{basename}-b#{extname}")
          left_img.write(left_path)
          images << left_path

          logger.p "left : #{left_path}"
        else
          images << file
        end
      end

      super
    end

    def split_dir
      File.join(download_dir, volume_str, 'split')
    end

    def create_split_dir
      FileUtils.mkdir_p split_dir
    end
  end
end
