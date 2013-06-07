module Shrimp
  class Middleware
    def initialize(app, options = { }, conditions = { })
      @app                        = app
      @options                    = options
      @conditions                 = conditions
      @options[:polling_interval] ||= 1
      @options[:polling_offset]   ||= 1
      @options[:cache_ttl]        ||= 1
      @options[:request_timeout]  ||= @options[:polling_interval] * 10
    end

    def call(env)
    #  @request = Rack::Request.new(env)
    #  status, headers, response = @app.call(env)
    #
    #  if render_as_pdf? #&& headers['Content-Type'] =~ /text\/html|application\/xhtml\+xml/
    #    body = Phantom.new(@request.url.sub(%r{\.pdf$}, ''), @options, @request.cookies).to_pdf
    #    response = [body]
    #
    #    # Do not cache PDFs
    #    headers.delete('ETag')
    #    headers.delete('Cache-Control')
    #
    #    headers["Content-Length"]         = (body.respond_to?(:bytesize) ? body.bytesize : body.size).to_s
    #    headers["Content-Type"]           = "application/pdf"
    #  end
    end

    private

    def render_as_pdf?
      !!@request.path.match(%r{\.pdf$})
    end
end
