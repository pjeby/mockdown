# mocha + markdown = mockdown

> **New** or changed in 0.4.0:
> 
> * The [`showCompiled` option](#showcompiled) lets you show compiled code in error messages
> * Code output in error messages now includes source line numbers
> * You can specify what `module` to use for the various [language engines](#languages)
> * The [`printResults` option](#printresults) now defaults to `false`, as it tends to produce unwanted output in typical usage.

What better place to specify your code's behavior than in its API documentation?  And how better to document your API than with examples?  But if they're not tested, examples tend to get stale and out-of-date.  And testing them by hand is a pain.

But what if you could *automatically* test your examples, as part of your project's existing mocha test suites?  For that matter, what if you could do *documentation-first testing*, by writing the API docs for the API you're creating, and using the examples in them as tests to drive your initial development?

Mockdown lets you do all of these things, and more, by testing code samples embedded in markdown files, like this:

```js
// "Hello world" Sample

console.log("Hello world!")
```
>     Hello world!

The above is a *documentation test*, or "doctest".  You embed a code block to be run, optionally followed by a blockquoted code block representing its output.  (If you don't include the output block, it's the same as asserting the example will output nothing.)

If the output doesn't match, or an unexpected error is thrown, the test fails.  If your test completes asynchronously, you can use `wait()` to defer the test's completion until a callback, promise resolution, or other asynchronous result occurs:

```js
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

```markdown
<!-- mockdown: ++skip -->
```

in order to mark a test pending, override the language defaults, change how output is checked, etc.

And since these directives are HTML comments, they don't show up when viewing the docs on github, or in any HTML docs you're generating for your website.  (Which means your readers won't get distracted by stuff that only matters to your testing process.)

Mockdown was inspired and influenced both by Python's [`doctest`](https://docs.python.org/2/library/doctest.html#simple-usage-checking-examples-in-a-text-file) module and Ian Bicking's [DoctestJS](http://doctestjs.org/), but is a new implementation specifically created to work with mocha and markdown.  Unlike DoctestJS, it:

* Works with markdown on the server instead of HTML in the browser
* Uses standard Node console inspection utilities instead of rolling its own pretty-print facilities, and
* Supports other languages besides plain Javascript -- including the use of multiple languages in the same document (Babel and CoffeeScript out of the box, but you can supply your own engine(s) via the options)
* Uses mocha for test running and reporting, allowing integration into existing test suites

#### Contents

<!-- toc -->

* [Writing Your Tests](#writing-your-tests)
  * [Mocha Test Titles](#mocha-test-titles)
  * [Output Matching](#output-matching)
  * [Error Output](#error-output)
  * [Asynchronous Tests](#asynchronous-tests)
  * [Controlling Test Execution with Directives](#controlling-test-execution-with-directives)
* [Configuring Your Tests](#configuring-your-tests)
  * [Making Variables Available in Examples](#making-variables-available-in-examples)
  * [Controlling Whether Tests are Included or Run](#controlling-whether-tests-are-included-or-run)
  * [Controlling the Formatting of Errors](#controlling-the-formatting-of-errors)
  * [Controlling Test Output and Expected Result Matching](#controlling-test-output-and-expected-result-matching)
  * [Language Options](#language-options)
  * [Other Options](#other-options)
* [Running Your Tests](#running-your-tests)
  * [The `mockdown.testFiles()` API](#the-mockdowntestfiles-api)
  * [Controlling How/When Tests Are Added](#controlling-howwhen-tests-are-added)
  * [Using Languages Besides Javascript](#using-languages-besides-javascript)
* [Changelog](#changelog)
* [Open Issues/TODO](#open-issuestodo)

<!-- toc stop -->


## Writing Your Tests

For the most part, tests are free-form.  Just insert code blocks, optionally followed by blockquoted code blocks (`> `-prefaced) to specify expected output.  Markdown section headings delineate mocha suites, with the heading levels being used to determine the nesting structure, and the section titles used to name the suites.

By default, code is assumed to be plain Javascript that can be executed by the engine mockdown is running on, unless you use a fenced code block with an explicit language declaration.  (You can change this default, add language engines, etc. using directives and options, which are discussed in later sections below.)  

Both the sample code and the expected output can be either Github-style "fenced" code blocks or traditional 4-space indented code blocks.  Remember, however, that blockquotes require a space after the `>`, so if you are using indented code blocks for expected output, you will need **5** spaces between the `>` and the beginning of expected output.  That is:

```markdown
>    this is not an expected output block!
```
```markdown
>     but this is!    
```

If you don't include all five spaces, the markdown parser will see the blockquote as regular text, so mockdown won't see it as an expected-output block, and your test will fail, despite it looking okay to the naked eye.

### Mocha Test Titles

If your code sample's first non-blank line begins with a line comment (`//`, `#`, `--`, or `%`, depending on your language), it'll be used as the test's title, e.g.:

```js
// This will show up as the mocha test title

{ /* We're not testing anything here except the test title */ }
```

Or, if the code sample doesn't start with a line comment, but it's the only code sample within a given suite, it'll replace the suite and assume its title.  (In other words, if you have only one code sample and no subheadings under a given markdown heading, then the test will get its title from the heading.)

If there's more than one code sample under a given heading, or if there are subheadings under that heading, then any otherwise-untitled tests will be titled "Example N at line M", where N is its sequence number within its suite, and M is the line number of its first code line.

### Output Matching

Code samples are run in a virtual environment with a simulated console, using the [`mock-globals`](https://npmjs.com/package/mock-globals) module.  Anything that a code sample outputs via `console.log`, `console.error`, etc. will be sent to the console's output record, which is then compared against the expected output at the end of each code sample's execution.

If the output doesn't match the expected output, the corresponding test will fail with a detailed error message showing the actual and expected output (unless you suppress it by changing the relevant options.)

By default, the last value evaluated in a code sample is printed, in much the same way as the Node REPL, with `undefined` results remaining silent.  You can change this behavior, however, using the `printResults` and `ignoreUndefined` options. (Either by passing different `options` to the API, or by using directives, as will be described in later sections below.)

(Note: `mock-globals` is **not** a secure execution environment.  Do not use `mockdown` to process files from untrusted sources, or you will be *very* sorry!)
 

### Error Output

You can include error output in your samples, if the purpose of the example is to show an error.  Only the error message itself will be printed to the virtual console, unless you have a non-zero `stackDepth` option set (via the API or an in-document directive).

So, the following example throws an error, but since an error is the *intended* result, the **test** will be still considered successful: 

```js
throw new Error("this is the message")
```
>     Error: this is the message

If the error name or message had differed, the test would fail instead, and the error stack shown by mocha would be the stack from the first error issued by the code sample. 

### Asynchronous Tests

If your code sample completes asynchronously, you need to use the `wait()` function to defer the test's output matching until your code is finished running.

When called without any arguments, `wait()` returns a node-style callback that can be invoked to finish the test.  If you call it with an error, the error will be written to the virtual console for output matching purposes.  So if the error is expected, the test will still succeed.

If you are working with promises instead, you can call `wait(aPromise)` to make the test wait for the promise to finish.  As with the callback scenario, a promise rejection is treated as an error that gets written to the virtual console for output matching purposes.

If you have neither a callback-taking function or a promise, you can still use `wait(timeout)` to wait the specified number of milliseconds, `wait(aFunction)` to call `aFunction()` every millisecond until it returns true, or `wait(interval, aFunction)` to do the same thing with a specified number of milliseconds between checks.

(By the way, if you need `wait()` to have a different name because you need to use the name `wait` for something else in your examples, you can rename it by changing the `waitName` option in a directive, or in the options you supply to the mockdown API.  See the sections below for more details.)

For some documentation, including an explicit `wait()` call may be intrusive; for these situations, you can use the `waitForOutput` option in a directive.  For example, the following test is configured to wait for the string `"done"` to appear in the output, using the directive `<!-- mockdown: waitForOutput = "done" -->`:

<!-- mockdown: waitForOutput = "done"; --printResults -->

```js
setTimeout(function(){ console.log("done"); }, 10);
```
>     done

(The main downside to this approach is that if the desired string never appears in the output, the test will time out before any output comparison is done.)

For more on how to use directives to configure options, see the next few sections.


### Controlling Test Execution with Directives

Sometimes, you need to have mocha skip a test and mark it pending.  Other times, you may have code blocks in your documentation that you don't want to treat as tests at all!  You can use **directives** to control these things, as well as to set other options like `waitName` or `printResults`.   A directive is a special kind of HTML comment, set off by blank lines before and after it.  For example, to skip a single test and mark it pending, you can use:

<!--mockdown-set: ++ignore -->

```markdown
<!-- mockdown: ++skip -->
```

Or to treat the next code block as a non-test code block, you can use:

```markdown
<!-- mockdown: ++ignore -->
```

If you want to mark *multiple* tests to skip or code blocks to ignore, you can bracket them with a pair of `mockdown-set` directives, like so:

```markdown
<!-- mockdown-set: ++skip -->

Tests between these directives will be marked
"pending" in mocha!

<!-- mockdown-set: --skip -->
```

The main difference between a `mockdown` directive and a `mockdown-set` one is that `mockdown` only affects the *next* code block encountered, while `mockdown-set` changes the current *default* options for the document.

So, anything you set with `mockdown-set` will *stay* set, until you change it with another `mockdown-set` -- even if it's temporarily overridden for one test with a `mockdown` directive.  (This makes it easy to change an option for just one test, because you don't have to remember to change things *back* afterwards: just use a `mockdown` directive for anything that should apply to just one test.)

(One other important difference between `mockdown` and `mockdown-set` directives is that `mockdown` directives must appear *immediately* before the code blocks they affect, without any other text or non-`mockdown` directives in between.  Otherwise, parsing of the document will fail with a `SyntaxError`, to avoid any ambiguity as to the intended effects.)

##### Setting Options With Directives

Directives aren't limited to toggling boolean flags like `skip` and `ignore`.  You can also set non-boolean options values (e.g. `<!-- mockdown: stackDepth = 3 -->`) and even combine multiple option changes in a single directive, e.g.:

```markdown
<!-- mockdown: stackDepth=3; waitName="defer"; ++showDiff -->
```

If this looks a lot like Javascript code, that's because it is!  Directive bodies are actually code that runs in a separate `mock-globals` environment, where global variables are tied directly to the options for the next code block (in a `mockdown` directive), or the document defaults (in a `mockdown-set` directive).

When used with a boolean option, the `++` and `--` operators are shorthand for setting the option to `true` or `false`, respectively.  This happens even if you use them repeatedly, so you don't need to keep track of how many times you incremented or decremented them: `++` *always* turns the option on, and `--` *always* turns it off.

Although directives are Javascript code, it's important to understand that this code runs while your markdown document is being *parsed*, not while the tests are running.  So they can only *configure* tests, not intervene in their execution.

For this reason, there is also a third type of directive: `mockdown-setup`.  You can use this directive at most once in a given markdown file, and only *before* any other directives or code blocks appear in the file.  Within this directive, your Javascript code can set or change the `globals` and `languages` that will be used by your tests.  It is in all other respects identical to a `mockdown-set` directive (i.e., you can use it to set other defaults for the file).

There are a great many options you can set or change via directives or the mockdown API; the next section lists them all.

<!--mockdown-set: --ignore -->


## Configuring Your Tests

All of the options described in this section can be set or changed within a markdown document using directives (as described in the previous section).  They can also be passed in as options to `mockdown.testFiles()` and other mockdown APIs (as described in the section on "Running Your Tests", below).

### Making Variables Available in Examples

##### `globals`

Object, default: `{}`.

An object containing the pseudo-global variables that will initialize the `mock-globals` Environment where the code samples will execute.  Can only be configured via the options passed into mockdown's APIs, or via a `mockdown-setup` directive at the top of a file.  (That is, unlike other options, it can't be set via `mockdown` or `mockdown-set` directives.)  

##### `waitName` 

String or null/undefined, default: `"wait"`

The name the `wait()` function is made available under.  You can change this in order to avoid conflict with a name in your examples.  If this option is set to null or undefined, the `wait()` function will not be accessible from the example.

##### `testName` 

String or null/undefined, default: `"test"`

The name the current mocha `test` object will be made available under, so you can e.g. change the test timeout.  If this option is set to null or undefined, the test object will not be accessible from the example.

### Controlling Whether Tests are Included or Run

##### `skip`

Boolean, default: `false`

If true, mark the applicable test(s) pending in Mocha.

##### `ignore`

Boolean, default: `false`

If true, do not turn markdown code blocks into examples until it becomes false again.  Can be used with a `mockdown` directive to "comment out" a single test, or a pair of `mockdown-set` directives to comment out a group of tests.

### Controlling the Formatting of Errors

##### `showOutput`

Boolean, default: `true`

When a test fails due to unmatched output, show the full expected and received output, along with the source code of the test.

##### `showCompiled`

Boolean, default: `false`  (New in version 0.4.0)

When a test fails, show the *compiled* code in the error output, instead of the original source.  (Has no effect if `showOutput` is false.)  This can be useful for debugging a broken test case or example written in a compile-to-JS language.

##### `showDiff`

Boolean, default: `false`

When a test fails due to unmatched output, tell mocha to diff the output.  

##### `stackDepth`

Integer from 0 to `Infinity` (i.e., unlimited stack depth).  Default: `0`.

When a test throws an unhandled exception, how many lines of stack trace should be included in the output?  (This lets you add more lines temporarily for debugging, or permanently if the contents of the stack trace are what your example is testing.) 


### Controlling Test Output and Expected Result Matching

##### `waitForOutput`

Optional function, string, or regular expression predicate; default `undefined`

If set, the test is considered asynchronous (as if `wait()` were explicitly called), and each string written to the virtual console will be checked using the supplied function, string, or regular expression.  If there is a match, the test will end on the next process tick, without needing to explicitly call a `done()` function.

A function predicate is considered to match if it returns a truthy value for a given output string, and a string predicate is considered to match if it is found at any point within the output string.  Regular expression predicates are matched with `.match()` on the output string.

If a matching string is never written, the test will time out, and then the output up to that point will be compared with the expected output.

##### `printResults`

Boolean, default: `false`.  (CHANGED in 0.4.0)

If true, the virtual environment acts like the node REPL, printing the value of the last expression in a code sample.

For example, the following test requires `printResults` to be true:

<!--mockdown: ++printResults -->

```js
6 * 7
```

>     42


##### `ignoreUndefined`

Boolean, default: `true`.

If true, don't print an `undefined` result.  This only has any effect if `printResults` is true. 

##### `writer`

Function or undefined, default: `undefined`

The function used to convert a REPL result to a string suitable for writing.  Only has effect if `printResults` is true.  If `writer` is `undefined`, then the Node `repl` module's current `writer` property will be used (which by default is a slightly modified version of `util.inspect()`).

### Language Options

##### `defaultLanguage`

String, default `"javascript"`

The name of the language that should be used when a code block doesn't have an explicit language.  That is, the language to be used for indented code blocks, and fenced blocks without a specified language.  You can also set this to `"ignore"` to ignore such code blocks and not create tests for them.

Language names are case-insensitive, at least in the sense that they are converted `toLowerCase()` before being looked up in the `languages` mapping.  

##### `languages`

Object, default: `require('mockdown/languages')()`

An object whose keys are all-lowercase language names, and whose values are language aliases or language engines.  A language alias is just a string that names the engine to be used, so for example if you set `languages.es7 = "babel"`, this would tell mockdown to use Babel to compile code blocks with a language of `es7`.

(Note: aliases are not recursive; they must name a language engine, not another alias.  They can, however, be set to `"ignore"`, which indicates blocks of that language should be ignored and not used as tests.)

A language engine is an object with one required property, `toJS:`, which must be a function accepting a `mockdown.Example` object and a starting line number, and returning a string of Javascript.  Usually, language engines will also include an `options:` property that will be used to send compiler options to the underlying language.  (For example, you can set `languages.babel.options.stage` to change the stability level used for Babel examples.)

Note that the `languages` option can only be configured via the options passed into mockdown's APIs, or via a `mockdown-setup` directive at the top of a file.  (That is, like `globals`, it can't be set via `mockdown` or `mockdown-set` directives.)

Currently, the default mapping for this option includes language engines for:

* `babel` (with `es6` as an alias)
* `coffee` (with `coffee-script` and `coffeescript` as aliases)
* `javascript` (with `js` as an alias)

And it includes `html`, `markdown`, and `text` as aliases for `ignore`.

You can add your own aliases and engines to this mapping by in-place modification in `mockdown-setup` code, or by passing a replacement object as a `languages:` option to the API.  (You can also call `require('mockdown/languages')()` to get a copy of the defaults that you can then modify and pass in.)

Both the `babel` and `coffee-script` language engines have a `module` property that can be used to determine what module to load to do the compiling.  `languages.babel.module` defaults to `"babel-core"`, and `languages.coffee.module` defaults to `"coffee-script"`, but you can override them if you need to.


### Other Options

##### `filename`

The filename that will appear in stack traces for errors thrown by code or directives within the file.  Like `globals` and `languages`, it can't be changed on the fly, but only initialized by passing options to the API or in a `mockdown-setup` directive.  If you don't explicitly provide it to the API, and mockdown loads the file for you, it will be set to the filename it was asked to load.  String, defaults to `"<anonymous>"` if the document was parsed from a string instead of a file.


## Running Your Tests

### The `mockdown.testFiles()` API

To include documentation files in your test suites, just pass a list of filenames, the mocha suite/describe and test/it functions, and an optional options object to `mockdown.testFiles()`, like this:

<!-- mockdown: ++skip -->

```js
var mockdown = require('mockdown');

mockdown.testFiles(['README.md'], describe, it, {

  printResults: false,  // disable REPL mode
  
  globals: {  

    // supply some global vars for your code samples
      
    someUsefulFunction: function () {
      // your examples will now be able to call
      // `someUsefulFunction()` without needing
      // to `require()` it
      return "I'm useful!";
    },

    // you can mock or stub any global names, too!
    
    require: function(path) {
        if (path === 'mymodule') return require('./');
        else return require(path);
    }
  }

})
```

As you can see above, the `options` argument not only lets you set any mockdown options or globals, it also lets you access *non-virtualized* code.  If you configure your globals from inside a `mockdown-setup` directive, you only have access to the virtual environment where directives run.  But when you configure them via the API, you can use functions that have access to e.g. the "real" `require()` function.


### Controlling How/When Tests Are Added

If you call `mockdown.testFiles()` from the top-level code of a module, the added test suites will be at the top level of your overall test set.  If you call it from inside a suite or `describe()` block, the suites will be nested within that block.

Alternately, if you want more explicit control over the process, you can:

1. Create a parser object using `parser = new mockdown.Parser(options)`
2. Get a `mockdown.Document` using `doc = parser.parse(text)` or `doc = parser.parseFile(path)`, and
3. Register tests and suites with mocha by calling `doc.register(suiteFn, testFn)` with `describe` and `it` or their equivalents in the mocha interface you're using.

   The `.register()` method can optionally be given a mock-globals `Environment` object as a third parameter, in which case it will be used instead of creating a new one.  (But in that event, the `options.globals` won't be used; you'll have to configure the `Environment` instance yourself.)

If you're parsing strings, you'll probably want to include a `filename:` entry in the options you give the parser, so that error messages will include the right filename.  And for a complete list of *all* the options you can use with any of mockdown's APIs, see the section on "[Configuring Your Tests](#configuring-your-tests)", above.

### Using Languages Besides Javascript

Currently, multi-language support is still experimental.  Most JS transpilers expect to be producing an entire module at a time, rather than a collection of code fragments to be run REPL-style.  So although it "works", you may run into language-specific compilation issues, and may need to use the `showCompiled` option to display compiled source in error messages so you can see what's really going on.

(Also, note that although mockdown includes engines for Babel and CoffeeScript, it does not declare dependencies on them, as by design it should use *your* installation of the relevant compiler modules.  That way, it will always be in sync with your project's version of the associated compiler.) 

## Changelog

##### New in 0.3.0

* The [`waitForOutput`](#waitforoutput) option lets you match console output to end an asynchronous test, without needing to call `wait()` in the test itself.  See the section above on [asynchronous tests](#asynchronous-tests) for an example.

## Open Issues/TODO

* Multi-language support is still experimental, and there aren't any docs yet on how to create an engine correctly.
* No API docs except nearly 2000 lines of very verbose tests
* Since it hasn't really been used yet, there are probably lots of syntax corner cases that haven't been encountered yet
* Ellipsis and whitespace options for output matching aren't implemented
