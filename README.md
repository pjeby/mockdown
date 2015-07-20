# mocha + markdown = mockdown

> Note: as of the 0.0.x releases, mockdown only supports exact output matching, and examples written in plain Javascript.  Other-language handling, ellipsis matching, and more docs are coming soon!

What better place to specify your code's behavior than in its API documentation?  And how better to document your API than with examples?  But if they're not tested, examples tend to get stale and out-of-date.  And testing them by hand is a pain.

But what if you could *automatically* test your examples, as part of your project's existing mocha test suites?  For that matter, what if you could do *documentation-first testing*, by writing the API docs for the API you're creating, and use the examples in them to drive your initial development?

Mockdown lets you do all of these things, and more, by testing code samples embedded in markdown files, like this:

```javascript
// "Hello world" Sample

console.log("Hello world!")
```
>     Hello world!

The above is a *documentation test*, or "doctest".  You embed a code block to be run, optionally followed by a blockquoted code block representing its output.  (If you don't include the output block, it's the same as asserting the example outputs nothing.)

If the output doesn't match, or an unexpected error is thrown, the test fails.  If your test completes asynchronously, you can use `wait()` to defer the test's completion until a callback, promise resolution, or other asynchronous result occurs:

<!-- mockdown: --printResults -->

```javascript
// Using wait() with setTimeout()

var done = wait();  // wait() with no arguments returns a callback... but we
                    // could have given it a promise, predicate, or timeout
                    // to wait for instead

setTimeout(function(){
  console.log("Hello world!");
  done();
}, 50);
```
>     Hello world!

Section headings in your markdown files define mocha suites, so your test suites will precisely match the table of contents of your documentation files.  If you need to do things like mark tests to be skipped or ignored, you can add simple HTML comment directives like this:

<!-- mockdown: ++ignore -->
    <!-- mockdown: ++skip -->

in order to mark a test pending, override the language defaults, change how output is checked, etc.

