require 'thor'
require 'net/http'

require './lib/sosho'

class Soshoget < Thor
  default_command :get
  desc 'get', 'get specific volume'
  method_option :pdf, type: :boolean, aliases: '-p', default: false, desc: 'create pdf'
  method_option :all, type: :boolean, aliases: '-a', default: false, desc: 'get all soshos'
  method_option :verbose, type: :boolean, aliases: '-v', default: false, desc: 'verbose output'
  method_option :overwrite, type: :boolean, aliases: '-o', default: false, desc: 'overwrite existing image'

  OpenSSL::SSL::SSLContext::DEFAULT_PARAMS[:options] |= OpenSSL::SSL::OP_LEGACY_SERVER_CONNECT

  def self.exit_on_failure?
    true
  end

  def get(volume)
    volumes = options['all'] ? all_volumes : [volume]
    logger = Sosho::Logger.new(options[:verbose])

    connection.use_ssl = true
    connection.start do |handler|
      volumes.each do |vol|
        volume = Sosho::Volume.new(num: vol, handler:, logger:, overwrite: options['overwrite'])
        volume.get
        wait
        next unless options['pdf']

        Sosho::PDF.new(files: volume.files, filename: volume.title, logger:).create
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
