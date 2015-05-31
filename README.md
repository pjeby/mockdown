# mocha + markdown = mockdown

What better place to specify your code's behavior than in its API documentation?  And how better to document your API than with examples?

But examples get stale and out-of-date, if they're not tested.  And testing them is a pain.

But what if you could *automatically* test them, as part of your existing mocha test suites?  For that matter, what if you could do *documentation-first testing*, by writing the API docs for the API you're creating, and use the examples in them to drive your initial development?

Mockdown lets you do all of these things, and more, by testing code samples embedded in markdown files, like this one:

```javascript
console.log("Hello world!")
```
>     Hello world!

The above is a *documentation test*, or "doctest".  You embed a code block to be run, optionally followed by a blockquoted code block representing its output.  If the output doesn't match, or an unexpected error is thrown, the test fails.  If your test completes asynchronously, you can use `wait()` to defer the test's completion until a callback, promise resolution, or other asynchronous result occurs:

```javascript
var done = wait();  // we could also pass in a promise, predicate, or timeout

setTimeout(function(){
  console.log("Hello world!"); done();
}, 50);
```
>     Hello world!


Section headings in your markdown files define mocha suites, so your test output is literally the table of contents from your documentation files.  If you need to do things like mark tests to be skipped or ignored, you can add simple HTML comment directives like this:

<!-- mockdown: +ignore -->
    <!-- mockdown: +skip -->

in order to mark a test pending, override the language defaults, change how output is checked, etc.

And since these directives are HTML comments, they don't show up when viewing the docs on github, or in any HTML docs you're generating for your website.  (Which means your readers won't get distracted by stuff that only matters to your testing process.)


## Usage

To include documentation files in your test suites, just pass a list of filenames and an options object to `mockdown.testFiles()`:

```js
var mockdown = require('mockdown');

mockdown.testFiles(['README.md'], {
  languages: ['javascript'],  
  suite: describe,
  test: it
})
```

If you call this from a top-level module, the added test suites will be at the top level;  if you call it from inside a suite or `describe()` block, the suites will be nested within that block.

### Language Options
### Output Matching Options

## Writing Tests

### Syntax,  Organization and Titles
* Language specs
* Titles (list, section, "Example", comment)

### Output Matching

* Creating output with console.log/dir
* Ellipsis matching
* Whitespace issues

### Asynchronous Completion

### Error Handling
* Error output


### Directives

* Parse caveats (standalone directives only, before tests only, etc.)
* Pending tests
* Ignoring tests
* Setting language
* Matching options
