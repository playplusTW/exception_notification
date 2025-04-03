# frozen_string_literal: true

require 'test_helper'
require 'telegram/bot'

class TelegramNotifierTest < ActiveSupport::TestCase
  def setup
    @exception = fake_exception
    @exception.stubs(:backtrace).returns(fake_backtrace)
    @exception.stubs(:message).returns('exception message')
    ExceptionNotifier::TelegramNotifier.any_instance.stubs(:clean_backtrace).returns(fake_cleaned_backtrace)
    Socket.stubs(:gethostname).returns('example.com')
  end

  test 'should send a telegram notification if properly configured' do
    options = {
      token: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
      chat_id: '123456789',
    }

    Telegram::Bot::Client.any_instance.expects(:api).returns(mock('api')).times(1)
    mock('api').expects(:send_message).with(fake_notification)

    telegram_notifier = ExceptionNotifier::TelegramNotifier.new(options)
    telegram_notifier.call(@exception)
  end

  test 'should send a telegram notification without backtrace info if properly configured' do
    options = {
      token: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
      chat_id: '123456789',
    }

    Telegram::Bot::Client.any_instance.expects(:api).returns(mock('api')).times(1)
    mock('api').expects(:send_message).with(fake_notification(fake_exception_without_backtrace))

    telegram_notifier = ExceptionNotifier::TelegramNotifier.new(options)
    telegram_notifier.call(fake_exception_without_backtrace)
  end

  test 'should send the notification with specific backtrace lines' do
    options = {
      token: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
      chat_id: '123456789',
      backtrace_lines: 1,
    }

    Telegram::Bot::Client.any_instance.expects(:api).returns(mock('api')).times(1)
    mock('api').expects(:send_message).with(fake_notification(@exception, {}, nil, 1))

    telegram_notifier = ExceptionNotifier::TelegramNotifier.new(options)
    telegram_notifier.call(@exception)
  end

  test 'should send the notification with additional fields' do
    field = { title: 'Branch', value: 'master' }
    options = {
      token: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
      chat_id: '123456789',
      additional_fields: [field],
    }

    Telegram::Bot::Client.any_instance.expects(:api).returns(mock('api')).times(1)
    mock('api').expects(:send_message).with(fake_notification(@exception, {}, nil, 10, [field]))

    telegram_notifier = ExceptionNotifier::TelegramNotifier.new(options)
    telegram_notifier.call(@exception)
  end

  test 'should pass the additional parameters to Telegram API' do
    options = {
      token: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
      chat_id: '123456789',
      username: 'test',
      additional_parameters: {
        disable_web_page_preview: true,
      },
    }

    Telegram::Bot::Client.any_instance.expects(:api).returns(mock('api')).times(1)
    mock('api').expects(:send_message).with(fake_notification.merge(options[:additional_parameters]))

    telegram_notifier = ExceptionNotifier::TelegramNotifier.new(options)
    telegram_notifier.call(@exception)
  end

  test "shouldn't send a telegram notification if token is missing" do
    options = {
      chat_id: '123456789',
    }

    telegram_notifier = ExceptionNotifier::TelegramNotifier.new(options)

    assert_nil telegram_notifier.notifier
    assert_nil telegram_notifier.call(@exception)
  end

  test "shouldn't send a telegram notification if chat_id is missing" do
    options = {
      token: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
    }

    telegram_notifier = ExceptionNotifier::TelegramNotifier.new(options)

    assert_nil telegram_notifier.notifier
    assert_nil telegram_notifier.call(@exception)
  end

  test 'should pass along environment data' do
    options = {
      token: '123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11',
      chat_id: '123456789',
      ignore_data_if: lambda { |k, v|
        k.to_s == 'key_to_be_ignored' || v.is_a?(Hash)
      },
    }

    notification_options = {
      env: {
        'exception_notifier.exception_data' => { foo: 'bar', john: 'doe' },
      },
      data: {
        'user_id' => 5,
        'key_to_be_ignored' => 'whatever',
        'ignore_as_well' => { what: 'ever' },
      },
    }

    expected_data_string = "foo: bar\njohn: doe\nuser_id: 5"

    Telegram::Bot::Client.any_instance.expects(:api).returns(mock('api')).times(1)
    mock('api').expects(:send_message).with(fake_notification(@exception, notification_options, expected_data_string))

    telegram_notifier = ExceptionNotifier::TelegramNotifier.new(options)
    telegram_notifier.call(@exception, notification_options)
  end

  private

  def fake_exception
    5 / 0
  rescue StandardError => e
    e
  end

  def fake_exception_without_backtrace
    StandardError.new('my custom error')
  end

  def fake_backtrace
    [
      'backtrace line 1', 'backtrace line 2', 'backtrace line 3',
      'backtrace line 4', 'backtrace line 5', 'backtrace line 6',
    ]
  end

  def fake_cleaned_backtrace
    fake_backtrace[2..-1] # standard:disable Style/SlicingWithRange
  end

  def fake_notification(exception = @exception, notification_options = {},
                        data_string = nil, expected_backtrace_lines = 10, additional_fields = [])
    exception_name = "*#{/^[aeiou]/i.match?(exception.class.to_s) ? 'An' : 'A'}* `#{exception.class}`"
    if notification_options[:env].nil?
      text = "#{exception_name} *occurred in background*"
    else
      env = notification_options[:env]

      kontroller = env['action_controller.instance']
      request = "#{env['REQUEST_METHOD']} <#{env['REQUEST_URI']}>"

      text = "#{exception_name} *occurred while* `#{request}`"
      text += " *was processed by* `#{kontroller.controller_name}##{kontroller.action_name}`" if kontroller
    end

    text += "\n\n*Exception:* #{exception.message}"
    text += "\n\n*Hostname:* example.com"

    if exception.backtrace
      text += "\n\n*Backtrace:*\n```\n#{fake_cleaned_backtrace.first(expected_backtrace_lines).join("\n")}\n```"
    end

    if notification_options[:env]
      env = notification_options[:env]
      request_info = {
        'Request Method' => env['REQUEST_METHOD'],
        'Request URL' => env['REQUEST_URI'],
        'Request Path' => env['PATH_INFO'],
        'Request Query' => env['QUERY_STRING'],
        'Request IP' => env['REMOTE_ADDR'],
        'Request Host' => env['HTTP_HOST'],
        'Request User Agent' => env['HTTP_USER_AGENT'],
      }.reject { |_, v| v.nil? || v.empty? }

      data_string = if data_string
                      "#{data_string}\n#{request_info.map { |k, v| "#{k}: #{v}" }.join("\n")}"
                    else
                      request_info.map { |k, v| "#{k}: #{v}" }.join("\n")
                    end
    end

    text += "\n\n*Data:*\n```\n#{data_string}\n```" if data_string

    additional_fields.each do |field|
      text += "\n\n*#{field[:title]}:* #{field[:value]}"
    end

    {
      chat_id: '123456789',
      text: text,
      parse_mode: 'Markdown',
    }
  end
end
