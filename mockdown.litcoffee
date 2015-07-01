# Literate Testing with Mockdown

    mockdown = exports

### Utility Functions

#### `assign()`

The `assign()` function is roughly equivalent to an `Object.assign()` polyfill,
except that it uses `Object.defineProperty()` to ensure that e.g. an inherited
descriptor on the target can't veto an assignment.  (As can happen when
assigning to an object that inherits from the global context, as with the
`.context` property of a `mockdown.Environment`.)

    assign = (target={}) ->
        to = Object(target)
        writable = configurable = enumerable = yes
        for arg, i in arguments when i and arg?     # skip first and empties
            arg = Object(arg)
            for k in Object.keys(arg)
                Object.defineProperty(to, k, {
                    value: arg[k], writable, configurable, enumerable
                })
        return to


#### `isPlainObject()`

This function just detects whether a value is a "plain" Object -- that is, if
its prototype is `Object.prototype`.  It's mainly used to validate options.

    isPlainObject = (ob) ->
        ob? and typeof ob is "object" and
            Object.getPrototypeOf(ob) is Object.prototype







## Options

    OPTION_DEFAULTS = {

        ellipsis: '...'         # wildcard for output matching
        ignoreWhitespace: no    # normalize whitespace for output mathching?
        showOutput: yes         # output the result of evaluating each example
        showDiff: no            # use mocha's diffing for match errors
        stackDepth: 0           # max # of stack trace lines in error output

        skip: no                # mark the test pending?

        globals: {}             # global vars for examples
        waitName: 'wait'        # name of 'wait()' function
        testName: 'test'        # name for current mocha test object

        filename: '<anonymous>'
        line: undefined
        title: undefined
        code: undefined
        output: undefined
    }

    OPTION_NAMES = Object.keys(OPTION_DEFAULTS)

















    class mockdown.Options

        constructor: (opts={}, defaults=OPTION_DEFAULTS) ->
            unless arguments.length < 3
                throw new TypeError("Options() accepts two or fewer arguments")
            unless isPlainObject(opts) or opts instanceof @constructor
                throw new TypeError("opts must be a plain Object")
            unless defaults is OPTION_DEFAULTS or defaults instanceof @constructor
                throw new TypeError("Defaults must be an Options object")
            for key in Object.keys(opts)
                unless OPTION_DEFAULTS.hasOwnProperty(key)
                    throw new TypeError("Unknown option: "+key)
            unless this instanceof mockdown.Options
                return new mockdown.Options(opts, defaults)

            for key in OPTION_NAMES
                val = if key of opts then opts[key] else defaults[key]
                val = assign({}, val) if isPlainObject(val) # prevent sharing
                this[key] = val

        mismatch: (output) ->
            return if output is @output
            msg = ['']
            if @showOutput
                msg.push 'Code:'
                msg.push '    '+l for l in (@code ? '').split('\n')
                msg.push 'Expected:'
                msg.push '>     '+l for l in expected = @output.split('\n')
                msg.push 'Got:'
                msg.push '>     '+l for l in actual = output.split('\n')
            err = new Error(msg.join('\n'))
            err.name = 'Failed example'
            err.showDiff = @showDiff
            err.expected = expected
            err.actual = actual
            stack = err.stack.split('\n')
            stack.splice(msg.length, 0, "  at Example (#{@filename}:#{@line})")
            err.stack = stack.join('\n')
            return err


        offset: (code=@code, line=@line) -> Array(line).join('\n') + code

        evaluate: (env, params) ->
            if params
                for k in Object.keys(params) when name = this[k+"Name"]
                    env.context[name] = params[k]
            return env.run(@offset(), this)

        writeError: (env, err) ->
            msgLines = err.message.split('\n').length
            stack = err.stack.split('\n').slice(0, @stackDepth + msgLines)
            env.context.console.error(stack.join('\n'))





























## Containers

    class Container

        constructor: -> @children = []

        add: (child) ->
            @children.push child.onAdd(this)
            this

        registerChildren: (suiteFn, testFn, env) ->
            for child in @children then child.register(suiteFn, testFn, env)
            this

### Document Objects

    class mockdown.Document extends Container

        constructor: (opts) ->
            @opts = mockdown.Options(opts); super

        register: (suite, test, env = new mockdown.Environment @opts.globals) ->
            @registerChildren(suite, test, env)

