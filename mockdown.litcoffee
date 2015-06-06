# Literate Testing with Mockdown

    mockdown = exports






































### Environment Objects

An environment is like a stripped-down node REPL that runs code samples in
a `.context` that retains its state and records its console output.  It uses
node's `REPLServer` class to create a suitable global context, given a dummy
`.outputStream` whose `.write()` method accumulates output in an array.  The
supplied globals are added to the `.context` after first fixing up the builtins
(in the event we're running on a node version that doesn't share builtins
across contexts.)

    class mockdown.Environment

        repl = require 'repl'

        constructor: (globals) ->
            @useGlobal = no
            @outputStream = []
            @outputStream.write = @outputStream.push

            @context = repl.REPLServer::createContext.call(this)
            @copyBuiltins() unless @context.Array is Array
            @context[k] = v for own k, v of globals

        copyBuiltins: ->
            @context[k] = global[k] for k in ['NaN', 'Infinity', 'undefined',
                'eval', 'parseInt', 'parseFloat', 'isNaN', 'isFinite', 'decodeURI',
                'decodeURIComponent', 'encodeURI', 'encodeURIComponent',
                'Object', 'Function', 'Array', 'String', 'Boolean', 'Number',
                'Date', 'RegExp', 'Error', 'EvalError', 'RangeError',
                'ReferenceError', 'SyntaxError', 'TypeError', 'URIError',
                'Math', 'JSON'
            ]

In principle, running a code sample is as simple as creating a `vm.Script` and
running it.  But in practice, node 0.12 and up expect an options object rather
than a filename, so if the supplied options contain a filename, we have to
figure out whether we're running on something newer than that, by checking for
the existence of `vm.runInDebugContext()` (which was added in 0.12).

        vm = require 'vm'
        
        run: (code, opts={}) ->
            script = if opts.filename then new vm.Script(code,
                        if vm.runInDebugContext?    # new API
                            {filename: opts.filename, displayErrors:false}
                        else opts.filename
                    )
            else new vm.Script(code)
            res = script.runInContext(@context)

Once the result of running the script is obtained, it's written to the console,
unless it's been disabled by setting the options' `.printResults` to false.
(Undefined values aren't printed, though, unless the `.ignoreUndefined'` option
has been set to false.)  In any event, the current `repl.writer` is used to
format the output, unless it's overridden via the `.writer` option.

            if opts.printResults ? true
                unless res is undefined and (opts.ignoreUndefined ? true)
                    @outputStream.write (opts.writer ? repl.writer)(res)+'\n'
            return res

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



