# Rack::Test::HarRecorder

This gem makes it easy to record requests and responses from your test suite as HTTP Archives (aka HAR files). These are JSON files with a specific schema suitable for describing the interchange between a web service and a user agent. One prominent place HAR files are used is in modern web browsers. While debugging a web application, you can open the development console of your web browser and save a copy of your browser's interaction with the server as a HAR file. Your test suite simulates similar client-server interactions and this gem lets your capture that activity.


## Documentation as Testing

When you publish an API for your application, you'll want to provide documentation. The best documentation includes examples. Sometimes it's easy to write out examples by hand. However, as you change your application you might mistakenly edit those examples. If you capture the examples from your test suite, then those examples can't go out of date. However, as you change the application, how do you know that those specification files are still accurate (or, in other words, that your application conforms to it's documentation)? One way is to compare the examples captured from your test suite against the examples included in the documentation. If they don't match then either the documentation needs to be updated or the application needs to be fixed.

You might eschew human-oriented documentation in favor of publishing JSON schema or RAML files. This is common for internal APIs where the providers and consumers of the API have a solid shared understanding of what the API is providing. It's tempting to think of your API as well documented in this case. However, this situation isn't fundamentally different from the previous situation.


## Debugging

Sometimes your tests will fail. The failure messages won't always describe the problem perfectly. If you're using CI infrastructure, sometimes those failures will occur while running on the CI server. You won't be able to set a breakpoint or edit the test in that case. However, if you capture the requests and responses to HAR files, then you can configure your CI server to leave those HAR files behind. That allows you to peek behind the curtain, in order to get more detail about what happened during the test run.


## Current Assumptions

Currently the gem assumes you're using `rspec`. Feel free to contribute patches to make it more flexible.

This was initially extracted from the test suite of a Rails application. We use it in some non-Rails applications. However, there's likely some hidden assumptions that `ActionDispatch` is loaded. Feel free to submit patches to decouple that.

