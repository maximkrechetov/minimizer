require 'open-uri'
require 'nokogiri'
require 'uri'
require 'css_parser'
require 'fileutils'
include CssParser

class Minimizer

  class IncorrectURIError < StandardError; end

  def initialize(uri)
    @combinations_index = 0
    @combinations_length = 2
    @combinations = ('a'..'z').to_a.combination(@combinations_length).to_a
    @accordance_hash = {}

    @uri = URI(uri)
    @url = "#{@uri.scheme}://#{@uri.host}"

    begin
      @document = Nokogiri::HTML(open(@uri.to_s))
    rescue
      raise IncorrectURIError
    end

  end

  def minimize
    unless File.directory?('public/css/tmp')
      FileUtils.mkdir_p('public/css/tmp')
    end

    File.open("public/css/tmp/#{@uri.host}.minimized.css", 'w+') do |file|
      _minimize_css(file)
    end

    _replace_css_classes
    _add_minimized_css_file
    _change_href
    _change_src
    _change_inline_styles

    @document.to_html
  end

  def accordance_hash
    _fill_accordance_hash
    @accordance_hash
  end

  private

  def _minimize_css(file)
    @document.css('link[rel="stylesheet"]').each do |element|
      next if element.attributes['href'].nil?

      href = _get_href(element)
      parts = href.split('/')

      parser = CssParser::Parser.new
      parser.load_uri!(href)

      parser.each_selector do |selector, declarations, specificity|
        declarations.gsub!(/url\(\w/, "url(#{parts.first(parts.length - 1).join('/')}/")
        declarations.gsub!("url('../../", "url('#{parts.first(parts.length - 3).join('/')}/")
        declarations.gsub!("url('../", "url('#{parts.first(parts.length - 2).join('/')}/")
        declarations.gsub!("url(../", "url(#{parts.first(parts.length - 2).join('/')}/")

        selector.scan(/\.[_a-zA-Z]+[_a-zA-Z0-9\-]*/).each do |klass|
          next if klass.length < 4
          old_classname = klass.sub('.', '')

          short_name = @combinations[@combinations_index].join('')

          if @accordance_hash.has_key?(old_classname)
            short_name = @accordance_hash[old_classname]
          end

          @accordance_hash[old_classname] = short_name

          selector.sub!(klass, ".#{short_name}")

          if @combinations_index == @combinations.length - 1
            @combinations_length += 1
            @combinations = ('a'..'z').to_a.combination(@combinations_length).to_a
          end

          @combinations_index += 1
        end

        file << selector
        file << ' {'
        file << declarations
        file << '} '
      end

      element.remove
    end
  end

  def _fill_accordance_hash
    @document.css('link[rel="stylesheet"]').each do |element|
      next if element.attributes['href'].nil?

      href = _get_href(element)
      parser = CssParser::Parser.new
      parser.load_uri!(href)

      parser.each_selector do |selector, declarations, specificity|

        selector.scan(/\.[_a-zA-Z]+[_a-zA-Z0-9\-]*/).each do |klass|
          next if klass.length < 4

          old_classname = klass.sub('.', '')
          short_name = @combinations[@combinations_index].join('')

          if @accordance_hash.has_key?(old_classname)
            short_name = @accordance_hash[old_classname]
          end

          @accordance_hash[old_classname] = short_name

          if @combinations_index == @combinations.length - 1
            @combinations_length += 1
            @combinations = ('a'..'z').to_a.combination(@combinations_length).to_a
          end

          @combinations_index += 1
        end
      end
    end
  end

  def _replace_css_classes
    @accordance_hash.each do |key, value|
      @document.css("[class~='#{key}']").each do |node|
        result = []
        classes = node.attributes['class'].value.split(' ')
        classes.each do |klass|
          if klass == key
            result << value
          else
            result << klass
          end
        end

        node.attributes['class'].value = result.join(' ')
      end
    end
  end

  def _add_minimized_css_file
    @document.css('head').each do |element|
      link = "<link rel='stylesheet' href='/css/tmp/#{@uri.host}.minimized.css'>"
      element.children.first.add_previous_sibling(link)
    end
  end

  def _change_href
    @document.css('link').each do |element|
      next if element.attributes['href'].nil?
      next if element.attributes['rel'] and element.attributes['rel'].value == 'stylesheet'
      href = element.attributes['href'].value
      next if href.start_with?('http://', '//', 'https://', 'www')
      element.attributes['href'].value = "#{@url}/#{href}"
    end
  end

  def _change_src
    @document.css('[src]').each do |element|
      src = element.attributes['src'].value
      next if src.start_with?('http://', '//', 'https://', 'www')
      element.attributes['src'].value = "#{@url}/#{src}"
    end
  end

  def _change_inline_styles
    @document.css('[style]').each do |element|
      style = element.attributes['style'].value
      style = style.gsub("'", "").gsub(/url\(\//, "url(#{@url}/")
      element.attributes['style'].value = style
    end
  end

  def _get_href(element)
    href = element.attributes['href'].value

    if href.start_with?('//')
      href.sub!('//', 'http://')
    end

    if not href.start_with?('http://', 'https://', 'www')
      href = "#{@url}#{href}"
    end

    href
  end

end