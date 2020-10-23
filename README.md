# webbrowser

Docs :: http://wikarekare.github.com/wikk_webbrowser/
Source :: https://github.com/wikarekare/wikk_webbrowser
Gem :: https://rubygems.org/gems/wikk_webbrowser

## DESCRIPTION:

Wrapper around ruby http and https libraries.

Converted to a gem from a mixture of versions I've used over the years. Might need some work yet :)

## FEATURES/PROBLEMS:

* session block
* get, post, put, delete

## SYNOPSIS:

call with WebBrowser.http_session() or https_session().
e.g.
```
      WebBrowser.https_session( host: @hostname, verify_cert: false ) do |ws|
        result = ws.get_page( query: "#{api_query}",
                              authorization: "token #{@auth_token}",
                              form_values: {
                                  "page_size"=>page_size, 
                                  "page"=>page,
                                }.merge(args)
                            )
      end
```

If the server supports keeping the connection open, then the block can have multiple calls per session.

## REQUIREMENTS:

## INSTALL:

* sudo gem install wikk_webbrowser

## LICENSE:

(The MIT License)

Copyright (c) 2020 FIX

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

