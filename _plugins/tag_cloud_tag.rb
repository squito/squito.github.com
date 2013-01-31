module Jekyll
  class TagCloudTag < Liquid::Tag
    safe = true

    def initialize(tag_name, text, tokens)
      super
    end

    def render(context)
      html = ""
      html << '<ul class="tag-list" id="main-tag-list">'
      tags = context.registers[:site].tags
      avg = tags.inject(0.0) {|memo, tag| memo += tag[1].length} / tags.length
      weights = Hash.new
      tags.each {|tag| weights[tag[0]] = tag[1].length/avg}
      tags.each do |tag, posts|
        s = posts.count
        html << "<li class=\"tag\"><a href=\"/tag/#{tag}\" tag-weight=\"#{s}\" title=\"Tag - #{tag}\">#{tag}</a></li> "
        #{}"<span style='font-size: #{sprintf("%d", weights[tag] * 100)}%'><a href='/tag/#{tag}/'>#{tag}</a></span>\n"
      end
      html << "</ul>"
      html
    end
  end
end

Liquid::Template.register_tag('tag_cloud', Jekyll::TagCloudTag)