And since these directives are HTML comments, they don't show up when viewing the docs on github, or in any HTML docs you're generating for your website.  (Which means your readers won't get distracted by stuff that only matters to your testing process.)

Mockdown was inspired and influenced both by Python's [`doctest`](https://docs.python.org/2/library/doctest.html#simple-usage-checking-examples-in-a-text-file) module and Ian Bicking's [DoctestJS](http://doctestjs.org/), but is a new implementation specifically created to work with mocha and markdown.  Unlike DoctestJS, it:

* Works with markdown on the server instead of HTML in the browser
* Uses standard Node console inspection utilities instead of rolling its own pretty-print facilities, and
* Supports other languages besides plain Javascript -- including the use of multiple languages in the same document
* Uses mocha for test running and reporting, allowing integration into existing test suites

#### Contents

<!-- toc -->

## Usage

To include documentation files in your test suites, just pass a list of filenames, the mocha suite and test functions, and an optional options object to `mockdown.testFiles()`:

<!-- mockdown: ++skip -->

```js
var mockdown = require('mockdown');

mockdown.testFiles(['README.md'], describe, it, {
  printResults: false  
})
```

If you call this from a top-level module, the added test suites will be at the top level;  if you call it from inside a suite or `describe()` block, the suites will be nested within that block.

## Writing Tests

For the most part, tests are free-form.  Just insert code blocks, optionally followed by blockquoted code blocks to specify expected output.  Markdown section headings delineate mocha suites, with the heading levels being used to determine the nesting structure, and the section titles used to name the suites.

### Titling

Tests can optionally be preceded by a bulleted title, like this:

* This will show up as the mocha test title

```javascript
{ /* We're not testing anything here except the test title! */ }
```

Or, if your code sample's first line begins with a line comment (`//`, `#`, `--`, or `%`, depending on your language, it'll be used as the test's title, e.g.:

```javascript
// This will also show up as a test title

{ /* and we're still not really testing anything! */ }
```

Or, if you have only one code sample within a suite, the suite will be replaced with the single test, and get its title from the markdown section heading.

Or, if all else fails, the sample will end up with a title of "Example N", where N is its sequence number within the current suite.

### Output Matching

Code samples are run in a virtual environment with a simulated console, using the [`mock-globals`](https://npmjs.com/package/mock-globals) library.  Anything that a code sample outputs via `console.log`, `console.dir`, etc. will be sent to the output record, which is then compared against the expected output at the end of the test run.

If the output doesn't match the expected output, the test will fail with a detailed error message showing the actual and expected output (unless you suppress it by changing the relevant options.)

By default, the last value evaluated in a code sample is printed, in much the same way as the Node REPL, with `undefined` results remaining silent.  You can change this behavior, however, using the `printResults` and `ignoreUndefined` options. (Either by passing different values to the API, or by using directives.  See the Options Reference and the sections below on directives for more details.)

### Error Handling

You can include error output in your samples.  Only the message itself will be printed to the virtual console, unless you have a non-zero `stackDepth` option set (via the API or an in-document directive).

```javascript
throw new Error("this is the message")
```
>     Error: this is the message

### Asynchronous Tests

If your code sample completes asynchronously, you need to use the `wait()` function to defer the test's output matching until your code is finished running.

When called without any arguments, `wait()` returns a node-style callback that can be invoked to finish the test.  If you call it with an error, the error will be written to the virtual console for output matching purposes.  So if the error is expected, the test will still succeed.

If you are working with promises instead, you can call `wait(aPromise)` to make the test wait for the promise to finish.  As with the callback scenario, a promise rejection is treated as an error that gets written to the virtual console for output matching purposes.

If you have neither a callback-taking function or a promise, you can still use `wait(timeout)` to wait the specified number of milliseconds, `wait(aFunction)` to call `aFunction()` every millisecond until it returns true, or `wait(interval, aFunction)` to do the same thing with a specified number of milliseconds between checks.

(By the way, if you need `wait()` to have a different name because you need to use the name `wait` for something else in your examples, you can rename it by changing the `waitName` option in a directive, or in the options you supply to the mockdown API.  See the "Options Reference" and the section on using directives for more details.)

### Controlling Test Behavior with Directives

There are three types of directives you can use to control the behavior of your tests:

* `<!-- mockdown: `*options*` -->` lets you change options for the *next* code sample, after which they will revert to the way they were before

* `<!-- mockdown-set: `*options*` -->` lets you change options *from this point on*; the changed options will be the default until changed by another directive

* `<!-- mockdown-setup: `*options*` -->` can be used, *once*, near the top of the document, before any other directives or code samples.  In addition to letting you do anything you can do with a `mockdown-set` directive, you can also use it to set up global variables that will be available to your examples.  (For example, you can `require()` things here, or even include short utility functions.)

In all three cases, the *options* consist of JavaScript code.  The code can assign options by name, e.g. `stackDepth = 3` or `printResults = false`.  As a shorthand for boolean options, you can also increment or decrement them to make them true or false.  For example, `<!-- mockdown: ++skip -->` will mark the next code sample as pending in mocha.  (Note: it doesn't matter how many times you increment or decrement, the option will always reset to `true` when you increment it, and `false` when you decrement it.)

mockdown has a *lot* of options you can manipulate with these directives.  Check out the "Options Reference" near the end of this document for the complete list.


## Options Reference

### Options for Variables Used in Examples

* `globals` - an object containing the variables to be made available to all examples.  Can only be configured via the options passed into mockdown's APIs, or via a `mockdown-setup` directive at the top of a file.  Default: an empty object.

* `waitName` - the name the `wait()` function is made available under.  You can change this in order to avoid conflict with a name in your examples.  If undefined, the `wait()` function will not be accessible from the example.  String or undefined, default: `"wait"`.

* `testName` - the name the current mocha `test` object will be made available under, so you can e.g. change the test timeout.  If undefined, the test object will not be accessible from the example.  String or undefined, default: `"test"`.

### Options for Test Control Flow

* `skip` - mark the test(s) pending in Mocha.  Boolean, default: `false`.

* `ignore` - do not turn markdown code blocks into examples.  Can be used with a `mockdown` directive to "comment out" a single test, or a pair of `mockdown-set` directives to comment out a group of tests.   Boolean, default: `false`.

### Options for Error Formatting

* `showOutput` - when a test fails due to unmatched output, show the full expected and received output.  Boolean, default: `true`.

* `showDiff` - when a test fails due to unmatched output, tell mocha to diff the output.  Boolean, default: `false`.

* `stackDepth` - when a test throws an unhandled exception, how many lines of stack trace should be included in the output?  (This lets you add more lines temporarily for debugging, or permanently if the contents of the stack trace are what your example is testing.)  Must be an integer; can be set from 0 to `Infinity`.  Default: `0`.

### Options for Output and Result Matching

* `printResults`
* `ignoreUndefined`
* `writer`

## Open Issues/TODO

* Multi-language support isn't done yet
* No API docs except nearly 2000 lines of very verbose tests
* Since it hasn't really been used yet, there are probably lots of syntax corner cases that haven't been encountered yet
* Ellipsis and whitespace options for output matching aren't implemented
* When an error match fails, we should probably output the original error as well as expected/actual output, instead of falling back to the original error; right now it's too hard to figure out what's wrong when a test that has an expected error is broken
