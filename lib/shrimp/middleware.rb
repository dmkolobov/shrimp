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

      status = 200
      headers = Hash.new
      response = ["blank_response"]

      if rendering_pdf?
        if !File.exist?( File.expand_path(@pipe_name) )
          `mkfifo #{File.expand_path(@pipe_name)}`
        end

        Rails.logger.debug "[666] Preparing to fork..."
        phantom_pid = Process.fork do
          Rails.logger.debug "[666] Launching Phantom child-process..."
          Phantom.new(@request.url.sub(%r{\.pdf$}, ''), {}, @request.cookies).to_pipe! @pipe_name
        end

        Rails.logger.debug "[666] Sleep for a second"
        sleep 0.1
        Rails.logger.debug "[666] Parent process continuing..."

        Rails.logger.debug "[666] preparing to read..."
        body = IO.read File.expand_path(@pipe_name)

        Rails.logger.debug "[666] waiting for Phantom to terminate"
        Process.waitpid 0

        response = [body]

        # Do not cache PDFs
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
