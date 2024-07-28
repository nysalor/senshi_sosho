require 'thor'
require 'net/http'

require './lib/sosho'

class Soshoget < Thor
  DOWNLOAD_DIR = 'downloads'

  default_command :get
  desc 'get', 'get specific volume'
  method_option :pdf, type: :boolean, aliases: '-p', default: false, desc: 'create pdf'
  method_option :split_pdf, type: :boolean, aliases: '-s', default: false, desc: 'create split pdf'
  method_option :all, type: :boolean, aliases: '-a', default: false, desc: 'get all soshos'
  method_option :verbose, type: :boolean, aliases: '-v', default: false, desc: 'verbose output'
  method_option :overwrite, type: :boolean, aliases: '-o', default: false, desc: 'overwrite existing image'
  method_option :dir, type: :string, aliases: '-d', default: DOWNLOAD_DIR, desc: 'directory to save files'
  OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_LEGACY_SERVER_CONNECT

  def self.exit_on_failure?
    true
  end

  def get(volume)
    volumes = options['all'] ? all_volumes : [volume]
    logger = Sosho::Logger.new(options[:verbose])

    config = {
      logger:,
      overwrite: options['overwrite'],
      download_dir: options['dir']
    }

    connection.use_ssl = true
    connection.start do |handler|
      volumes.each do |vol|
        volume = Sosho::Volume.new(config.merge({ num: vol, handler: }))
        volume.get
        wait
        next unless options['pdf'] || options['split_pdf']

        pdf_config = config.merge({
          volume_str: volume.volume_str,
          files: volume.files,
          title: volume.title
        })
        if options['split_pdf']
          Sosho::Split.new(pdf_config).create
        else
          Sosho::PDF.new(pdf_config).create
        end
      end
    end
  end

  private

  def connection
    @connection ||= Net::HTTP.new(Sosho::NIDS_DOMAIN, 443)
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

  def wait
    sleep 30
  end
end

Soshoget.start
