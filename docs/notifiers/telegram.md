# Telegram Notifier

The Telegram notifier sends notifications to a Telegram chat using a bot.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'exception_notification_telegram'
```

And then execute:

```bash
$ bundle install
```

## Usage

### Rails

In your Rails application, you can configure the notifier in `config/initializers/exception_notification.rb`:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  telegram: {
    token: 'YOUR_TELEGRAM_BOT_TOKEN',
    chat_id: 'YOUR_CHAT_ID',
    username: 'Bot Name', # optional
    icon_url: 'https://example.com/icon.png', # optional
    icon_emoji: ':robot_face:', # optional
    backtrace_lines: 10, # optional, defaults to 10
    additional_parameters: { # optional, additional Telegram API parameters
      disable_web_page_preview: true
    },
    ignore_data_if: ->(k, v) { v.nil? || v.empty? }, # optional, filter data condition
    additional_fields: [ # optional, additional fields
      { title: 'Environment', value: Rails.env },
      { title: 'Version', value: '1.0.0' }
    ]
  }
```

### Standalone

You can also use the notifier in a standalone application:

```ruby
require 'exception_notification/telegram_notifier'

notifier = ExceptionNotifier::TelegramNotifier.new(
  token: 'YOUR_TELEGRAM_BOT_TOKEN',
  chat_id: 'YOUR_CHAT_ID'
)

begin
  # your code
rescue => exception
  notifier.call(exception)
end
```

## Configuration Options

| Option                  | Description                        | Required | Default |
| ----------------------- | ---------------------------------- | -------- | ------- |
| `token`                 | Telegram Bot Token                 | Yes      | -       |
| `chat_id`               | Telegram Chat ID                   | Yes      | -       |
| `username`              | Bot display name                   | No       | -       |
| `icon_url`              | Bot icon URL                       | No       | -       |
| `icon_emoji`            | Bot icon emoji                     | No       | -       |
| `backtrace_lines`       | Number of backtrace lines to show  | No       | 10      |
| `additional_parameters` | Additional Telegram API parameters | No       | `{}`    |
| `ignore_data_if`        | Data filtering condition           | No       | -       |
| `additional_fields`     | Additional fields to include       | No       | `[]`    |

## Message Format

The Telegram notifier sends formatted messages that include:

1. Error type
2. Error message
3. Hostname
4. Backtrace (if available)
5. Request information (if available)
6. Environment data
7. Additional fields

Messages use Markdown format and support:

- Bold text
- Italic text
- Code blocks
- Links

## Getting a Bot Token

To get a bot token:

1. Open Telegram and search for [@BotFather](https://t.me/botfather)
2. Start a chat and send `/newbot`
3. Follow the instructions to create a new bot
4. BotFather will give you a token - save this for your configuration

## Getting a Chat ID

To get a chat ID:

1. Start a chat with your bot
2. Send a message to the bot
3. Visit `https://api.telegram.org/bot<YourBOTToken>/getUpdates`
4. Look for the `chat` object in the response
5. The `id` field is your chat ID

## Example Message

Here's an example of what a notification might look like:

```
*An* `ZeroDivisionError` *occurred while* `GET <http://example.com/posts/1>` *was processed by* `posts#show`

*Exception:* divided by 0

*Hostname:* example.com

*Backtrace:*
```

app/controllers/posts_controller.rb:8:in `/'
app/controllers/posts_controller.rb:8:in `show'

```

*Data:*
```

Request Method: GET
Request URL: http://example.com/posts/1
Request Path: /posts/1
Request IP: 127.0.0.1
Request Host: example.com
Request User Agent: Mozilla/5.0...

```

*Environment:* production
*Version:* 1.0.0
```

## Troubleshooting

### Common Issues

1. **Bot not responding**

   - Verify your bot token is correct
   - Make sure the bot has been started
   - Check that the chat ID is correct

2. **Messages not formatted correctly**

   - Ensure you're using valid Markdown syntax
   - Check that special characters are properly escaped

3. **Missing information**
   - Verify all required parameters are provided
   - Check that the environment data is being passed correctly

### Debugging

You can enable debug mode to see more information about the notification process:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  telegram: {
    token: 'YOUR_TELEGRAM_BOT_TOKEN',
    chat_id: 'YOUR_CHAT_ID',
    debug: true # Enable debug mode
  }
```

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/your-username/exception_notification_telegram.
