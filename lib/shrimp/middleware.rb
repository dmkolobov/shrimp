module Shrimp
  class Middleware
    def initialize(app)
      @app                        = app
      @pipe_name                  = "tmp/pdfpipe.pdf"
    end

    def call(env)
      @request = Rack::Request.new(env)
      @render_pdf = false

      set_request_to_render_as_pdf(env) if render_as_pdf?

      status, headers, response = @app.call(env)

      if rendering_pdf? && headers['Content-Type'] =~ /text\/html|application\/xhtml\+xml/
        if !File.exist?( File.expand_path(@pipe_name) )
          `mkfifo #{File.expand_path(@pipe_name)}`
        end

        body = ""
        next_line = ""

        source = response.respond_to?(:body) ? response.body : response.join
        source = source.join if source.is_a?(Array)
        source.gsub!(/\'/, "\'")

        phantom_pid = Process.fork do
          Phantom.new(source, {}, @request.cookies).to_pipe! @pipe_name
        end

        body = IO.read File.expand_path(@pipe_name)

        Process.wait phantom_pid

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
