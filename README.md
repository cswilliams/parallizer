# Parallizer - Execute your service layer in parallel

Parallizer executes service methods in parallel, stores the method results, and creates a proxy of your service with those results. Your application then uses the short-lived service proxy (think of a single request for a web application) and calls your methods without again executing the underlying implementation. For applications that make considerable use of web service calls, Parallizer can give you a considerable performance boost.

## Installation

    gem install parallizer

## Examples

### Parallizing a service object

Here's an example service.

```ruby
require 'rubygems'
require 'net/http'
require 'nokogiri'

class SearchService
  def top_urls_for_foo
    parse_search_result_for_urls(Net::HTTP.get('www.google.com', '/search?q=foo'))
  end
  
  def top_urls_for_bar
    parse_search_result_for_urls(Net::HTTP.get('www.google.com', '/search?q=bar'))
  end
  
  private
  
  def parse_search_result_for_urls(content)
    Nokogiri::HTML.parse(content).search('h3.r > a').collect(&:attributes).collect{ |attrs| attrs['href'].value }
  end
end

$search_service = SearchService.new
```

Now create a Parallizer for that service and add all of the methods you intend to call. This begins the execution of the service methods in worker threads. Then create a service proxy that uses the stored results of the method calls.

```ruby
require 'parallizer'

parallizer = Parallizer.new($search_service)
parallizer.add.top_urls_for_foo
parallizer.add.top_urls_for_bar
search_service = parallizer.create_proxy
```

Now use that service proxy in your application logic. Calls to these methods will not make an HTTP request
and will not parse HTML. That was done by the parallel worker threads.

```ruby
puts search_service.top_urls_for_foo
puts search_service.top_urls_for_bar
```

Additional calls in your application logic will not result in an additional call to the underlying service.

```ruby
# Called twice, but no extra service call. (Be careful not to mutate the returned object!)
puts search_service.top_urls_for_foo
puts search_service.top_urls_for_foo
```

If there are additional methods on your service that were not parallized, you can still call them.

```ruby
puts search_service.top_urls_for_foobar # makes an HTTP request and parses result
```

### Parallizing methods with parameters

Parallizing also works on service methods with parameters.

```ruby
require 'net/http'
require 'nokogiri'
require 'cgi'

class SearchService
  def top_urls(search_term)
    parse_search_result_for_urls(Net::HTTP.get('www.google.com', "/search?q=#{CGI.escape(search_term)}"))
  end
  
  private
  
  def parse_search_result_for_urls(content)
    Nokogiri::HTML.parse(content).search('h3.r > a').collect(&:attributes).collect{ |attrs| attrs['href'].value }
  end
end

$search_service = SearchService.new
```

The parallel execution and proxy creation.

```ruby
require 'parallizer'

parallizer = Parallizer.new($search_service)
parallizer.add.top_urls('foo')
parallizer.add.top_urls('bar')
search_service = parallizer.create_proxy
```

Using the service proxy in your application logic.

```ruby
puts search_service.top_urls('foo') # returns stored value
puts search_service.top_urls('bar') # returns stored value
puts search_service.top_urls('foobar') # makes an HTTP request and parses result
```


### Parallizing class methods

You can even parallize class methods.

```ruby
require 'net/http'
require 'parallizer'

parallizer = Parallizer.new(Net::HTTP)
parallizer.add.get('www.google.com', '/search?q=foo')
parallizer.add.get('www.google.com', '/search?q=bar')
http_service = parallizer.create_proxy
```

Use the service proxy.

```ruby
# use your service proxy
http_service.get('www.google.com', '/search?q=foo') # returns stored value
http_service.get('www.google.com', '/search?q=bar') # returns stored value
http_service.get('www.google.com', '/search?q=foobar') # makes an HTTP request and parses result
```


### Service Method Retries

Parallize also allows you to retry methods that fail (any exception raised is considered a failure).

```ruby
require 'net/http'
require 'parallizer'

parallizer = Parallizer.new(Net::HTTP, :retries => 3)
parallizer.add.get('www.google.com', '/search?q=foo')
http_service = parallizer.create_proxy

http_service.get('www.google.com', '/search?q=foo') # Will be called up to 4 times
```


### Retrieve all results

You can also execute all added methods in parallel and get all the results.

```ruby
require 'net/http'
require 'parallizer'

parallizer = Parallizer.new(Net::HTTP)
parallizer.add.get('www.google.com', '/search?q=foo')
parallizer.add.get('www.google.com', '/search?q=bar')

call_results = parallizer.all_call_results
# {
#   [:get, 'www.google.com', '/search?q=foo'] => ...,
#   [:get, 'www.google.com', '/search?q=foo'] => ...
# }
```


# Credits

[Parallizer](https://github.com/michaelgpearce/parallizer) is maintained by [Michael Pearce](http://github.com/michaelgpearce) and is funded by [Rafter](http://www.rafter.com "Rafter").

![Rafter Logo](http://rafter-logos.s3.amazonaws.com/rafter_github_logo.png "Rafter")

# Copyright

Copyright (c) 2012 Michael Pearce, Rafter.com. See LICENSE.txt for further details.

