# frozen_string_literal: true

require 'telegram/bot'

module ExceptionNotifier
  class TelegramNotifier < BaseNotifier
    include ExceptionNotifier::BacktraceCleaner

    attr_accessor :notifier

    def initialize(options)
      super
      begin
        @ignore_data_if = options[:ignore_data_if]
        @backtrace_lines = options.fetch(:backtrace_lines, 10)
        @additional_fields = options[:additional_fields]

        token = options.fetch(:token)
        @chat_id = options.fetch(:chat_id)
        @message_opts = options.fetch(:additional_parameters, {})
        @username = options[:username]
        @icon_url = options[:icon_url]
        @icon_emoji = options[:icon_emoji]
        @notifier = Telegram::Bot::Client.new(token)
      rescue StandardError
        @notifier = nil
      end
    end

    def call(exception, options = {})
      clean_message = escape_markdown(exception.message)
      text = format_message(exception, clean_message, options)

      return unless valid?

      send_notice(exception, options, clean_message) do |_msg, _opts|
        message_opts = @message_opts.merge(
          chat_id: @chat_id,
          text: text,
          parse_mode: 'MarkdownV2',
        )

        message_opts[:username] = options[:username] if options.key?(:username)
        message_opts[:icon_url] = options[:icon_url] if options.key?(:icon_url)
        message_opts[:icon_emoji] = options[:icon_emoji] if options.key?(:icon_emoji)

        @notifier.api.send_message(message_opts)
      end
    end

    protected

    def valid?
      !@notifier.nil?
    end

    private

    def escape_markdown(text)
      return '' if text.nil?

      text.to_s.gsub(/([_*\[\]()~`>#+\-=|{}.!])/, '\\\\\1')
    end

    def format_message(exception, clean_message, options)
      text, data = information_from_options(exception.class, options)
      backtrace = clean_backtrace(exception) if exception.backtrace

      text += "\n\n*Exception:* #{clean_message}"
      text += "\n\n*Hostname:* #{escape_markdown(Socket.gethostname)}"

      if backtrace
        formatted_backtrace = backtrace.first(@backtrace_lines).map { |line| escape_markdown(line) }.join("\n")
        text += "\n\n*Backtrace:*\n```\n#{formatted_backtrace}\n```"
      end

      unless data.empty?
        deep_reject(data, @ignore_data_if) if @ignore_data_if.is_a?(Proc)
        data_string = data.map { |k, v| "#{escape_markdown(k)}: #{escape_markdown(v)}" }.join("\n")
        text += "\n\n*Data:*\n```\n#{data_string}\n```"
      end

      if @additional_fields
        @additional_fields.each do |field|
          text += "\n\n*#{escape_markdown(field[:title])}:* #{escape_markdown(field[:value])}"
        end
      end

      text
    end

    def information_from_options(exception_class, options)
      errors_count = options[:accumulated_errors_count].to_i

      measure_word = if errors_count > 1
                       errors_count
                     else
                       /^[aeiou]/i.match?(exception_class.to_s) ? 'An' : 'A'
                     end

      exception_name = "*#{measure_word}* `#{escape_markdown(exception_class)}`"
      env = options[:env]

      if env.nil?
        data = options[:data] || {}
        text = "#{exception_name} *occurred in background*\n"
      else
        data = (env['exception_notifier.exception_data'] || {}).merge(options[:data] || {})

        kontroller = env['action_controller.instance']
        request = "#{env['REQUEST_METHOD']} <#{env['REQUEST_URI']}>"
        text = "#{exception_name} *occurred while* `#{escape_markdown(request)}`"
        if kontroller
          text += " *was processed by* `#{escape_markdown(kontroller.controller_name)}##{escape_markdown(kontroller.action_name)}`"
        end
        text += "\n"

        request_info = {
          'Request' => "#{env['REQUEST_METHOD']} #{env['action_controller.instance']&.request&.fullpath || env['REQUEST_URI']}",
          'Parameters' => env['action_controller.instance']&.params&.to_h,
          'Request IP' => env['REMOTE_ADDR'],
          'Request User Agent' => env['HTTP_USER_AGENT'],
        }.reject { |_, v| v.nil? || v.empty? }

        data.merge!(request_info)
      end

      [text, data]
    end

    def deep_reject(hash, block)
      hash.each do |k, v|
        deep_reject(v, block) if v.is_a?(Hash)
        hash.delete(k) if block.call(k, v)
      end
    end
  end
end