### Section Objects

    class mockdown.Section extends Container

        constructor: (@title) -> super

        onAdd: (container) ->
            if @children.length==1 and
             (child = @children[0]) instanceof mockdown.Example
                child.title ?= @title
                child.onAdd(container)
            else
                this

        register: (suiteFn, testFn, env) -> suiteFn @title, =>
            @registerChildren(suiteFn, testFn, env)

## Running Examples

### Example Objects

    class mockdown.Example

        constructor: (opts) ->
            @opts = opts = mockdown.Options(opts)
            @title = opts?.title
            @code = opts?.code
            @line = opts?.line ? 1
            @output = opts?.output
            @seq = undefined

        onAdd: (container) ->
            @seq = container.children.length + 1
            this

        register: (suiteFn, testFn, env) ->
            if @opts.skip
                testFn @getTitle()
            else
                my = this
                testFn @getTitle(), (done) -> my.runTest(env, @runnable(), done)

        getTitle: ->
            return @title if @title?
            return m[2].trim() if m = @code?.match ///
                ^
                \s*
                (//|#|--|%)
                \s*
                ([^\n]+)
            ///
            if @seq then "Example "+@seq else "Example"






        runTest: (env, testObj, done) ->

            finished = no

            waiter = new mockdown.Waiter (err) =>
                if finished
                    done(err) if err
                else
                    finished = yes
                    @opts.writeError(env, err) if err
                    matchErr = @opts.mismatch(env.getOutput())

                    if not matchErr
                        done.call(null, undefined)
                    else if not err?
                        done.call(null, matchErr)
                    else
                        done.call(null, err)

            testObj.callback = waiter.done

            try
                @opts.evaluate(env, wait: waiter.wait, test: testObj)
                waiter.done() unless waiter.waiting
            catch e
                if waiter.waiting
                    @opts.writeError(env, e)
                else waiter.done(e)













### Environment Objects

An environment is like a stripped-down node REPL that runs code samples in
a private `.context` that retains its state and records its console output.
The context inherits from the Node global environment, and sees any changes
to globals that aren't shadowed by assignments in the code samples (or in the
initially-provided globals).

    class mockdown.Environment

        repl = require 'repl'
        Console = require('console').Console

        constructor: (globals={}) ->
            @outputStream = []
            @outputStream.write = @outputStream.push

            @context = ctx = Object.create(global)
            @addProps(
                console: new Console(@outputStream)
                global: ctx
                GLOBAL: ctx
                THIS: ctx       # Used for rewrites of top-level `this`
                module: @dummyModule()
                exports: {}
                require: require
            ).addProps(globals)

Properties are normally added via assignment, but some globals aren't writable;
we use defineProperty to redefine them.

        addProps: (props) ->
            assign(@context, props)
            return this







#### Supporting require() and module.exports in code samples

In order to allow `require()` to work in code samples by default, we use
roughly the same hack as the node `repl` module uses, and modify our module
lookup paths to be based on the current directory.  (So if you don't override
`require` in an environment's context, you'll get a require that works relative
to the current directory.)

For the exposed `module`, we use a clone of the mockdown module, with an
`exports` property that gets/sets the context `exports`, so that code samples
can run in an environment that closely resembles a standard module.

        dummyModule: ->
            return Object.create(module, exports: {
                get: => @context.exports
                set: (v) => @context.exports = v
                enumerable: yes
            })























#### Code Rewriting

