require 'rubygems'

require 'fileutils'
require 'net/http'

require 'thor'
require 'nokogiri'
require 'rmagick'

class Soshoget < Thor
  default_command :get
  desc 'get', 'get specific volume'
  method_option :pdf, type: :boolean, aliases: '-p', default: false, desc: 'create pdf'
  method_option :all, type: :boolean, aliases: '-a', default: false, desc: 'get all soshos'
  method_option :verbose, type: :boolean, aliases: '-v', default: false, desc: 'verbose output'

  OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_LEGACY_SERVER_CONNECT

  def self.exit_on_failure?
    true
  end

  def get(volume)
    volumes = options['all'] ? all_volumes : [volume]
    connection.use_ssl = true
    connection.start do |http|
      volumes.each do |vol|
        logger "downloading ##{vol}"
        get_volume(volume: vol, handler: http)
      end
    end
  end

  private

  def connection
    @connection ||= Net::HTTP.new(nids_domain, 443)
  end

  def get_volume(volume:, handler:)
    volume_str = volume.to_s.rjust(3, '0')

    FileUtils.mkdir_p volume_str

    path = "/military_history_search/SoshoView?kanno=#{volume_str}"
    doc = Nokogiri::HTML(handler.get(path).body)
    opts = doc.css('#pageselector > select').children.search('option')
    title = doc.css('head > title').inner_text
    first_page = opts.first.attr('value').to_i
    last_page = opts.last.attr('value').to_i
    logger "found page ##{first_page} to ##{last_page}"
    files = (first_page..last_page).map do |num|
      get_image(num:, volume_str:, handler:)
    end

    return unless options['pdf']

    logger 'creating pdf...'
    create_pdf(files:, volume_str:, title:)
  end

  def get_image(num:, volume_str:, handler:)
    fn = "#{volume_str}_#{num.to_s.rjust(3, '0')}.jpg"
    image_path = "/military_history_search/GetImage?s=#{volume_str}/#{fn}"
    headers = {
      Referer: URI::HTTPS.build(host: nids_domain, path: '/military_history_search/SoshoView',   query: "kanno=#{volume_str}").to_s
    }

    logger "downloading #{fn}..."
    file_to_save = File.join(volume_str, fn)
    File.open(file_to_save, 'wb') do |f|
      f.write handler.get(image_path, headers).body
    end
    sleep 0.05
    file_to_save
  end

  def create_pdf(files:, volume_str:, title:)
    r = Magick::ImageList.new
    files.each do |file|
      r.push(Magick::Image.read(file)[0])
    end
    r.write "#{volume_str}/#{title}.pdf"
  end

  def all_volumes
    (1..max_volume).to_a
  end

  def max_volume
    104
  end

  def logger(str)
    puts str if options['verbose']
  end

  def nids_domain
    'www.nids.mod.go.jp'
  end
end

Soshoget.start
