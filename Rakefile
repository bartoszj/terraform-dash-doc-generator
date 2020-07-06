require "nokogiri"
require "erb"
require "sqlite3"
require "pathname"

class Index
  attr_accessor :db

  def initialize(path)
    @db = SQLite3::Database.new path
  end

  def drop
    @db.execute <<-SQL
      DROP TABLE IF EXISTS searchIndex
    SQL
  end

  def create
    db.execute <<-SQL
      CREATE TABLE searchIndex(id INTEGER PRIMARY KEY, name TEXT, type TEXT, path TEXT)
    SQL
    db.execute <<-SQL
      CREATE UNIQUE INDEX anchor ON searchIndex (name, type, path)
    SQL
  end

  def reset
    drop
    create
  end

  def insert(type, path)
    doc = Nokogiri::HTML(File.open(path).read)

    header = doc.xpath("//div[@id='inner']/h1").first
    if header.nil?
      header = doc.xpath("//div[@id='inner']/h2").first
    end
    if header.nil?
      header = doc.xpath("//body/h1").first
    end

    unless header.nil?
      name = header.content.match(/(\w+.+)/)[0].strip.sub(/.*: (.*)/m, "\\1")
    end 

    if name.nil? or name.empty?
      name = File.basename(path, ".*")
    end

    name = name.sub("(Deprecated)", "")

    raise "Empty name for #{path}" if name.nil? or name.empty?

    @db.execute <<-SQL, name: name, type: type, path: path
      INSERT OR IGNORE INTO searchIndex (name, type, path)
      VALUES(:name, :type, :path)
    SQL
  end
end

task default: [:clean, :build, :setup, :copy, :create_index, :package]

task :clean do
  rm_rf "build"
  rm_rf "Terraform.docset"
end

task :build do
  sh "make build"
end

task :setup do
  mkdir_p "Terraform.docset/Contents/Resources/Documents"

  # Icon
  # at older docs there is no retina icon
  if File::exist? "content/source/assets/images/favicons/favicon-16x16.png" and File::exist? "content/source/assets/images/favicons/favicon-32x32.png"
    cp "content/source/assets/images/favicons/favicon-16x16.png", "Terraform.docset/icon.png"
    cp "content/source/assets/images/favicons/favicon-32x32.png", "Terraform.docset/icon@2x.png"
  elsif File::exists? "content/source/assets/images/favicon.png"
    cp "content/source/assets/images/favicon.png", "Terraform.docset/icon.png"
  else
    cp "content/source/images/favicon.png", "Terraform.docset/icon.png"
  end

  # Info.plist
  File.open("Terraform.docset/Contents/Info.plist", "w") do |f|
    f.write <<-XML
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
    <key>CFBundleIdentifier</key>
    <string>terraform</string>
    <key>CFBundleName</key>
    <string>Terraform</string>
    <key>DocSetPlatformFamily</key>
    <string>terraform</string>
    <key>isDashDocset</key>
    <true/>
    <key>DashDocSetFamily</key>
    <string>dashtoc</string>
    <key>dashIndexFilePath</key>
    <string>docs/index.html</string>
    <key>DashDocSetFallbackURL</key>
    <string>https://www.terraform.io/</string>
    </dict>
</plist>
    XML
  end
end

task :copy do
  file_list = []
  Dir.chdir("content/build") { file_list = Dir.glob("**/*").sort }

  file_list.each do |path|
    source = "content/build/#{path}"
    target = "Terraform.docset/Contents/Resources/Documents/#{path}"

    case
    when File.stat(source).directory?
      mkdir_p target
    when source.match(/\.gz$/)
      next
    when source.match(/\.html$/)
      doc = Nokogiri::HTML(File.open(source).read)
      
      unless doc.title.nil?
        doc.title = doc.title.sub(" - Terraform by HashiCorp", "")
      end

      doc.xpath("//a[contains(@class, 'anchor')]").each do |e|
        a = Nokogiri::XML::Node.new "a", doc
        a["class"] = "dashAnchor"
        a["name"] = "//apple_ref/cpp/%{type}/%{name}" %
          {type: "Section", name: ERB::Util.url_encode(e.parent.children.last.text.strip)}
        e.previous = a
      end

      doc.xpath("//link[starts-with(@href, '/')]").each do |e|
        e["href"] = Pathname.new(e["href"]).relative_path_from(Pathname.new("/#{path}").dirname).to_s
      end
      doc.xpath("//a[starts-with(@href, '/')]").each do |e|
        e["href"] = Pathname.new(e["href"]).relative_path_from(Pathname.new("/#{path}").dirname).to_s
      end

      doc.xpath('//script').each do |script|
        if script.text != ""
          script.remove
        end
      end
      doc.xpath("//aside").each do |e|
        e.remove
      end
      doc.xpath("id('header')").each do |e|
        e.remove
      end
      doc.xpath("id('inner-header-grid')").each do |e|
        e.remove
      end
      doc.xpath("//div[contains(@class, 'g-alert-banner')]").each do |e|
        e.remove
      end
      doc.xpath("//div[contains(@class, 'mega-nav-sandbox')]").each do |e|
        e.remove
      end
      doc.xpath("//div[contains(@class, 'oics-button')]").each do |e|
        e.remove
      end
      doc.xpath("//div[contains(@class, 'docs-sidebar')]").each do |e|
        e.parent.remove
      end
      doc.xpath("id('docs-sidebar')").each do |e|
        e.remove
      end
      doc.xpath("id('footer')").each do |e|
        e.remove
      end

      doc.xpath('//div[@id="inner"]/h1').each do |e|
        e["style"] = "margin-top: 0px"
      end
      doc.xpath("//div[contains(@class, 'container')]").each do |e|
        e["style"] = "width: 100%; padding-top: 30px; padding-left: 30px; padding-right: 30px;"
      end
      doc.xpath("//div[contains(@role, 'main')]").each do |e|
        e["style"] = "width: 100%"
      end

      File.open(target, "w") { |f| f.write doc }
    else
      cp source, target
    end
  end
end

task :create_index do
  index = Index.new("Terraform.docset/Contents/Resources/docSet.dsidx")
  index.reset

  Dir.chdir("Terraform.docset/Contents/Resources/Documents") do
    # example
    Dir.glob("intro/examples/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Sample", path
    end
    # getting-started
    Dir.glob("intro/getting-started/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Guide", path
    end
    # backends
    Dir.glob("docs/backends/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Environment", path
    end
    # configuration
    Dir.glob("docs/configuration/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Setting", path
    end
    # commands
    Dir.glob("docs/commands/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Command", path
    end
    # import
    Dir.glob("docs/import/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Section", path
    end
    # state
    Dir.glob("docs/state/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Instance", path
    end
    # providers
    Dir.glob("docs/providers/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      next unless path.match(/\.html$/)
      maybe_type_code = path.split("/").reverse.drop(1).first

      if maybe_type_code == "r"
        type = "Resource"
      elsif maybe_type_code == "d"
        type = "Directive"
      else
        type = "Provider"
      end

      index.insert type, path
    end
    # provisioners
    Dir.glob("docs/provisioners/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Provisioner", path
    end
    # modules
    Dir.glob("docs/modules/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Module", path
    end
    # plugins
    Dir.glob("docs/plugins/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Plugin", path
    end
    # internals
    Dir.glob("docs/internals/**/*")
      .find_all{ |f| File.stat(f).file? }.each do |path|

      index.insert "Protocol", path
    end
  end
end

task :import do
  sh "open Terraform.docset"
end

task :package do
  sh "tar --exclude='.DS_Store' -cvzf Terraform.tgz Terraform.docset"
end
