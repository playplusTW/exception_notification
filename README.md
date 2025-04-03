# Exception Notification

[![Gem Version](https://badge.fury.io/rb/exception_notification.svg)](https://badge.fury.io/rb/exception_notification)
[![Build Status](https://github.com/kmcphillips/exception_notification/actions/workflows/ci.yml/badge.svg)](https://github.com/kmcphillips/exception_notification/actions/workflows/ci.yml)

---

The Exception Notification gem provides a set of [notifiers](#notifiers) for sending notifications when errors occur in a Rack/Rails application. The built-in notifiers can deliver notifications by [email](docs/notifiers/email.md), [HipChat](docs/notifiers/hipchat.md), [Slack](docs/notifiers/slack.md), [Mattermost](docs/notifiers/mattermost.md), [Teams](docs/notifiers/teams.md), [IRC](docs/notifiers/irc.md), [Amazon SNS](docs/notifiers/sns.md), [Google Chat](docs/notifiers/google_chat.md), [Datadog](docs/notifiers/datadog.md), [Telegram](docs/notifiers/telegram.md) or via custom [WebHooks](docs/notifiers/webhook.md).

There's a [Railscast (2011) about Exception Notification](http://railscasts.com/episodes/104-exception-notifications-revised) you can see that may help you getting started.

## Gem status

This gem is not under active development, but is maintained. There are more robust and modern solutions for exception handling. But this code was [extracted from Rails about 15+ years ago](https://github.com/rails/exception_notification) and still has lots of value for some applications.

## Requirements

- Ruby 3.2 or greater
- If using Rails, version 7.1 or greater. (Sinatra or other Rack-based applications are supported.)

## Getting Started

Add the following line to your application's Gemfile:

```ruby
gem "exception_notification"
```

### Rails

In order to install ExceptionNotification as an [engine](https://api.rubyonrails.org/classes/Rails/Engine.html), just run the following command from the terminal:

```bash
rails g exception_notification:install
```

This generates an initializer file, `config/initializers/exception_notification.rb` with some default configuration, which you should modify as needed.

Make sure the gem is not listed solely under the `production` group in your `Gemfile`, since this initializer will be loaded regardless of environment. If you want it to only be enabled in production, you can add this to your configuration:

```ruby
config.ignore_if do |exception, options|
  !!Rails.env.local?
end
```

The generated initializer file will include this require:

```ruby
require "exception_notification/rails"
```

which automatically adds the ExceptionNotification middleware to the Rails middleware stack. This middleware is what watches for unhandled exceptions from your Rails app (except for [background jobs](#background-jobs)) and notifies you when they occur.

The generated file adds an `email` notifier:

```ruby
  config.add_notifier :email, {
    email_prefix: "[ERROR] ",
    sender_address: %{"Notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  }
```

**Note**: In order to enable delivery notifications by email, make sure you have [ActionMailer configured](docs/notifiers/email.md#actionmailer-configuration).

#### Adding middleware manually

Alternatively, if for some reason you don't want to `require "exception_notification/rails"`, you can manually add the middleware, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  email: {
    email_prefix: "[PREFIX] ",
    sender_address: %{"notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  }
```

This is the older way of configuring ExceptionNotification (which prior to version 4 was the _only_ way to configure it), and is still the way used in some of the examples.

Options passed to the `ExceptionNotification::Rack` middleware in this way are translated to the equivalent configuration options for the `ExceptionNotification.configure` of configuring (compare to the [Rails](#rails) example above).

### Rack/Sinatra

In order to use ExceptionNotification with Sinatra, please take a look in the [example application](examples/sinatra).

### Custom Data, e.g. Current User

Save the current user in the `request` using a controller callback.

```ruby
class ApplicationController < ActionController::Base
  before_action :prepare_exception_notifier

  private

  def prepare_exception_notifier
    request.env["exception_notifier.exception_data"] = {
      current_user: current_user
    }
  end
end
```

The current user will show up in your email, in a new section titled "Data".

```
------------------------------- Data:

* data: {:current_user=>
  #<User:0x007ff03c0e5860
   id: 3,
   email: "jane.doe@example.com", # etc...
```

For more control over the display of custom data, see "Email notifier -> Options -> sections" below.

### Filtering parameters

Since the error notification contains the full request parameters, you may want to filter out sensitive information. The `filter_parameters` in Rails can be used to filter out sensitive information from the request parameters.

```ruby
config.filter_parameters += [:secret_details, :credit_card_number]
```

See the Rails documentation for more information: https://guides.rubyonrails.org/configuring.html#config-filter-parameters

## Notifiers

ExceptionNotification relies on notifiers to deliver notifications when errors occur in your applications. By default the following notifiers are available:

- [Datadog notifier](docs/notifiers/datadog.md)
- [Email notifier](docs/notifiers/email.md)
- [HipChat notifier](docs/notifiers/hipchat.md)
- [IRC notifier](docs/notifiers/irc.md)
- [Slack notifier](docs/notifiers/slack.md)
- [Mattermost notifier](docs/notifiers/mattermost.md)
- [Teams notifier](docs/notifiers/teams.md)
- [Amazon SNS](docs/notifiers/sns.md)
- [Google Chat notifier](docs/notifiers/google_chat.md)
- [Telegram notifier](docs/notifiers/telegram.md)
- [WebHook notifier](docs/notifiers/webhook.md)

You also can implement your own [custom notifier](docs/notifiers/custom.md).

## Error Grouping

In general, ExceptionNotification will send a notification when every error occurs, which may result in a problem: if your site has a high throughput and a particular error is raised frequently, you will receive too many notifications. During a short period of time, your mail box may be filled with thousands of exception mails, or your mail server may even become slow. To prevent this, you can choose to group errors by setting the `:error_grouping` option to `true`.

Error grouping uses a default formula of `Math.log2(errors_count)` to determine whether to send the notification, based on the accumulated error count for each specific exception. This makes the notifier only send a notification when the count is: 1, 2, 4, 8, 16, 32, 64, 128, ..., (2\*\*n). You can use `:notification_trigger` to override this default formula.

The following code shows the available options to configure error grouping:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  ignore_exceptions: ['ActionView::TemplateError'] + ExceptionNotifier.ignored_exceptions,
  email:  {
    email_prefix: '[PREFIX] ',
    sender_address: %{"notifier" <notifier@example.com>},
    exception_recipients: %w{exceptions@example.com}
  },
  error_grouping: true,
  # error_grouping_period: 5.minutes,    # the time before an error is regarded as fixed
  # error_grouping_cache: Rails.cache,   # for other applications such as Sinatra, use one instance of ActiveSupport::Cache::Store
  #
  # notification_trigger: specify a callback to determine when a notification should be sent,
  #   the callback will be invoked with two arguments:
  #     exception: the exception raised
  #     count: accumulated errors count for this exception
  #
  # notification_trigger: lambda { |exception, count| count % 10 == 0 }
```

## Ignore Exceptions

You can choose to ignore certain exceptions, which will make ExceptionNotification avoid sending notifications for those specified. There are three ways of specifying which exceptions to ignore:

- `:ignore_exceptions` - By exception class (i.e. ignore RecordNotFound ones)

- `:ignore_crawlers` - From crawler (i.e. ignore ones originated by Googlebot)

- `:ignore_if` - Custom (i.e. ignore exceptions that satisfy some condition)

- `:ignore_notifer_if` - Custom (i.e. let each notifier ignore exceptions if by-notifier condition is satisfied)

### :ignore_exceptions

_Array of strings, default: %w{ActiveRecord::RecordNotFound Mongoid::Errors::DocumentNotFound AbstractController::ActionNotFound ActionController::RoutingError ActionController::UnknownFormat ActionDispatch::Http::MimeNegotiation::InvalidType Rack::Utils::InvalidParameterError}_

Ignore specified exception types. To achieve that, you should use the `:ignore_exceptions` option, like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        ignore_exceptions: ['ActionView::TemplateError'] + ExceptionNotifier.ignored_exceptions,
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        }
```

The above will make ExceptionNotifier ignore a _TemplateError_ exception, plus the ones ignored by default.

### :ignore_crawlers

_Array of strings, default: []_

In some cases you may want to avoid getting notifications from exceptions made by crawlers. To prevent sending those unwanted notifications, use the `:ignore_crawlers` option like this:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        ignore_crawlers: %w{Googlebot bingbot},
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        }
```

### :ignore_if

_Lambda, default: nil_

You can ignore exceptions based on a condition. Take a look:

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        ignore_if: ->(env, exception) { exception.message =~ /^Couldn't find Page with ID=/ },
                                        email: {
                                          email_prefix: '[PREFIX] ',
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com},
                                        }
```

You can make use of both the environment and the exception inside the lambda to decide wether to avoid or not sending the notification.

### :ignore_notifier_if

- Hash of Lambda, default: nil\*

In case you want a notifier to ignore certain exceptions, but don't want other notifiers to skip them, you can set by-notifier ignore options.
By setting below, each notifier will ignore exceptions when its corresponding condition is met.

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
                                        ignore_notifier_if: {
                                          email: ->(env, exception) { !Rails.env.production? },
                                          slack: ->(env, exception) { exception.message =~ /^Couldn't find Page with ID=/ }
                                        },

                                        email: {
                                          sender_address: %{"notifier" <notifier@example.com>},
                                          exception_recipients: %w{exceptions@example.com}
                                        },
                                        slack: {
                                          webhook_url: '[Your webhook url]',
                                          channel: '#exceptions',
                                        }
```

To customize each condition, you can make use of environment and the exception object inside the lambda.

## Rack X-Cascade Header

Some rack apps (Rails in particular) utilize the "X-Cascade" header to pass the request-handling responsibility to the next middleware in the stack.

Rails' routing middleware uses this strategy, rather than raising an exception, to handle routing errors (e.g. 404s); to be notified whenever a 404 occurs, set this option to "false."

### :ignore_cascade_pass

_Boolean, default: true_

Set to false to trigger notifications when another rack middleware sets the "X-Cascade" header to "pass."

## Background Jobs

The ExceptionNotification middleware can only detect notifications that occur during web requests (controller actions). If you have any Ruby code that gets run _outside_ of a normal web request (hereafter referred to as a "background job" or "background process"), exceptions must be detected a different way (the middleware won't even be running in this context).

Examples of background jobs include jobs triggered from a cron file or from a queue.

ExceptionNotificatior can be configured to automatically notify of exceptions occurring in most common types of Rails background jobs such as [rake tasks](#rake-tasks). Additionally, it provides optional integrations for some 3rd-party libraries such as [Resque and Sidekiq](#resquesidekiq). And of course you can manually trigger a notification if no integration is provided.

### Rails runner

To enable exception notification for your runner commands, add this line to your `config/application.rb` _below_ the `Bundler.require` line (ensuring that `exception_notification` and `rails` gems will have already been required):

```ruby
require 'exception_notification/rails'
```

(Requiring it from an initializer is too late, because this depends on the `runner` callback, and that will have already been fired _before_ any initializers run.)

### Rake tasks

If you've already added `require 'exception_notification/rails'` to your `config/application.rb` as described [above](#rails-runner), then there's nothing further you need to do. (That Engine has a `rake_tasks` callback which automatically requires the file below.)

Alternatively, you can add this line to your `config/initializers/exception_notification.rb`:

```ruby
require 'exception_notification/rake'
```

### Manually notify of exceptions

If you want to manually send a notifications from a background process that is not _automatically_ handled by ExceptionNotification, then you need to manually call the `notify_exception` method like this:

```ruby
begin
  # some code...
rescue => e
  ExceptionNotifier.notify_exception(e)
end
```

You can include information about the background process that created the error by including a `data` parameter:

```ruby
begin
  # some code...
rescue => e
  ExceptionNotifier.notify_exception(
    e,
    data: { worker: worker.to_s, queue: queue, payload: payload}
  )
end
```

### Resque/Sidekiq

Instead of manually calling background notifications for each job/worker, you can configure ExceptionNotification to do this automatically. For this, run:

```bash
rails g exception_notification:install --resque
```

or

```bash
rails g exception_notification:install --sidekiq
```

As above, make sure the gem is not listed solely under the `production` group, since this initializer will be loaded regardless of environment.

## Manually notify of exceptions from `rescue_from` handler

If your controller rescues and handles an error, the middleware won't be able to see that there was an exception, and the notifier will never be run. To manually notify of an error after rescuing it, you can do something like the following:

```ruby
class SomeController < ApplicationController
  rescue_from Exception, with: :server_error

  def server_error(exception)
    # Whatever code that handles the exception

    ExceptionNotifier.notify_exception(
      exception,
      env: request.env, data: { message: 'was doing something wrong' }
    )
  end
end
```

## Development and support

Pull requests are very welcome! Issues too.

You can always debug the gem by running `rake console`.

Please read first the [Contributing Guide](CONTRIBUTING.md).

And always follow the [code of conduct](CODE_OF_CONDUCT.md).

## License

Copyright (c) 2005 Jamis Buck, released under the [MIT license](http://www.opensource.org/licenses/MIT).

Maintainer: [Kevin McPhillips](https://github.com/kmcphillips)

# Exception Notification Telegram

Telegram notifier for [Exception Notification](https://github.com/smartinez87/exception_notification) gem.

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
    username: 'Bot Name', # 可選
    icon_url: 'https://example.com/icon.png', # 可選
    icon_emoji: ':robot_face:', # 可選
    backtrace_lines: 10, # 可選，預設為 10
    additional_parameters: { # 可選，額外的 Telegram API 參數
      disable_web_page_preview: true
    },
    ignore_data_if: ->(k, v) { v.nil? || v.empty? }, # 可選，過濾資料的條件
    additional_fields: [ # 可選，額外的欄位
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
  # 你的程式碼
rescue => exception
  notifier.call(exception)
end
```

## Configuration Options

| Option                  | Description              | Required | Default |
| ----------------------- | ------------------------ | -------- | ------- |
| `token`                 | Telegram Bot Token       | Yes      | -       |
| `chat_id`               | Telegram Chat ID         | Yes      | -       |
| `username`              | Bot 的顯示名稱           | No       | -       |
| `icon_url`              | Bot 的圖示 URL           | No       | -       |
| `icon_emoji`            | Bot 的圖示 Emoji         | No       | -       |
| `backtrace_lines`       | 顯示的堆疊追蹤行數       | No       | 10      |
| `additional_parameters` | 額外的 Telegram API 參數 | No       | `{}`    |
| `ignore_data_if`        | 過濾資料的條件           | No       | -       |
| `additional_fields`     | 額外的欄位               | No       | `[]`    |

## Message Format

Telegram notifier 會發送格式化的訊息，包含以下資訊：

1. 錯誤類型
2. 錯誤訊息
3. 主機名稱
4. 堆疊追蹤（如果有的話）
5. 請求資訊（如果有的話）
6. 環境資料
7. 額外欄位

訊息使用 Markdown 格式，支援粗體、斜體和程式碼區塊。

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/your-username/exception_notification_telegram. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/your-username/exception_notification_telegram/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the ExceptionNotificationTelegram project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/your-username/exception_notification_telegram/blob/master/CODE_OF_CONDUCT.md).

# Exception Notification (Fork)

這是 [Exception Notification](https://github.com/smartinez87/exception_notification) 的 fork 版本，增加了 Telegram 通知器的支援。

## 安裝

在你的 Gemfile 中加入：

```ruby
gem 'exception_notification',
    github: 'playplusTW/exception_notification',
    branch: 'main'
```

然後執行：

```bash
bundle install
```

## 設定

在你的 Rails 應用程式中，你需要設定 Exception Notification。在 `config/initializers/exception_notification.rb` 中加入：

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  telegram: {
    token: 'YOUR_BOT_TOKEN',
    chat_id: 'YOUR_CHAT_ID',
    additional_parameters: {
      parse_mode: 'MarkdownV2'
    }
  }
```

## 必要依賴

由於這是 fork 版本，你需要手動在 Gemfile 中加入以下依賴：

```ruby
gem 'telegram-bot-ruby', '>= 0.19.0'
```

## 使用方式

### 基本設定

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  telegram: {
    token: 'YOUR_BOT_TOKEN',
    chat_id: 'YOUR_CHAT_ID'
  }
```

### 進階設定

```ruby
Rails.application.config.middleware.use ExceptionNotification::Rack,
  telegram: {
    token: 'YOUR_BOT_TOKEN',
    chat_id: 'YOUR_CHAT_ID',
    username: 'Exception Bot',
    icon_url: 'https://example.com/icon.png',
    icon_emoji: ':warning:',
    backtrace_lines: 10,
    additional_parameters: {
      parse_mode: 'MarkdownV2'
    }
  }
```

### 支援的參數

- `token`: Telegram Bot Token（必要）
- `chat_id`: 目標聊天室 ID（必要）
- `username`: 機器人顯示名稱
- `icon_url`: 機器人頭像 URL
- `icon_emoji`: 機器人頭像 emoji
- `backtrace_lines`: 堆疊追蹤顯示行數（預設：10）
- `additional_parameters`: 額外的 Telegram API 參數

## 訊息格式

錯誤通知會包含以下資訊：

- 錯誤類型
- 錯誤訊息
- 發生時間
- 請求資訊（如果有的話）
  - 請求方法
  - 請求 URL
  - 請求參數
  - IP 位址
  - 主機名稱
  - User Agent
- 堆疊追蹤
- 環境資訊

## 注意事項

1. 確保你的 Telegram Bot Token 是有效的
2. 確保 Bot 已經被加入到目標聊天室
3. 確保 Bot 有發送訊息的權限

## 疑難排解

如果遇到問題，請檢查：

1. Bot Token 是否正確
2. Chat ID 是否正確
3. Bot 是否有適當的權限
4. 網路連接是否正常

## 授權

本專案採用 MIT 授權條款。詳見 [LICENSE](LICENSE) 檔案。