Before they can be run, code samples are wrapped in a `with(MOCKDOWN_GLOBAL)`
block, so that variables are read and written from the Environment's `.context`
instead of from the process globals.  In order for this to work, the context
must have properties for every global variable assignment or function
declaration in the code sample, and function declarations must be converted to
variable assignments.  (Otherwise, they'll write directly to global context.)

So, we use the `recast` module to scan the code and track what global variables
are assigned to, along with the location of any function declarations.  The
`globals` we use for tracking inherits from the `.context`, so that we don't
add dummy globals for already-existing context or global variables.

        recast = require 'recast'

        rewrite: (src) ->

            globals = Object.create(@context)
            funcs = []

            recast.visit recast.parse(src),
                visitAssignmentExpression: vae = (p) ->
                    @traverse(p)
                    target = p.node.left
                    return unless target.type is 'Identifier'
                    name = target.name
                    return if name of globals
                    s = p.scope.lookup(target.name)
                    if not s? or s.isGlobal
                        globals[name] = undefined
                    return
                visitForInStatement: vae

                visitFunctionDeclaration: (p) ->
                    name = p.node.id.name
                    funcs.push [name, p.node.loc.start]
                    globals[name] = undefined unless name of globals
                    @traverse(p)
                    return

In addition to variables and functions, it's also possible to refer to the
global context as `this`, so we replace global-scope `this` with `THIS`, which
avoids changing any code positions, but will now refer to the running context
instead of the global context.

                visitThisExpression: (p) ->
                    @traverse(p)
                    if p.scope.isGlobal
                        {line, column} = p.node.loc.start
                        src = replaceAt(src, line, column, 'this', 'THIS')

Once the global variables are found, we can add them directly to our context.
(Since `.addProps()` only copies own-properties, this won't overwrite any
existing, inherited properties.)

            @addProps(globals)

In order to avoid reformatting the source code any more than necessary, we
don't use recast's source printer.  Instead, if there are any changes
necessary, we splice the assignment directly into the code at the exact
locations where the functions were declared.  We do this in reverse order
(popping locations off the list) so that if there are multiple declarations on
the same line, the column positions of earlier declarations will remain valid.

            if funcs.length
                while funcs.length
                    [name, {line, column:col}] = funcs.pop()
                    src = replaceAt(src, line, col, '', name + '=')

            return "with(MOCKDOWN_GLOBAL){#{src}}"

The actual source code replacement is done with a parameterized regular
expression that handles counting lines and columns.

        replaceAt = (TEXT, ROW, COL, MATCH, REPLACE) ->
            match = ///^
                ((?:[^\n]*\n){#{ROW-1}}.{#{COL}})#{MATCH}(.*)
            $///.exec(TEXT)
            if match then match[1] + REPLACE + match[2] else TEXT


#### Running Code

In principle, running a code sample is as simple as creating a `vm.Script` and
running it.  But in practice, node 0.12 and up expect an options object rather
than a filename, so if the supplied options contain a filename, we have to
figure out whether we're running on something newer than that, by checking for
the existence of `vm.runInDebugContext()` (which was added in 0.12).

        vm = require 'vm'

        toScript = (code, filename) ->
            if filename then new vm.Script(code,
                if vm.runInDebugContext?    # new API
                    {filename: filename, displayErrors:false}
                else filename
            )
            else new vm.Script(code)

To avoid mixing `recast()` syntax errors with Node syntax errors, we create
a dummy script for the unmodified code sample before creating the rewritten
script we'll actually run.  We then wrap the script execution with a temporary
global assignment to `MOCKDOWN_GLOBAL`, so the `with()` statement will pick up
our context when it executes.  (It's not needed after that.)

        run: (code, opts={}) ->
            toScript(code, opts.filename) # force syntax error here
            script = toScript(@rewrite(code), opts.filename)

            current_global = global
            current_global.MOCKDOWN_GLOBAL = @context
            try
                res = script.runInThisContext(displayErrors: false)
            finally
                delete current_global.MOCKDOWN_GLOBAL

Once the result of running the script is obtained, it's written to the console,
unless it's been disabled by setting the options' `.printResults` to false.
(Undefined values aren't printed, though, unless the `.ignoreUndefined'` option
has been set to false.)  In any event, the current `repl.writer` is used to
format the output, unless it's overridden via the `.writer` option.

            if opts.printResults ? true
                unless res is undefined and (opts.ignoreUndefined ? true)
                    @outputStream.write (opts.writer ? repl.writer)(res)+'\n'
            return res


#### Console Output Tracking

Last, but not least, the `.getOutput()` method just returns the current
accumulated output and resets it to accumulate from empty again.

        getOutput: -> @outputStream.splice(0).join ''





























### Waiting For Test Completion

Mockdown examples can run synchronously or asynchronously, depending on whether
they use the `wait()` function.  The `Waiter(callback)` class implements the
process of waiting, by keeping track of whether something is being waited for
(via its `.waiting` flag) and whether that something has happened yet (via its
`.finished` flag and `.done()` method).

    class mockdown.Waiter

        constructor: (@callback) ->
            @finished = @waiting = no


When `.done()` is called, its arguments are forwarded to the original callback,
and the waiter is flagged as `.finished` and not `.waiting` any more.

        done: =>
            @finished = yes
            @waiting = no
            @callback.apply(null, arguments)


And once the waiter is `.finished`, trying to wait for anything else should
result in an error.

        _startWaiting: ->
            if @finished
                throw new Error("Can't wait if already finished")
            @waiting = yes


The rest of the `wait()` implementation is straightforward: a waiter's `.wait()`
is a bound method that starts waiting and arranges for `.done()` to be called
with the appropriate argument(s) when the given timeout is reached, given
predicate returns true, or given thenable resolves or rejects.





        wait: (arg, pred) =>
            if arguments.length
                if typeof arg?.then is "function"
                    @waitThenable(arg)
                else if typeof arg is "function"
                    @waitPredicate arg
                else if typeof arg is "number"
                    @waitPredicate (pred ? -> yes), arg
                else throw new TypeError(
                    'must wait on timeout, function, promise, or nothing'
                )
            else
                @_startWaiting()
                @done

        waitThenable: (p) ->
            @_startWaiting()
            done = @done
            p.then(
                (v) -> done()
                (e) -> done(e or new Error('Empty promise rejection'))
            )
            return p

        waitPredicate: (pred, interval=1) ->
            @_startWaiting()
            setTimeout (=>
                return if @finished
                try
                    if pred() then @done()
                    else @waitPredicate(pred)
                catch e
                    @done(e)
            ), interval







### Markdown Lexical Analysis

Marked exposes a `Lexer` class that we can use to pull out headings, code, etc.
from markdown source. But it doesn't retain line numbers (which we need for
error messages, tracebacks, etc.), nor the original text/whitespace (which we
sometimes need for exact output matching.)  It also outputs the entire document
as a flat list, with certain structures encoded as start/end pairs, where we
would prefer to nest the contained items in a single object.

The `mockdown.lex()` function works around most of these limitations by
tracking the original text and line numbers, as well as restructuring nested
tokens into blocks.

Unfortunately, due to the way marked's lexer works, it cannot generate correct
line numbers for list items other than the first item, or any other blocks
embedded in a list. So, we keep track of the lexer state and only give line
numbers for tokens not embedded in a list.

    marked = require 'marked'

    mockdown.lex = (src) ->
        lexer = new marked.Lexer(
            # Specify all options in case somebody changed the global defaults;
            # use pedantic mode so blockquoted indented code blocks will
            # include trailing blank lines
            gfm: yes, tables: yes, pedantic: yes, sanitize: no, smartLists: yes
        )

        current = lexer.tokens  # where tokens get inserted
        stack = []              # track nested structures
        inList = no
        last_match = null       # track text and line numbers
        line = nextLine = 1








The original text of each token is saved in `last_match`, by replacing the
lexer's regex rules with dummy objects wrapping their `.exec()` methods.
(Unfortunately, marked's lexer doesn't use `.exec()` with the list-item
pattern, so we have to leave that one alone.)


        rules = {}
        for own name, re of lexer.rules
            if re instanceof RegExp and name isnt 'item'
                rules[name] = do (re) -> exec: ->
                    if (last_match = re.exec(arguments...))
                        nextLine = line + last_match[0].split('\n').length - 1

                        # Special case: marked ignores single newlines, but we
                        # need to count them to keep line numbers aligned
                        if this is rules.newline and nextLine-line is 1
                            line = nextLine

                    return last_match
            else
                rules[name] = re

        lexer.rules = rules


















Each token pushed is checked to see if it's a `_start` or `_end` token. Start
tokens are renamed to remove the `_start`, and get a `children` attribute that
will hold subsequent tokens.  End tokens pop the stack and are otherwise
ignored.  Non-start/end tokens get a line number and text, and the line number
for subsequent tokens is updated.

        lexer.tokens.push = (tok) ->
            tok.line = line unless inList
            #tok.src = last_match?[0]
            Array::push.call(current, tok)

            parts = tok.type.split('_')
            kind = parts.pop()

            if kind is 'start'
                stack.push(current, nextLine, inList)
                tok.type = parts.join('_')   # remove `_start` suffix
                tok.children = current = []
                inList = inList or tok.type is 'list'

            else if kind is 'end'
                current.pop()  # don't include end token in output
                inList = stack.pop()
                line = stack.pop() ? nextLine
                current = stack.pop()

            else
                line = nextLine

            return current.length   # emulate push() return


Finally, once all the monkeypatching is complete, we can just return the lexed
source, which will be an array of tokens, modified to our liking. (Albeit with
`.links` and `.push()` properties still attached to it... so we remove them by
returning a fresh array instead.)

        return [].concat(lexer.lex(src))



