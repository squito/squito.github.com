module Jekyll
  class TagPage < Page
    include Convertible
    attr_accessor :site, :pager, :name, :ext
    attr_accessor :basename, :dir, :data, :content, :output
#<h3>{{ post.date | date: "%A %d.%m." }} &mdash; <a href="{{ post.url }}">{{ post.title }}</a></h3>

    def initialize(site, tag, posts)
      @site = site
      @tag = tag
      self.ext = '.html'
      self.basename = 'index'
      self.content = <<-EOS
<ul class="posts">
{% for post in page.posts %}
<li class=\"tag\">
<span>{{ post.date | date: "%B %e, %Y" }}</span>
<a href="{{ post.url }}" >{{ post.title }}</a></li>
{% endfor %}
</ul>
EOS
      self.data = {
        'layout' => 'tag',
        'type' => 'tag',
        'title' => "Tag - #{@tag}",
        'posts' => posts
      }
    end

    def render(layouts, site_payload)
      payload = Utils.deep_merge_hashes({
        "page" => self.to_liquid,
        "paginator" => pager.to_liquid
      }, site_payload)
      do_layout(payload, layouts)
    end

    def url
      File.join("/tag", @tag, "index.html")
    end

    def to_liquid
      Utils.deep_merge_hashes(self.data, {
                             "url" => self.url,
                             "content" => self.content
                           })
    end


    def destination(dest)
      path = File.join(dest, CGI.unescape(self.url))
      path
    end


    def write(dest, dest_suffix = nil)
      dest = File.join(dest, dest_suffix) if dest_suffix
      path = destination(dest)

      FileUtils.mkdir_p(File.dirname(path))
      File.open(path, 'w') do |f|
        f.write(self.output)
      end
    end

    def html?
      true
    end
  end
end
