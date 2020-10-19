# webbrowser

Ruby wrapper around http library.

I keep reinventing this code, and have included it lots of different repositories over the years. Time to tidy it up, and make it a separate repo. 

## Usage
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



