#encoding utf-8
require 'colorize'
require 'international/version'
require 'csv'
require 'file_manager'
require 'htmlentities'
Encoding.default_external = Encoding::UTF_8
module International

  class MainApp

    def initialize(arguments)

      # defaults
      @path_to_output = 'output/'
      @path_to_csv = nil
      @dryrun = false
      @platform = 'android'
      @default_lang = 'en'

      # Parse Options
      arguments.push "-h" if arguments.length == 0
      create_options_parser(arguments)

      manage_opts

    end

    def is_valid_platform
      @platform.eql?'android' or @platform.eql?'ios'
    end

    ### Options parser
    def create_options_parser(args)
      require 'optparse'
      OptionParser.new  do |opts|
        opts.banner = "Usage: international [OPTIONS]"
        opts.separator  ''
        opts.separator  "Options"

        opts.on('-c PATH_TO_CSV', '--csv PATH_TO_CSV', 'Path to the .csv file') do |csv_path|
          @path_to_csv = csv_path
        end

        opts.on('-p PLATFORM', '--platform PLATFORM', 'Choose between "android" and "ios" (default: "android")') do |platform|
          @platform = platform.downcase
        end

        opts.on('-o PATH_TO_OUTPUT', '--output PATH_TO_OUTPUT', 'Path to the desired output folder') do |path_to_output|
          unless path_to_output[-1,1] == '/'
            path_to_output = "#{path_to_output}/"
          end

          @path_to_output = path_to_output
        end

        opts.on('-d', '--dryrun', 'Only simulates the output and don\'t write files') do |aa|
          @dryrun = true
        end

        opts.on('-h', '--help', 'Displays help') do
          @require_analyses = false
          puts opts.help
          exit
        end
        opts.on('-v', '--version', 'Displays version') do
          @require_analyses = false
          puts International::VERSION
          exit
        end
      end.parse!(args)
    end

    ### Manage options
    def manage_opts

      unless @path_to_csv
        puts "Please give me a path to a CSV".yellow
        exit 1
      end

      unless is_valid_platform
        puts "The platform you chose could not be found, pick 'android' or 'ios'".yellow
        exit 1
      end

      hash = csv_to_hash(@path_to_csv)
      separate_languages hash
    end

    ### CSV TO HASH
    def csv_to_hash(path_to_csv)
      if path_to_csv.start_with?('http://') || path_to_csv.start_with?('https://')
        require 'open-uri'
        response = open(path_to_csv)
        data = response.read

        body = data.force_encoding("UTF-8")
        #CSV.new(body).each do |l|
        #  puts l
        #end
      else
        p Encoding.find("filesystem")
        file = File.open(path_to_csv, "rb")
        body = file.read().force_encoding("UTF-8")
      end
      body = "key#{body}" if body[0,1] == ','

      CSV::Converters[:blank_to_nil] = lambda do |field|
        field && field.empty? ? nil : field
      end

      csv = CSV.new(body, :headers => true, :header_converters => :symbol, :converters => [:all, :blank_to_nil])

      csv.to_a.map {|row| row.to_hash }
    end

    def separate_languages(all)
      languages = all.first.keys.drop(1)
        separated = Hash.new
      coder = HTMLEntities.new
      default_items = Array.new

      languages.each  do | lang|
        items = Array.new
        all.each_with_index do | row, idx|

          next if row.first.nil?
          begin
            encoded = row[lang].gsub("'",'\\\\\'')
            encoded = encoded.gsub('"','\\"')
            encoded = encoded.gsub('&','&amp;')
            #encoded = coder.encode(encoded)
            #encoded = row[lang].encode('utf-8')
            if encoded != row[lang]
            #puts "ENC 0 #{lang} '#{row[lang]}'"
            #puts "ENC 1 #{lang} '#{encoded}'"
            end

          rescue => e
             end
          # replcing substitutionds for ios
          replaced = row[lang]
          if @platform.eql?'ios'
            begin
              if /\%/.match(replaced)
                replaced = replaced.gsub(/\%[1-9]\$s/,'%@')
                replaced = replaced.gsub(/\%[1-9]\$d/,'%@')
                replaced = replaced.gsub("%s","%@")
              end
              replaced = replaced.gsub(/\n/,"\\n")
            rescue => e

            end

          end
           item = {
            :key => row.first.last, # dem hacks
            :translation => replaced,

            :translation_encoded => encoded || row[lang]
          }
          unless lang.to_s.eql?@default_lang
            if item[:translation].nil?
              item[:translation] = default_items[idx][:translation]
              item[:translation_encoded] = default_items[idx][:translation_encoded]
            end
            if item[:translation_encoded].nil?
              item[:translation_encoded] = default_items[idx][:translation_encoded]
            end
          end
          unless item[:key].to_s.empty?
            items.push item
          end


          if lang.to_s.eql?@default_lang
            #puts lang
            #puts default_items.count

            default_items.push item
          end
        end
        manager = FileManager.new lang, items, @path_to_output, @platform, @dryrun
        manager.create_file
      end
    end

  end
end
