# SnFoil::Context

![build](https://github.com/limited-effort/snfoil-context/actions/workflows/main.yml/badge.svg) [![maintainability](https://api.codeclimate.com/v1/badges/6a7a2f643707c17cb879/maintainability)](https://codeclimate.com/github/limited-effort/snfoil-context/maintainability)

SnFoil Contexts are a simple way to ensure a workflow pipeline can be easily established end extended.  It helps by creating a workflow, allowing additional steps at specific intervals, and reacting to success or failure, you should find your code being more maintainable and testable.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'snfoil-context'
```

## Usage
While contexts are powerful, they aren't a magic bullet.  Each function should strive to only contain a single purpose.  This also has the added benefit of outlining some basic tests - if it is in a function it should have a related test.


### Quickstart Example

```ruby
require 'snfoil/context'

class TokenContext
  include SnFoil::Context

  interval :always

  action(:create) { |options| options[:object].save }
  action(:expire) { |options| options[:object].update(expired_at: Time.current) }

  # log the current action. . . because reasons?
  always { |options| LocalLogger.debug "START Running #{options[:action]}" }

  # run always interval
  setup_expire { |options| run_interval(:always, **options) }
  setup_create { |options| run_interval(:always, **options) }

  # inject created_by
  setup_create { |options| options[:params][:created_by] = entity }

  # initialize token
  before_create do |options|
    options[:object] = Token.create(options[:params])
    options
  end

  # send token email
  after_create_success { |options| TokenMailer.new(token: option[:object]) }

  # log expiration error
  after_expire_failure { |options| ErrorLogger.notify(error: options[:object].errors) }
end
```


### Initialize

When you `new` up a SnFoil Context you should provide the entity running the actions.  This will usually be a user but you can pass in anything.  This will be accessible from within the context as `entity`.

```ruby
  TokenContext.new(current_user)
```

### Intervals
Intervals are a collection of `Proc` functions and a final method.  Each `proc` of the interval will pass the return of the first to the next.

You can run an interval by calling `run_interval` with the interval name as the first argument and an optional options keyword arguments.

```ruby
class TokenContext
  include SnFoil::Context

  interval :demo

  def demo(**options)
    puts 'Demo Method'
    options
  end

  demo do |options|
    puts "First Proc"
    puts options

    options[:foo] = :bar

    options
  end

  demo do |options|
    puts "Second Proc"
    puts options

    options
  end
end

TokenContext.new.run_interval(:demo, lorem: :ipsum)
  # console>    First Proc
  # console>    { lorem: :ipsum }
  # console>    Second Proc
  # console>    { foo: :bar, lorem: :ipsum }
  # console>    Demo Method
```

### Multiple Intervals

You can define intervals one at a time

```ruby
  interval :demo
  interval :production
```

They can also be defined in bulk using `intervals`

```ruby
  intervals :demo, :production
```

### Actions
Actions are a group of intervals that create a workflow around a single primary function.

To start you will need to define an action.  

Arguments:
* `name` - The name of this action will also set the name of all the hooks and methods later generated.
* `with` - Keyword Param - The method name of the primary action.  Either this or a block is required
* `block` - Block -  The block of the primary action.  Either this or with is required

```ruby
# lib/contexts/token_context
require 'snfoil/context'

class TokenContext
  include SnFoil::Context

  ...

  action(:expire) { |options| options[:object].update(expired_at: Time.current) }
end
```

This will generate the intervals of the pipeline.  In this example the following get made:
* setup_expire
* before_expire
* after_expire_success
* after_expire_failure
* after_expire

Now you can trigger the workflow by calling the action as a method on an instance of the context.

```ruby
class TokenContext
  include SnFoil::Context

  action(:expire) { |options| options[:object].update(expired_at: Time.current) }
end

TokenContext.new(current_user).expire(object: current_token)
```

If you want to reuse the primary action or just prefer methods, you can pass in the method name you would like to call, rather than providing a block.  If a method name and a block are provided, the block is ignored. 


```ruby
# lib/contexts/token_context
require 'snfoil/context'

class TokenContext
  include SnFoil::Context

  action :expire, with: :expire_token

  def expire_token(options)
    options[:object].update(expired_at: Time.current)
  end
end
```

#### Primary Function
The primary function is the function that determines whether or not the action is successful.  To do this, the primary function must always return a truthy value if the action was successful, or a falsey one if it failed.

The primary function is passed one argument which is the return value of the closest preceding interval function.

```ruby
# lib/contexts/token_context
require 'snfoil/context'

class TokenContext
  include SnFoil::Context

  action :expire, with: :expire_token

  before_expire do |options|
    options[:foo] = bar
    options
  end

  def expire_token(options)
    puts options[:foo] # => logs 'bar' to the console
    ...
  end
end
```

#### Action Intervals
The following are the intervals SnFoil Contexts set up in the order they occur.  The suggested uses are just very simple examples.  You can chain contexts to setup very complex interactions in a very easy-to-manage workflow.

<table>
  <thead>
    <th>Name</th>
    <th>Suggested Use</th>
  </thead>
  <tbody>
    <tr>
      <td>setup_&lt;action&gt;</td>
      <td>
        <div>* find or create a model</div>
        <div>* setup params needed later in the action</div>
        <div>* set scoping </div>
      </td>
    </tr>
    <tr>
      <td>before_&lt;action&gt;</td>
      <td>
        <div>* alter model or set attributes</div>
      </td>
    </tr>
    <tr>
      <td>primary action</td>
      <td>
        <div>* persist database changes</div>
        <div>* make primary network call</div>
      </td>
    </tr>
    <tr>
      <td>after_&lt;action&gt;_success</td>
      <td>
        <div>* setup additional relationships</div>
        <div>* success specific logging</div>
      </td>
    </tr>
    <tr>
      <td>after_&lt;action&gt;_failure</td>
      <td>
        <div>* cleanup failed remenants</div>
        <div>* call bug tracker</div>
        <div>* failure specific logging</div>
      </td>
    </tr>
    <tr>
      <td>after_&lt;action&gt;</td>
      <td>
        <div>* perform necessary required cleanup</div>
        <div>* log outcome</div>
      </td>
    </tr>
  </tbody>
<table>


#### Hook and Method Design

SnFoil Contexts try hard to not store variables longer than necessary.  To facilitate this we have chosen to pass an object (we normally use a hash called options) to each hook and method, and the return from the hook or method is passed down the chain to the next hook or method.  

The only method or block that does not get its value passed down the chain is the primary action - which must always return a truthy value of whether or not the action was successful.

#### Hooks
Hooks make it very easy to compose multiple actions that need to occur in a specific order.  You can have as many repeated hooks as you would like.  This makes defining single responsibility hooks very simple, and they will get called in the order they are defined.

<strong>Important Note</strong> Hooks <u>always</u> need to return the options hash at the end.

##### Example
```ruby
# Call the webhooks for third party integrations
after_expire_success do |options|
  call_webhook_for_model(options[:object])
  options
end

# Commit business logic to internal process
after_expire_success do |options|
  finalize_business_logic(options[:object])
  options
end

# notify error tracker
after_expire_error do |options|
  notify_errors(options[:object].errors)
  options
end
```

#### Methods
Methods allow users to create inheritable actions that occur in a specific order.  Methods will always run after their hook counterpart.  Since these are inheritable, you can chain needed actions through the parent hierarchy by using the `super` keyword.   These are very useful when you need to have something always happen at the end of an Interval.

<strong>Important Note</strong> Methods <u>always</u> need to return the options hash at the end.

<i>Author's opinion:</i> While simpler than hooks, they do not allow for as clean of a composition as hooks.

##### Example

```ruby
# Call the webhooks for third party integrations
# Commit business logic to internal process
def after_expire_success(**options)
  options = super

  call_webhook_for_model(options[:object])
  finalize_business_logic(options[:object])

  options
end

# notify error tracker
def after_expire_error(**options)
  options = super

  notify_errors(options[:object].errors)

  options
end
```

### Authorize
The original purpose of all of SnFoil was to ensure there was a good consistent way to authenticate and authorize entities.  As such authorize hooks were built directly into the workflow.

These authorization hooks are always called twice.  Once after `setup_<action>` and once after `before_<action>`

The `authorize` method functions much like primary action except the first argument is usually the name of the action you are authorizing.

Arguments:
* `name` - The name of this action to be authorized.  If omitted, all actions without a specific associated authorize will use this
* `with` - Keyword Param - The method name of the primary action.  Either this or a block is required
* `block` - Block -  The block of the primary action.  Either this or with is required

```ruby
# lib/contexts/token_context
require 'snfoil/context'

class TokenContext
  include SnFoil::Context

  action :expire, with: :expire_token

  authorize(:expire) { |_options| :entity.is_admin? }

  ...
end
```

You can also call authorize without an action name.  This will have all action authorize with the provided method or block unless there is a more specific authorize action configured.  It's probably easier explained with an example


```ruby
# lib/contexts/token_context
require 'snfoil/context'

class TokenContext
  include SnFoil::Context

  action :expire, with: :expire_token #=> will authorize by checking the entity is an admin
  action :search, with: :query_tokens #=> will authorize by checking the entity is a user
  action :show, with: :find_token #=> will authorize by checking the entity is a user

  authorize(:expire) { |_options| entity.is_admin? }
  authorize { |_options| entity.is_user? }

  ...
end
```

#### Why before and after?
Simply to make sure the entity is allowed access to the primary target and is allowed to make the requested alterations/interactions.

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/limited-effort/snfoil-context. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/limited-effort/snfoil-context/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [Apache 2 License](https://opensource.org/licenses/Apache-2.0).

## Code of Conduct

Everyone interacting in the Snfoil::Context project's codebases, issue trackers, chat rooms, and mailing lists is expected to follow the [code of conduct](https://github.com/limited-effort/snfoil-context/blob/main/CODE_OF_CONDUCT.md).
