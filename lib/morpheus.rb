require 'version'

module Morpheus
  def self.transform(data, options = {})
    unless data.respond_to?(:root)
      raise_err "Input data must be a Nokogiri document or similar", options
    end

    options[:src_type] ||= data.root.name
    options[:src_format] ||= "xml"
    options[:tgt_type] ||= options[:src_type]
    options[:tgt_format] ||= options[:src_format]
    [:src_type, :src_format, :tgt_type, :tgt_format].each do |k|
      options[k] = options[k].to_s
    end

    if options[:src_type] == options[:tgt_type] and
    options[:src_format] == options[:tgt_format]
      return data # It's already what we want
    end

    transformation_seq = find_transform_seqs(
      options[:dir] || "#{RAILS_ROOT}/app/transforms",
      options[:src_type],
      options[:src_format],
      options[:tgt_type],
      options[:tgt_format]
    )
    unless transformation_seq
      raise_err "No transformation sequence found", options
    end

    transformation_seq.each do |path|
      # FIXME: Why do I need to have this in the loop?
      # If I generate it only once, it seems that the first XSLT
      # transform somehow fouls it up. So, I'm just
      # regenerating it each time. There should be a
      # better way to do this.
      context = options[:context] || Object.new
      xslt_context = context_to_xml(context).doc

      xslt_str = File.read(path)
      if path.end_with?(".haml")
        xslt_str = Haml::Engine.new(xslt_str).render(context)
      end
      xslt = Nokogiri::XSLT(xslt_str)
      xslt_env = Nokogiri::XML::Document.new
      xslt_env.root = Nokogiri::XML::Node.new("env", xslt_env)
      xslt_env.root << xslt_context.root
      xslt_env.root << data.root
      # Re-parse to allow for tags to be output through xsl:value without escaping
      data = Nokogiri::XML(xslt.transform(xslt_env).to_s)
      raise_err "XSLT processing using #{path} failed", options unless data.root
    end

    return data
  end

  private

  def self.raise_err(msg, options)
    err_msg = "Error transforming " +
      "'#{options[:src_type]}.#{options[:src_format]}' " +
      "to '#{options[:tgt_type]}.#{options[:tgt_format]}' " +
      ": #{msg}"
    raise err_msg
  end

  def self.find_transform_seqs(dir, from_type, from_format, to_type, to_format, max_depth = 3)
    return nil unless max_depth > 0

    Dir.glob("#{dir}/#{to_type}.#{to_format}.*").each do |fn|
      basename = File.basename(fn)
      fn_props = {}
      [
        ["from", :type, to_type],
        ["via", :format, "xml"]
      ].map do |tag, key, default|
        if basename =~ /\.#{tag}-(\w+)\./
          fn_props[key] = $1
        else
          fn_props[key] = default
        end
      end

      if fn_props[:type] == from_type && fn_props[:format] == from_format
        return [fn]
      else
        indirect_path = find_transform_seqs(
          dir,
          from_type,
          from_format,
          fn_props[:type],
          fn_props[:format],
          max_depth - 1
        )
        if indirect_path
          return indirect_path + [fn]
        end
      end
    end

    return nil
  end

  def self.simple_xmlify(v)
    case v
    when Hash
      v.map{|key, val|
        "<#{CGI::escapeHTML(key.to_s)}>#{simple_xmlify(val)}</#{CGI::escapeHTML(key.to_s)}>"
      }.join("")
    when Array
      r = []
      v.each_index do |i|
        r << "<val>#{simple_xmlify(v[i])}</val>"
      end
      r.join("")
    else
      if v.respond_to?(:to_xml)
        begin
          v.to_xml(:skip_instruct => true).to_s
        rescue ArgumentError
          # Some to_xml methods don't understand skip_instruct
          v.to_xml.to_s
        end
      elsif v.respond_to?(:to_s)
        CGI::escapeHTML(v.to_s)
      else
        ""
      end
    end
  end

  def self.context_to_xml(context)
    builder = Nokogiri::XML::Builder.new do |env|
      env.context_ do
        context.send(:instance_variables).each do |sym|
          env.send(sym.to_s.sub(/^@/, '')) do
            var = context.send(:instance_variable_get, sym)
            env << simple_xmlify(var)
          end
        end
      end
    end
  end
end
