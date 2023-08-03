# Literate Testing with Mockdown

## High-Level API

    mockdown = exports

    mockdown.testFiles = (paths, suiteFn, testFn, options) ->
        for path in paths
            mockdown.parseFile(path, options).register(suiteFn, testFn)
































## Utilities and Types

    mockdown.Environment = require('mock-globals').Environment

    {string, object, empty} = props = require 'prop-schema'
    bool = props.integer.and((v) -> v>0).or props.boolean
    int = props.integer.and(props.nonNegative)
    posInt = props.integer.and(props.positive)

    maybe = (t) -> empty.or(t)
    infinInt = int.or(
        props.check "must be integer or Infinity", (v) -> v is Infinity
    )

    mkArray = props.type (val=[]) -> [].concat(val)
    splitLines = (txt) -> txt.split /\r\n?|\n\r?/g
    offset =  (line, code) -> Array(line).join('\n') + code

    injectStack = (err, txt, replace=no) ->
        stack = splitLines(err.stack)
        stack.splice(splitLines(err.message).length,
            (if replace then stack.length else 0), txt)
        err.stack = stack.join('\n')
        return err

    storage_opts =
        descriptorFor: (name, spec) ->
            name = name + '_'   # store data in `name_`

            get: -> this[name]
            set: (v) -> this[name] = spec.convert(v)
            enumerable: yes
            configurable: yes
        setupStorage: ->   # no init needed

    recursive = props.compose(object.and(
        (v) ->
            for k in Object.keys(v) when props.isPlainObject(v[k])
                v[k] = recursive(v[k])
            return v))

    pattern = props.function.or (val) ->
        if typeof val is "string" then (arg) -> ~arg.indexOf(val)
        else if val instanceof RegExp then (arg) -> arg.match(val)
        else props.check("must be string, function, or regexp").converter(val)

## Options

    languages = require('./languages')()

    example_specs =
        ellipsis:
            empty.or(string) '...', "wildcard for output matching"
        ignoreWhitespace:
            bool no, "normalize whitespace for output mathching?"

        showCompiled: bool no, "show compiled code in errors"
        showOutput: bool yes, "show expected/actual output in errors"
        showDiff:   bool no, "use mocha's diffing for match errors"
        stackDepth: infinInt 0, "max # of stack trace lines in error output"

        skip:   bool no, "mark the test pending?"
        ignore: bool no, "treat the example as a non-test"

        waitForOutput: maybe(pattern) undefined, "output to stop on"
        waitName: maybe(string) 'wait', "name of 'wait()' function"
        testName: maybe(string) 'test', "name of current mocha test object"

        printResults: bool no, "output the result of evaluating each example"
        ingoreUndefined: bool yes, "don't output undefined results"
        writer:
            maybe(props.function) undefined, "function used to format results"
        defaultLanguage: maybe(string)("javascript",
            "language to use for code without an explicit language")

    document_specs = props.assign {}, example_specs,
        filename: string '<anonymous>', "filename for stack traces"
        globals: object {}, "global vars for examples"
        languages: props.type(recursive)(languages, "language specs")



## Containers

    class Container
        props(@, children: mkArray(undefined, "contained items"), storage_opts)

        constructor: props.Base

        add: (child) ->
            @children.push(c) if (c = child.onAdd(this))?
            this

        registerChildren: (suiteFn, testFn, env) ->
            for child in @children then child.register(suiteFn, testFn, env)
            this

### Document Objects

    class mockdown.Document extends Container

        props(@, document_specs)

        getEngine: (lang) ->
            info = @languages[lang.toLowerCase()]
            info = @languages[info.toLowerCase()] if typeof info is "string"
            return info

        register: (suite, test, env = new mockdown.Environment @globals) ->
            @registerChildren(suite, test, env)













### Section Objects

    class mockdown.Section extends Container
        props(@,
            title: maybe(string)(undefined, "section title")
            level: posInt(1, "heading level"))

        onAdd: (container) ->
            if @children.length==1 and
             (child = @children[0]) instanceof mockdown.Example and
                !child.getTitle(yes)?
                    child.title = @title
                    child.onAdd(container)
            else if @children.length then this

        register: (suiteFn, testFn, env) -> suiteFn @title, =>
            @registerChildren(suiteFn, testFn, env)
























### Builder Objects

    class mockdown.Builder

        constructor: (@container) ->
            @stack = []

        startSection: (level, title) ->
            @endSection() while level <= (@container.level ? -1)
            @stack.push @container
            @container = new mockdown.Section({level, title})
            return this

        addExample: (e) ->
            @container.add(e)
            return this

        endSection: ->
            @container = @stack.pop().add(@container)
            return this

        end: ->
            @endSection() while @stack.length
            return @container

















