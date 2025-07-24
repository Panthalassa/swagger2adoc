require 'json'
require 'fileutils'

# Load the OpenAPI 3 JSON file
input_file = ARGV[0] || 'swagger.json'
swagger = JSON.parse(File.read(input_file))

# Create output directory
output_dir = ARGV[1] || './adoc_output'
FileUtils.mkdir_p(output_dir)

# === overview.adoc ===
overview = []
info = swagger['info'] || {}
overview << "= #{info['title'] || 'API Documentation'}"
overview << ""
overview << "Version: #{info['version']}" if info['version']
overview << ""
overview << (info['description'] || 'No description provided.')
File.write(File.join(output_dir, 'overview.adoc'), overview.join("\n"))

# === paths.adoc ===
paths = swagger['paths'] || {}
paths_adoc = ["== API Paths", ""]
paths.each do |path, methods|
  methods.each do |http_method, details|
    operation_id = details['operationId'] || "#{http_method.upcase} #{path}"
    summary = details['summary'] || ''
    description = details['description'] || ''
    tags = details['tags']&.join(', ') || 'none'

    paths_adoc << "=== #{operation_id}"
    paths_adoc << "* Method: `#{http_method.upcase}`"
    paths_adoc << "* Path: `#{path}`"
    paths_adoc << "* Tags: #{tags}"
    paths_adoc << ""
    paths_adoc << description
    paths_adoc << ""

    # Consumes (MIME types)
    mime_types = []
    if details.dig('requestBody', 'content')
      mime_types = details['requestBody']['content'].keys
    end
    if mime_types.any?
      paths_adoc << "==== Consumes"
      mime_types.each { |type| paths_adoc << "* `#{type}`" }
      paths_adoc << ""
    end

    # Responses
    responses = details['responses'] || {}
    if responses.any?
      paths_adoc << "==== Responses"
      responses.each do |status, resp|
        paths_adoc << "* `#{status}`: #{resp['description']}"
      end
      paths_adoc << ""
    end

    # Example response
    example = nil
    responses.each do |_, resp|
      content = resp['content']&.values&.first
      if content && content['examples']
        example_obj = content['examples'].values.first
        example = example_obj['value'] if example_obj
      elsif content && content['example']
        example = content['example']
      end

      break if example
    end

    if example
      paths_adoc << "==== Example Response"
      paths_adoc << "[source,json]"
      paths_adoc << "----"
      paths_adoc << JSON.pretty_generate(example)
      paths_adoc << "----"
      paths_adoc << ""
    end
  end
end
File.write(File.join(output_dir, 'paths.adoc'), paths_adoc.join("\n"))

# === definitions.adoc (components.schemas) ===
schemas = swagger.dig('components', 'schemas') || {}
defs_adoc = ["== Definitions", ""]
schemas.each do |name, schema|
  defs_adoc << "=== #{name}"
  defs_adoc << (schema['description'] || '')
  defs_adoc << ""
  if schema['properties']
    defs_adoc << "[cols=\"1,1\", options=\"header\"]"
    defs_adoc << "|==="
    defs_adoc << "| Property | Type"
    schema['properties'].each do |prop, meta|
      type = meta['type'] || 'object'
      defs_adoc << "| #{prop} | #{type}"
    end
    defs_adoc << "|==="
    defs_adoc << ""
  end
end
File.write(File.join(output_dir, 'definitions.adoc'), defs_adoc.join("\n"))

# === security.adoc ===
security_schemes = swagger.dig('components', 'securitySchemes') || {}
security_adoc = ["== Security", ""]
security_schemes.each do |name, scheme|
  type = scheme['type']
  desc = scheme['description'] || ''
  security_adoc << "=== #{name}"
  security_adoc << "* Type: #{type}"
  security_adoc << desc
  security_adoc << ""
end
File.write(File.join(output_dir, 'security.adoc'), security_adoc.join("\n"))
