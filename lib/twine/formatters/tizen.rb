# encoding: utf-8
require 'cgi'
require 'rexml/document'

module Twine
  module Formatters
    class Tizen < Abstract
      FORMAT_NAME = 'tizen'
      EXTENSION = '.xml'
      DEFAULT_FILE_NAME = 'strings.xml'
      LANG_CODES = Hash[
        'eng-GB' => 'en',
        'rus-RU' => 'ru',
        'fra-FR' => 'fr',
        'deu-DE' => 'de',
        'spa-ES' => 'es',
        'ita-IT' => 'it',
        'ces-CZ' => 'cs',
        'pol-PL' => 'pl',
        'por-PT' => 'pt',
        'ukr-UA' => 'uk'
      ]
      DEFAULT_LANG_CODES = Hash[
      ]

      def self.can_handle_directory?(path)
        Dir.entries(path).any? { |item| /^values.*$/.match(item) }
      end

      def default_file_name
        return DEFAULT_FILE_NAME
      end

      def write_all_files(path)
        if !File.directory?(path)
          raise Twine::Error.new("Directory does not exist: #{path}")
        end

        langs_written = []
        Dir.foreach(path) do |item|
          if item == "." or item == ".."
            next
          end
          item = File.join(path, item)
          if !File.directory?(item)
            lang = determine_language_given_path(item)
            if lang
              write_file(item, lang)
              langs_written << lang
            end
          end
        end
        if langs_written.empty?
          raise Twine::Error.new("Failed to genertate any files: No languages found at #{path}")
        end
      end

      def determine_language_given_path(path)
        path_arr = path.split(File::SEPARATOR)
        path_arr.each do |segment|
          match = /^(.*-.*)\.xml$/.match(segment)
          if match
            lang = match[1]
            lang = LANG_CODES.fetch(lang, nil)
            return lang
          end
        end
        return
      end

      def read_file(path, lang)
        resources_regex = /<resources(?:[^>]*)>(.*)<\/resources>/m
        key_regex = /<string name="(\w+)">/
        comment_regex = /<!-- (.*) -->/
        value_regex = /<string name="\w+">(.*)<\/string>/
        key = nil
        value = nil
        comment = nil

        File.open(path, 'r:UTF-8') do |f|
          content_match = resources_regex.match(f.read)
          if content_match
            for line in content_match[1].split(/\r?\n/)
              key_match = key_regex.match(line)
              if key_match
                key = key_match[1]
                value_match = value_regex.match(line)
                if value_match
                  value = value_match[1]
                  value = CGI.unescapeHTML(value)
                  value.gsub!('\\\'', '\'')
                  value.gsub!('\\"', '"')
                  value = iosify_substitutions(value)
                  value.gsub!(/(\\u0020)*|(\\u0020)*\z/) { |spaces| ' ' * (spaces.length / 6) }
                else
                  value = ""
                end
                set_translation_for_key(key, lang, value)
                if comment and comment.length > 0 and !comment.start_with?("SECTION:")
                  set_comment_for_key(key, comment)
                end
                comment = nil
              end

              comment_match = comment_regex.match(line)
              if comment_match
                comment = comment_match[1]
              end
            end
          end
        end
      end

      def format_header(lang)
        "<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<!-- Tizen Strings File -->\n<!-- Generated by Twine #{Twine::VERSION} -->\n<!-- Language: #{lang} -->"
      end

      def format_sections(strings, lang)
        result = '<string_table  Bversion="2.0.0.201311071819" Dversion="20120315">'
        
        result += super + "\n"

        result += '</string_table>'
      end

      def format_section_header(section)
        "\t<!-- SECTION: #{section.name} -->"
      end

      def format_comment(comment)
        "\t<!-- #{comment.gsub('--', '—')} -->"
      end

      def key_value_pattern
        "\t<text id=\"IDS_%{key}\">%{value}</text>"
      end

      def format_key(key)
        key.upcase
      end

      def format_value(value)
        value = escape_quotes(value)
        # Tizen enforces the following rules on the values
        #  1) apostrophes and quotes must be escaped with a backslash
        value.gsub!("'", "\\\\'")
        #  2) HTML escape the string
        value = CGI.escapeHTML(value)
        #  3) fix substitutions (e.g. %s/%@)
        value = androidify_substitutions(value)
        #  4) replace beginning and end spaces with \0020. Otherwise Tizen strips them.
        value.gsub(/\A *| *\z/) { |spaces| '\u0020' * spaces.length }
      end
    end
  end
end