## Running Examples
### Example Objects

    class mockdown.Example
        props(@, example_specs, storage_opts)
        props(@,
            filename: document_specs.filename
            engine: props.spec(languages.javascript, "language engine to use")
            line:
                maybe(posInt) undefined, "line number for stack traces"
            code:
                maybe(string) undefined, "code of the test"
            output:
                string '', "expected output"
            seq: maybe(int) undefined, "an example's sequence #"
            title: maybe(string) undefined, "title of the test"
        )
        constructor: -> props.Base.apply(this, arguments)

        onAdd: (container) ->
            @seq = container.children.length + 1
            this

        register: (suiteFn, testFn, env) ->
            if @skip
                testFn @getTitle()
            else
                my = this
                testFn @getTitle(), (done) -> my.runTest(env, @runnable(), done)

        getTitle: (explicit=no)->
            return @title if @title?
            return m[2].trim() if m = @code?.match(///
                ^ \s*  (//|#|--|%)  \s* ([^\n]+)
            ///)
            unless explicit
                if @seq then "Example "+@seq + (
                    if @line then ' at line '+@line else ''
                ) else "Example"
            else undefined

        runTest: (env, testObj, done) ->

            finished = no

            waiter = new mockdown.Waiter (err) =>
                if finished
                    done(err) if err
                else
                    finished = yes
                    @unwatch(env) if @waitForOutput
                    @writeError(env, err) if err
                    matchErr = @mismatch(env.getOutput())

                    if not matchErr
                        done.call(null, undefined)
                    else if not err?
                        done.call(null, matchErr)
                    else
                        matchErr.originalError = err
                        done.call(null, injectStack(matchErr, err.stack, yes))

            testObj.callback = waiter.done

            try
                @watch(env, @waitForOutput, waiter.wait()) if @waitForOutput
                @evaluate(env, wait: waiter.wait, test: testObj)
                waiter.done() unless waiter.waiting
            catch e
                if waiter.waiting
                    @writeError(env, e)
                else waiter.done(e)

        watch: (env, pred, done) ->
            pred = pattern.converter(pred)
            os = env.outputStream; os.write = (arg) =>
                os.push(arg)
                if pred(arg.toString())
                    @unwatch(env); process.nextTick(done)

        unwatch: (env) -> os = env.outputStream; os.write = os.push

        number = (line, text) ->
            line = "      #{+line} | #{text}"
            line.substr(-(9+text.length))

        mismatch: (output) ->
            return if output is @output
            msg = ['']
            if @showOutput
                code = if @showCompiled then @toJS(1) else @code
                msg.push 'Code:'
                for l, i in splitLines(code ? '')
                    msg.push(if @line? then number(i+@line, l) else '    '+l)
                msg.push 'Expected:'
                msg.push '>     '+l for l in expected = splitLines(@output)
                msg.push 'Got:'
                msg.push '>     '+l for l in actual = splitLines(output)
            err = new Error(msg.join('\n'))
            err.name = 'Failed example'
            err.showDiff = @showDiff
            err.expected = expected
            err.actual = actual
            return injectStack(err, "  at Example (#{@filename}:#{@line})")

        offset: (line=@line, code=@code) -> offset(line, code)

        toJS: (line=@line) -> @engine.toJS(this, line)

        evaluate: (env, params) ->
            if params
                for k in Object.keys(params) when name = this[k+"Name"]
                    env.context[name] = params[k]
            return env.run(@toJS(), this)

        writeError: (env, err) ->
            msgLines = splitLines(err.message).length
            stack = splitLines(err.stack).slice(0, @stackDepth + msgLines)
            env.context.console.error(stack.join('\n'))




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







## Parsing

    mockdown.parse = (input, options) ->
        return new mockdown.Parser(options).parse(input)
    mockdown.parseFile = (path, options) ->
        return new mockdown.Parser(options).parseFile(path)

### The Parser

    class mockdown.Parser
        constructor:  ->
            @doc = new mockdown.Document(arguments...)
            @builder = new mockdown.Builder(@doc)
            @example = undefined

        match: (tok, pred) ->
            if typeof pred is 'string'
                return tok if tok.type == pred
            else
                for p in pred
                    t = @match(tok, p)
                    return t if t?
            return

        matchDeep: (tok, pred, subpreds...) ->
            return unless (tok = @match(tok, pred))?
            return tok unless subpreds.length
            children = (c for c in tok.children ? [] when c.type isnt 'space')
            return unless children.length == 1
            return @matchDeep(children[0], subpreds...)

        syntaxError: (line, message) -> injectStack(
            new SyntaxError(message), "  at (#{@doc.filename}:#{line})"
        )

        parseFile: (path) ->
            @doc.filename = path if @doc.filename is '<anonymous>'
            @parse require('fs').readFileSync(path, 'utf8')



#### Parsing States

        parse: (input) ->
            input = mockdown.lex input if typeof input is 'string'

            # make a copy so our options aren't mutated
            parser = new @constructor(@doc)

            state = parser.SCAN
            for tok in input when tok.type isnt 'space'
                state = state.call(parser, tok)

            state.call(parser, type: 'END')
            return parser.builder.end()

        SCAN: (tok) ->
            @parseDirective(tok, no) or @parseCode(tok) or
            @parseHeading(tok) or @SCAN

        HAVE_DIRECTIVE: (tok) ->
            @parseDirective(tok, yes) or @parseCode(tok) or throw @syntaxError(
                tok.line, "no example found for preceding directives"
            )

        HAVE_CODE: (tok) ->
            if out = @matchDeep(tok, 'blockquote', 'code')
                @setExample(output: out.text+'\n')
            @builder.addExample @example unless @example.ignore
            @example = undefined
            return @SCAN(tok)

        setExample: (data) ->
            return props.assign(@example, data) if @example?
            @example ?= new mockdown.Example(data, @doc)







#### Parsing Rules

        parseCode: (tok) ->
            return unless tok.type is 'code'
            @setExample(line: tok.line, code: tok.text)
            lang = tok.lang ? @example.defaultLanguage
            unless @example.engine = @doc.getEngine(lang)
                throw @syntaxError(tok.line, "Unrecognized language: " + lang)
            @example.ignore = yes if @example.engine is 'ignore'
            @started = yes
            return @HAVE_CODE

        parseHeading: (tok) ->
            return unless tok.type is 'heading'
            @builder.startSection(tok.depth, tok.text)
            return @SCAN

        parseDirective: (tok, haveDirective) ->
            return unless tok = @matchDirective(tok)
            switch tok.type
                when 'mockdown'
                    @directive(@setExample(), tok.text, tok.line)
                    @started = yes
                    return @HAVE_DIRECTIVE
                when 'mockdown-set'
                    return if haveDirective
                    @directive(@doc, tok.text, tok.line)
                when 'mockdown-setup'
                    return if haveDirective
                    throw @syntaxError(
                        tok.line,
                        "setup must be before other code or directives"
                    ) if @started
                    @directive(@doc, tok.text, tok.line, document_specs)
            @started = yes
            return @SCAN





#### Directives

        directiveStart = /// ^ ([\S\s]* <!-- \s*) mockdown ///

        validDirective = ///
        ^ \s* <!-- \s* (mockdown (?:-set|-setup|)) :
        ( (?: [^-] | -(?!->) )* ) --> \s* $ ///

        matchDirective: (tok) ->
            return unless tok.type is 'html'
            return unless match = tok.text.match(directiveStart)

            [all, prefix] = match
            tok.line += splitLines(prefix).length - 1

            unless match = tok.text.match(validDirective)
                throw @syntaxError(tok.line, "malformed mockdown directive")

            [all, tok.type, tok.text] = match
            return tok

        directive: (ob, code, line, specs=example_specs) ->
            @directiveEnv(ob, specs).run(
                offset(line, code), filename: @doc.filename
            )

        directiveEnv: (ob, allowed) ->
            ctx = (env = new mockdown.Environment).context
            Object.keys(document_specs).forEach (name) ->
                msg = name+" can only be accessed via mockdown-setup"
                err = -> throw new TypeError(msg)
                descr = get: err, set: err

                if allowed.hasOwnProperty(name)
                    descr.set = (val) -> ob[name] = val
                    descr.get = -> ob[name]

                Object.defineProperty(ctx, name, descr)
            return env


### Markdown Lexical Analysis

Mockdown was originally written to use Marked for turning markdown into tokens.
Marked, however, created a flat list of tokens that lacked line numbers, so
we've lately switched to using `remark` instead.  `remark` provides an
already-built tree structure that mostly resembles Marked tokens, so we convert
them the rest of the way to the old Marked tokens we were using before.  In
addition to letting us leave all the other code and tests alone, it also
shortens the printed representation of tokens compared to raw `remark` tokens,
by dropping information we don't need.

    remark = require('remark')()  # create a private instance

    mockdown.lex = (src) ->
        toMarked(tok) for tok in remark.parse(src).children

Mostly, this conversion consists of renaming nodes' `.value` to `.text` and
flattening their `.position` to a simple `.line`.  Headings and paragraphs also
need their children flattened into the original text, and code nodes need some
extra work to maintain correct trailing whitespace and start line position.

    toMarked = (tok, parent) ->

        if tok.value?
            tok.text = tok.value
            delete tok.value

        if tok.children?
            if tok.type in ['heading', 'paragraph']
                tok.text = ((remark.stringify(c) for c in tok.children).join '').trimEnd()
                delete tok.children
            else tok.children = (toMarked(c, tok) for c in tok.children)

        if (p = tok.position)?
            tok.line = p.start.line
            lineCount = p.end.line - tok.line + 1
            reformatCode(tok, parent, lineCount) if tok.type is 'code'
            delete tok.position

        return tok

`remark` gives the position range of fenced code blocks with the fences
themselves included in the size.  But those lines aren't part of the `.text`,
so we can detect the missing lines in order to know that a code block is
fenced.  And that lets us offset the start line by 1, so `.line` will refer
to the actual start line of the *code*, instead of the fence.

    reformatCode = (tok, parent, lineCount) ->

        ++tok.line if missing = lineCount - splitLines(tok.text).length

Another issue: code contained in a blockquote may be missing trailing blank
lines, which may be a problem for output matching.  We restore those lines
by comparing the blockquote's end line with the code block's end line, and
add in the missing line feeds.

        if parent?.type is 'blockquote' and parent.children.length == 1
            add = parent.position.end.line - tok.position.end.line
            tok.text += Array(add+1).join('\n')























