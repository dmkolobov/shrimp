module Shrimp
  class Middleware
    def initialize(app)
      @app                        = app
    end

    def call(env)
      @request = Rack::Request.new(env)
      @render_pdf = false

      set_request_to_render_as_pdf(env) if render_as_pdf?

      status, headers, response = @app.call(env)

      if rendering_pdf? && headers['Content-Type'] =~ /text\/html|application\/xhtml\+xml/
        pipe_name = "tmp/#{(Random.new().rand * 100000).round}.pdf"

        if !File.exist?( pipe_name )
          `mkfifo #{pipe_name}`
        end

        body = ""
        next_line = ""

        Process.fork do
          Phantom.new(@request.url.sub(%r{\.pdf$}, ''), {}, @request.cookies).to_pipe pipe_name
        end

        File.open( File.expand_path pipe_name, "r+" ) do |pipe|
          while !( next_line.include? "EOF" )
            if next_line != nil
              body += next_line
            end

            next_line = pipe.gets
          end
          body += next_line
        end

        Process.wait
        File.delete pipe_name

        response = [body]

        # Do not cache PDFs
        headers.delete('ETag')
        headers.delete('Cache-Control')

        headers["Content-Length"]         = (body.respond_to?(:bytesize) ? body.bytesize : body.size).to_s
        headers["Content-Type"]           = "application/pdf"
      end
      [status, headers, response]
    end

    private

    def rendering_pdf?
      @render_pdf
    end

    def render_as_pdf?
      !!@request.path.match(%r{\.pdf$})
    end

    def set_request_to_render_as_pdf(env)
      @render_pdf = true
      path = @request.path.sub(%r{\.pdf$}, '')
      %w[PATH_INFO REQUEST_URI].each { |e| env[e] = path }
      env['HTTP_ACCEPT'] = concat(env['HTTP_ACCEPT'], Rack::Mime.mime_type('.html'))
      env["Rack-Middleware-Shrimp"] = "true"
    end

    def concat(accepts, type)
      (accepts || '').split(',').unshift(type).compact.join(',')
    end
  end
end
