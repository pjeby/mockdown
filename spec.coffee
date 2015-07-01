{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

expect_fn = (item) -> expect(item).to.exist.and.be.a('function')
{spy} = sinon = require 'sinon'

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

failSafe = (done, fn) -> ->
    try fn.apply(this, arguments)
    catch e then done(e)

{lex, Options, Section, Example, Environment, Document, Waiter} = require './'
util = require 'util'























describe "mockdown.Waiter(cb)", ->

    beforeEach -> @waiter = new Waiter(@spy = spy.named 'done')

    describe "calls cb() with null context", ->

        it "when .done() called as method", ->
            @waiter.done()
            expect(@spy).to.have.been.calledOnce
            expect(@spy).to.have.been.calledWithExactly()
            expect(@spy).to.have.been.calledOn(null)

        it "when .done(err) called as method", ->
            @waiter.done(e=new Error)
            expect(@spy).to.have.been.calledOnce
            expect(@spy).to.have.been.calledWithExactly(e)
            expect(@spy).to.have.been.calledOn(null)

        it "when done() called as function", ->
            done = @waiter.done
            done()
            expect(@spy).to.have.been.calledOnce
            expect(@spy).to.have.been.calledWithExactly()
            expect(@spy).to.have.been.calledOn(null)

        it "when done(err) called as function", ->
            done = @waiter.done
            done(e=new Error)
            expect(@spy).to.have.been.calledOnce
            expect(@spy).to.have.been.calledWithExactly(e)
            expect(@spy).to.have.been.calledOn(null)

    describe ".finished", ->

        it "is initially false", ->
            expect(@waiter.finished).to.be.false

        it "becomes true as soon as done() is called", ->
            waiter = new Waiter(-> expect(waiter.finished).to.be.true)
            waiter.done()

    describe ".waiting", ->

        it "is initially false", ->
            expect(@waiter.waiting).to.be.false

        it "is set to false as soon as done() is called", ->
            waiter = new Waiter(-> expect(waiter.waiting).to.be.false)
            waiter.waiting = true
            waiter.done()

    describe ".waitThenable()", ->

        beforeEach ->
            @thenable = then: @thenSpy = spy.named 'then', (@onF, @onR) =>
            return

        it "returns its argument", ->
            expect(@waiter.waitThenable(@thenable)).to.equal(@thenable)

        it "passes distinct callbacks to thenable.then()", ->
            @waiter.waitThenable(@thenable)
            expect(@thenSpy).to.have.been.calledOnce
            expect(@thenSpy).to.have.been.calledWithExactly(@onF, @onR)
            expect_fn(@onF)
            expect_fn(@onR)
            expect(@onF).to.not.equal(@onR)

        it "invokes @done when the thenable resolves", ->
            @waiter.waitThenable(@thenable)
            @onF(42)
            expect(@spy).to.have.been.calledOnce
            expect(@spy).to.have.been.calledWithExactly()
            expect(@spy).to.have.been.calledOn(null)

        it "forwards thenable errors to @done", ->
            @waiter.waitThenable(@thenable)
            @onR(e = new Error)
            expect(@spy).to.have.been.calledOnce
            expect(@spy).to.have.been.calledWithExactly(e)
            expect(@spy).to.have.been.calledOn(null)

        it "handles falsy promise resolution", ->
            waiter = new Waiter reject = spy.named 'reject', (e) ->
                expect(e).to.exist
                expect(e).to.be.instanceOf(Error)
                expect(-> throw e).to.throw /rejection/

            waiter.waitThenable(@thenable)
            @onR()
            expect(reject).to.have.been.calledOnce
            expect(reject).to.have.been.calledOn(null)

        it "marks the waiter as waiting", ->
            @waiter.waitThenable(@thenable)
            expect(@waiter.waiting).to.be.true

        it "throws an error if already finished", ->
            @waiter.done()
            expect(
                => @waiter.waitThenable(@thenable)
            ).to.throw /already finished/


    describe ".waitPredicate(pred, interval)", ->

        it "calls pred after the timeout", (done) ->
            @waiter.waitPredicate pred = spy.named 'pred', -> true
            setTimeout (failSafe done, =>
                expect(pred).to.have.been.calledOnce
                expect(@spy).to.have.been.calledOnce
                done()
            ), 5

        it "calls pred repeatedly, until it returns true", (done) ->
            @runnable().slow(100)
            count = 3
            pred = spy.named 'pred', -> --count is 0
            waiter = new Waiter failSafe done, =>
                expect(pred).to.have.been.calledThrice
                done()
            waiter.waitPredicate(pred)

        it "uses the timeout value given", (done) ->
            @waiter.waitPredicate (pred = spy.named 'pred', -> true), 20
            setTimeout (failSafe done, =>
                expect(pred).to.not.have.been.called
            ), 5
            setTimeout (failSafe done, =>
                expect(pred).to.have.been.calledOnce
                expect(@spy).to.have.been.calledOnce
                done()
            ), 30

        it "returns a timeout that can be canceled", (done) ->
            timeout = @waiter.waitPredicate (pred = spy.named 'pred', -> true)
            clearTimeout(timeout)
            setTimeout (failSafe done, =>
                expect(pred).to.not.have.been.called
                done()
            ), 10

        it "forwards predicate() errors to @done", (done) ->
            err = new Error()
            @waiter.waitPredicate pred = spy.named 'pred', -> throw err
            setTimeout (failSafe done, =>
                expect(pred).to.have.been.calledOnce
                expect(@spy).to.have.been.calledOnce
                expect(@spy).to.have.been.calledWithExactly(err)
                done()
            ), 10

        it "doesn't call the predicate if finished before timeout", (done) ->
            @waiter.waitPredicate (pred = spy.named 'pred', -> true)
            @waiter.done()
            setTimeout (failSafe done, =>
                expect(pred).to.not.have.been.called
                done()
            ), 10

        it "marks the waiter as waiting", ->
            @waiter.waitPredicate(-> yes)
            expect(@waiter.waiting).to.be.true

        it "throws an error if already finished", ->
            @waiter.done()
            expect(
                => @waiter.waitPredicate(-> yes)
            ).to.throw /already finished/

    describe "bound method .wait", ->

        beforeEach ->
            @spyPred = spy.named "waitPredicate", @waiter, "waitPredicate"
            @spyThen = spy.named "waitThenable", @waiter, "waitThenable"
            @wait = @waiter.wait

        it "() -> the waiter's .done method", ->
            expect(@wait()).to.equal(@waiter.done)

        it "() -> marks the waiter as waiting", ->
            @wait()
            expect(@waiter.waiting).to.be.true

        it "() -> throws an error if already finished", ->
            @waiter.done()
            expect(@wait).to.throw /already finished/

        it "(number) -> .waitPredicate(->yes, number)", ->
            res = @wait(99)
            expect(@spyPred).to.have.been.calledOnce
            expect(@spyPred).to.have.returned(res)
            expect_fn(pred = @spyPred.args[0][0])
            expect(pred()).to.be.true
            expect(@spyPred.args[0][1]).to.equal(99)

        it "(number, function) -> .waitPredicate(function, number)", ->
            res = @wait(0, pred = -> yes)
            expect(@spyPred).to.have.been.calledOnce
            expect(@spyPred).to.have.been.calledWithExactly(pred, 0)
            expect(@spyPred).to.have.returned(res)




        it "(function) -> .waitPredicate(function)", ->
            res = @wait(pred = -> yes)
            expect(@spyPred).to.have.been.calledOnce
            expect(@spyPred).to.have.been.calledWithExactly(pred)
            expect(@spyPred).to.have.returned(res)

        it "(thenable-object) -> .waitThenable(thenable-object)", ->
            res = @wait(thenable = then: ->)
            expect(@spyThen).to.have.been.calledOnce
            expect(@spyThen).to.have.been.calledWithExactly(thenable)
            expect(res).to.equal(thenable)

        it "(thenable-function) -> .waitThenable(thenable-function)", ->
            thenable = ->
            thenable.then = ->
            res = @wait(thenable)
            expect(@spyThen).to.have.been.calledOnce
            expect(@spyThen).to.have.been.calledWithExactly(thenable)
            expect(res).to.equal(thenable)

        describe "(anything else) -> throws TypeError", ->
            for arg in [{then:1}, "string", null, undefined, true, false]
                do (arg) -> it "with #{arg}", ->
                    expect(=> @wait(arg)).to.throw TypeError
                    expect(=> @wait(arg)).to.throw /must wait on/
















describe "mockdown.Environment(globals)", ->

    beforeEach -> @env = new Environment(x:1, y:2)

    describe ".run(code, opts)", ->

        it "returns the result", ->
            expect(@env.run('1')).to.equal(1)

        it "throws any syntax errors", ->
            expect(=> @env.run('if;')).to.throw SyntaxError

        it "throws any runtime errors", ->
            expect(=> @env.run('throw new TypeError')).to.throw(
               TypeError
            )

        it "sets the filename from opts.filename", ->
            try
                @env.run('throw new Error', filename: 'foobar.js')
            catch e
                expect(e.stack).to.match /at foobar.js:1/

        it "uses the same Javascript engine", ->
            expect(@env.run('[]')).to.be.instanceOf Array
            expect(@env.run('({})')).to.be.instanceOf Object
            expect(@env.run('(function(){})')).to.be.instanceOf Function
            expect(@env.run('new Error')).to.be.instanceOf Error













        describe "prevents global assignment via", ->

            check = (title, code, result, strict=yes) -> it title, ->
                expect(@env.run(code)).to.equal(result)
                if strict
                    expect(global.hasOwnProperty("foo#{result}")).to.be.false
                else
                    expect(typeof global["foo#{result}"]).to.equal 'undefined'

            check "simple assignment", 'foo1=1', 1
            check "var declaration", 'var q, foo2=2; foo2', 2, false
            check "nested assignment", 'function q(){ return foo3=3;}; q()', 3

            check "function declaration",
                'function foo4() { return 4; }; foo4()', 4

            check "conditional declaration",
                'if (1) function foo5() { return 5; }; foo5()', 5

            check "strict mode assignment",
                'function x() { "use strict"; foo6=6; }; x(); foo6', 6

            check "global.property assignment",
                'global.foo7 = 7; foo7', 7

            check "`this` assignment", 'this.foo8 = 8; foo8', 8

            check "for loops", 'for (foo9=0; foo9<9; foo9++) {}; foo9', 9

            check "for-var loops",
                'for (var foo10=0; foo10<10; foo10++) {}; foo10', 10, false

            check "for-in loops", 'for (fooX in {X:1}) {}; fooX', 'X'

            check "for var-in loops",
                'for (var fooY in {Y:1}) {}; fooY', 'Y', false





    describe ".context variables", ->

        it "include the globals used to create the environment", ->
            expect(@env.context.x).to.equal(1)
            expect(@env.context.y).to.equal(2)

        it "are readable by run() code", ->
            expect(@env.run('[x,y]')).to.eql([1,2])

        it "are writable by run() code", ->
            @env.run('var x=3; y=4')
            expect(@env.context.x).to.equal(3)
            expect(@env.context.y).to.equal(4)

        it "can be defined by run() code", ->
            @env.run('var z=42')
            expect(@env.context.z).to.equal(42)

        it "include a global and GLOBAL that map to the context", ->
            expect(@env.run('global')).to.equal(@env.context)
            expect(@env.run('GLOBAL')).to.equal(@env.context)

        it "include a complete `require()` implementation", ->
            req = @env.context.require
            expect(req('./spec.coffee')).to.equal(exports)
            expect(req.cache).to.equal(require.cache)
            expect(req.resolve('./spec.coffee')).to.equal(
                   require.resolve('./spec.coffee'))

        it "include a unique (but linked) exports and module.exports", ->
            e1 = @env;  e2 = new Environment()
            expect(c1 = e1.context).to.not.equal(c2 = e2.context)
            expect(m1 = c1.module) .to.not.equal(m2 = c2.module)
            expect(x1 = m1.exports).to.not.equal(x2 = m2.exports)
            expect(x1).to.exist.and.equal(c1.exports).and.deep.equal({})
            expect(x2).to.exist.and.equal(c2.exports).and.deep.equal({})
            nx1 = c1.exports = {}
            expect(m1.exports).to.equal(c1.exports).and.equal(nx1)
            nx2 = m2.exports = {}
            expect(m2.exports).to.equal(c2.exports).and.equal(nx2)

    describe ".getOutput()", ->

        beforeEach -> @console = @env.context.console

        it "returns all log/dir/warn/error text from .context.console", ->
            @console.error("w")
            @console.warn("x")
            @console.log("y")
            @console.dir("z")
            expect(@env.getOutput().split('\n')).to.eql(
                ['w','x','y',"'z'", ""]
            )
        it "resets after each call", ->
            @console.log("x")
            expect(@env.getOutput().split('\n')).to.eql(['x',''])
            expect(@env.getOutput()).to.eql('')


    describe "result logging", ->

        it "logs results other than undefined", ->
            @env.run('1')
            @env.run('null')
            @env.run('if(0) 1;')
            expect(@env.getOutput()).to.eql('1\nnull\n')

        it "logs undefined if opts.ignoreUndefined is false", ->
            @env.run('if(0) 1;', ignoreUndefined: no)
            expect(@env.getOutput()).to.eql('undefined\n')

        it "uses opts.writer if specified", ->
            @env.run('2', writer: writer = spy.named 'writer', -> 'hoohah!')
            expect(@env.getOutput()).to.eql('hoohah!\n')
            expect(writer).to.have.been.calledOnce
            expect(writer).to.have.been.calledWithExactly(2)

        it "doesn't log results if disabled", ->
            @env.run('1', printResults: no)
            expect(@env.getOutput()).to.eql('')


    describe ".rewrite(code)", ->

        it "doesn't rewrite inner `this`", ->
            expect(@env.rewrite(src = '(function(){this})'))
            .to.equal("with(MOCKDOWN_GLOBAL){#{src}}")

        describe "handles oddly formatted stuff like", ->
            it "tabs messing up offset positions"
            it "carriage returns and other zero-space characters"
            it "wide character offsets"































checkDefaults = (cls) ->
    for k, [dflt, alt] of {
        skip: [no, yes]
        waitName: ['wait', null]
        testName: ['test', null]
        ellipsis: ['...', null]
        ignoreWhitespace: [no, yes]
        showOutput: [yes, no]
        showDiff: [no, yes]
        filename: ['<anonymous>', 'helloWorld.js']
        stackDepth: [0, 2]
        globals: [{}, {x:'y'}]
        line: [undefined, 42]
        title: [undefined, 'An Example']
        code: [undefined, '1+1']
        output: [undefined, 'xxx']
    } then do (k, dflt, alt) ->
        describe ".#{k} = #{util.inspect(dflt)}", ->
            it "when overwritten", ->
                expect(new cls("#{k}": alt).opts[k]).to.deep.equal(alt)
            it "when unsupplied", ->
                expect(new cls({}).opts[k]).to.deep.equal(dflt)
            it "when no options given", ->
                expect(new cls().opts[k]).to.deep.equal(dflt)

















describe "mockdown.Options(opts?, defaults?)", ->

    it "works with or without `new`", ->
        expect(Options({})).to.be.instanceOf(Options)
        .and.deep.equal new Options {}

    describe "argument validation", ->

        it "expects at most two arguments", ->
            expect(-> new Options({}, new Options({}), 42))
            .to.throw /two or fewer arguments/

        it "requires opts to be a plain Object or Options", ->
            expect(-> new Options new class Foo)
            .to.throw /must be a plain Object/

        it "requires defaults to be an Options instance", ->
            expect(-> new Options {}, {})
            .to.throw /must be an Options object/

        it "rejects invalid keys in opts", ->
            expect(-> new Options {x: 'y'})
            .to.throw /Unknown option: x/

        describe "allows empty arguments", ->
            it "by omission", ->
                expect(new Options).to.deep.equal new Options {}
            it "by passing null", ->
                expect(new Options null, null).to.deep.equal new Options {}
            it "by passing undefined", ->
                expect(new Options undefined, undefined)
                .to.deep.equal new Options {}

    describe "gets properties from opts, including", ->
        checkDefaults class StdOpts
            constructor: (opts) -> @opts = new Options(opts)

    describe "gets defaults from defaults, including", ->
        checkDefaults class DefaultOpts
            constructor: (opts) -> @opts = new Options({}, new Options(opts))

    describe ".mismatch(output)", ->
        mismatch = (opts, output) -> new Options(opts).mismatch(output)

        it "returns an untrue value if output matches opts.output", ->
            expect(!!new Options(output:'x').mismatch('x')).to.be.false

        it "normalizes whitespace when opts.ignoreWhitespace"
        it "treats opts.ellipsis as a wildcard when set"

        describe "returns an error object for mismatches, that", ->

            it "has .actual and .expected line-list properties", ->
                err = mismatch(output:'x\ny', 'y\nz')
                expect(err.name).to.equal('Failed example')
                expect(err).to.be.instanceOf(Error)
                expect(err.actual).to.deep.equal ['y','z']
                expect(err.expected).to.deep.equal ['x','y']

            it "has actual/expected in .message if opts.showOutput", ->
                expect(mismatch(
                    code:'foo()\nbar()', output:'a\nb', showOutput: no, 'b\nc'
                ).message).to.equal('')
                err = mismatch(code:'foo()\nbar()', output:'a\nb', 'b\nc')
                expect(err.message.split('\n')).to.deep.equal [
                    '', 'Code:', '    foo()', '    bar()'
                    'Expected:', '>     a', '>     b'
                    'Got:',      '>     b', '>     c'
                ]

            it "has a true .showDiff if opts.showDiff", ->
                expect(mismatch(output:'x\ny', 'y\nz').showDiff).to.be.false
                expect(mismatch(output:'x\ny', showDiff: yes, 'y\nz').showDiff)
                .to.be.true

            it "has a stack that includes opts.filename:opts.line", ->
                err = new Options(
                    output:'x\ny', line:55, filename:'foo.md', showOutput:no
                ).mismatch('y\nz')
                expect(err.stack.split('\n')[1])
                .to.equal "  at Example (foo.md:55)"

    describe ".evaluate(env, params)", ->

        evaluate = (opts, env=new Environment, params) ->
            o = new Options(opts)
            if arguments.length>2
                return o.evaluate(env, params)
            return o.evaluate(env)

        it "runs opts.code in env, returning the result", ->
            expect(evaluate(code: 'foo', new Environment(foo: 42)))
            .to.equal(42)

        it "uses the correct line numbers and filenames in stack traces", ->
            try
                evaluate(
                    code: '\n\nthrow new Error', line: 40
                    filename: 'throw-sample.js'
                )
            catch e
                s = e.stack.split('\n').slice(0, 2)
                expect(s).to.deep.equal(['Error', '  at throw-sample.js:42:7'])
                return
            throw new Error("Example didn't throw")

        it "makes params.wait available under opts.waitName, if set", ->
            expect(evaluate(code:'wait', null, wait:42)).to.equal 42
            expect(evaluate(code:'hold', waitName: 'hold', null, wait:42))
            .to.equal 42


        it "makes params.test available under opts.testName, if set", ->
            expect(evaluate(code:'test', null, test:99)).to.equal 99
            expect(evaluate(code:'example', testName: 'example', null, test:99)
            ).to.equal 99







    describe ".writeError(env, err)", ->

        getError = (stackDepth, err) ->
            new Options({stackDepth}).writeError(env = new Environment, err)
            return env.getOutput()

        it "writes err.stack to env's console", ->
            expect(getError(Infinity, err = new Error("message")).split('\n'))
            .to.deep.equal (err.stack+'\n').split('\n')

        it "trims the stack to .stackDepth lines", ->
            expect(getError(1, err = new Error("message\n1\n2")).split('\n'))
            .to.deep.equal err.stack.split('\n').slice(0, 4).concat([''])




























describe "mockdown.Example(opts)", ->

    describe "gets properties from opts, including", ->

        beforeEach -> @ex = new Example(@opts = new Options(@args = (
            title: @title = "Hello world"
            code: @code = 'console.log("Hello world!")'
            output: @output = 'Hello world!\n'
            line: @line = 42
        )))

        it ".title",  -> expect(@ex.title) .to.equal(@title)
        it ".code",   -> expect(@ex.code)  .to.equal(@code)
        it ".output", -> expect(@ex.output).to.equal(@output)
        it ".line",   -> expect(@ex.line) .to.equal(@line)

        describe ".opts", ->

            it "when passed an Options object", ->
                expect(@ex.opts).to.be.instanceOf(Options).and.deep.equal(@opts)
                expect(@ex.opts).to.not.equal(@opts)

            it "when passed a plain object", ->
                d = new Example(@args)
                expect(d.opts).to.be.instanceOf(Options).and.deep.equal(@opts)
                expect(d.opts).to.not.equal(@opts)















    describe ".getTitle()", ->

        it "returns .title if set", ->
            ex = new Example title: 'A Title'
            expect(ex.getTitle()).to.equal 'A Title'

        it "returns a default title of 'Example'", ->
            ex = new Example
            expect(ex.getTitle()).to.equal 'Example'

        it "returns 'Example N' where N is its position in a container", ->
            (ex = new Example).onAdd(children: [])
            expect(ex.getTitle()).to.equal 'Example 1'
            ex.onAdd(children: [42])
            expect(ex.getTitle()).to.equal 'Example 2'

        describe "extracts a title from a first code line comment", ->
            for cmt in ['//', '#', '--','%'] then it "using #{cmt}", ->
                ex = new Example code: """\
                    #{cmt} An example using #{cmt} as a delimiter """
                expect(ex.getTitle()).to.equal(
                    "An example using #{cmt} as a delimiter"
                )
                ex = new Example code: """\
                    Not! #{cmt} An example using #{cmt} as a delimiter"""
                expect(ex.getTitle()).to.equal("Example")















    describe ".runTest(env, testObj, done)", ->

        beforeEach ->
            @env = new Environment
            @gotOutput = spy.named 'getOutput', @env, 'getOutput'
            @done = spy.named 'done'
            @testOb = {}

            @runTest = (@ex, @testOb={}, @done = spy.named 'done') ->
                @evaled = spy.named 'evaluate', @ex.opts, 'evaluate'
                @checked = spy.named 'mismatch', @ex.opts, 'mismatch'
                @ex.runTest(@env, @testOb, @done)

            @checkRanOnce = ->
                expect(@evaled).to.have.been.calledOnce
                expect(@evaled).to.have.been.calledWith(@env)
                expect(@evaled).to.have.been.calledOn(@ex.opts)
                expect(@evaled.args[0][1].test).to.equal(@testOb)
                expect(@gotOutput).to.have.been.calledOnce
                expect(@gotOutput).to.have.been.calledAfter @evaled
                expect(@checked).to.have.been.calledOnce
                expect(@checked).to.have.been.calledAfter @gotOutput
                expect(@checked).to.have.been.calledWithExactly(
                    @gotOutput.returnValues[0]
                )

            @checkDone = (err) ->
                @checkRanOnce()
                expect(@done).to.have.been.calledOnce
                expect(@done).to.have.been.calledWithExactly(err)
                expect(@done).to.have.been.calledOn(null)

        it "sets testObj.callback to complete the example (for Mocha timeouts)", ->
            ex = new Example(code: 'done = wait(); undefined', output:'')
            @runTest(ex)
            expect(@done).to.not.have.been.called
            expect(@testOb.callback).to.equal(done = @env.context.done)




        it "calls done() after running synchronous code", ->
            ex = new Example(code: '42', output:'42\n')
            @runTest(ex); @checkDone()
            expect(@checked).to.have.been.calledWithExactly('42\n')

        it "makes a distinct wait() available under opts.waitName", ->
            @runTest new Example(code: 'waitFn = wait; undefined', output:'')
            expect_fn(@env.context.waitFn)
            @runTest new Example(
                code: 'holdFn = hold; undefined', output:'', waitName:'hold'
            )
            expect_fn(@env.context.holdFn)

        it "doesn't call done() until async result is finished", ->
            ex = new Example(code: 'done = wait(); undefined', output:'')
            @runTest(ex)
            expect(@done).to.not.have.been.called
            @env.context.done()
            @checkDone()

        describe "only calls done() w/success once", ->

            it "when called synchronously", ->
                ex = new Example(code: 'done = wait(); done(); undefined', output:'')
                @runTest(ex)
                @env.context.done()
                @checkDone()

            it "when called asynchronously", ->
                ex = new Example(code: 'done = wait(); undefined', output:'')
                @runTest(ex)
                expect(@done).to.not.have.been.called
                @env.context.done()
                @env.context.done()
                @checkDone()






        it "forwards even late errors to done()", ->
            ex = new Example(code: 'done = wait(); undefined', output:'')
            @runTest(ex)
            expect(@done).to.not.have.been.called
            @env.context.done()
            @checkDone()
            @env.context.done(err=new Error)
            expect(@done).to.have.been.calledTwice
            expect(@done).to.have.been.calledWith(err)
            @checkRanOnce()

        it "records synchronous errors when waiting for async results", ->
                @runTest new Example(
                    code: 'done = wait(); throw new TypeError("bar")'
                    output: 'TypeError: bar\n'
                )
                expect(@done).to.not.have.been.called
                @env.context.done()
                @checkDone()


        describe "suppresses errors that match expected output", ->

            it "when thrown synchronously", ->
                @runTest new Example(
                    code: 'throw new TypeError("foo")'
                    output: 'TypeError: foo\n'
                )
                @checkDone()

            it "when sent asynchronously", ->
                @runTest new Example(
                    code: 'done = wait(); undefined', output: 'TypeError: foo\n'
                )
                expect(@done).to.not.have.been.called
                @env.context.done(new TypeError('foo'))
                @checkDone()




        describe "sends mismatch errors to done", ->

            beforeEach ->
                @checkDone = ->
                    @checkRanOnce()
                    expect(@done).to.have.been.calledOnce
                    expect(@done).to.have.been.calledWithExactly(
                        err = @checked.returnValues[0]
                    )
                    expect(@done).to.have.been.calledOn(null)
                    expect(err).to.be.instanceOf(Error)
                    expect(err.name).to.equal('Failed example')

            describe "when no errors were expected", ->

                it "at synchronous completion w/out error", ->
                    @runTest new Example(code: '42', output: '43\n')
                    @checkDone()

                it "at asynchronous completion w/out error", ->
                    @runTest new Example(
                        code: 'done = wait(); 42', output: '43\n'
                    )
                    expect(@done).to.not.have.been.called
                    @env.context.done()
                    @checkDone()

            describe "when errors were expected", ->

                it "at synchronous completion w/out error", ->
                    @runTest new Example(code: '42', output: 'Error: foo\n')
                    @checkDone()

                it "at asynchronous completion w/out error", ->
                    @runTest new Example(
                        code: 'done = wait(); 42', output: 'Error: foo\n'
                    )
                    expect(@done).to.not.have.been.called
                    @env.context.done()
                    @checkDone()

        describe "sends thrown/async errors to done()", ->

            describe "when no errors were expected", ->
                it "at synchronous completion w/error", ->
                    myErr = @env.context.myErr = new Error()
                    @runTest new Example(code: 'throw myErr', output:'42\n')
                    @checkDone(myErr)

                it "at asynchronous completion w/ error", ->
                    ex = new Example(code: 'done = wait(); undefined', output:'')
                    @runTest(ex)
                    expect(@done).to.not.have.been.called
                    @env.context.done(err = new Error())
                    @checkDone(err)

            describe "when errors were expected", ->
                it "at synchronous completion w/nonmatching error", ->
                    @runTest new Example(
                        code: 'throw err = new TypeError("foo")'
                        output: 'TypeError: bar\n'
                    )
                    @checkDone(err = @env.context.err)
                    expect(err).to.be.instanceOf(TypeError)
                    expect(err.message).to.equal 'foo'

                it "at asynchronous completion w/nonmatching error", ->
                    @runTest new Example(
                        code: 'done=wait(); undefined'
                        output: 'TypeError: bar\n'
                    )
                    @env.context.done(err = new TypeError('foo'))
                    @checkDone(err)
                    expect(err).to.be.instanceOf(TypeError)
                    expect(err.message).to.equal 'foo'







    describe ".onAdd(container)", ->

        it "sets .seq based on its position in container and returns itself", ->
            ex = new Example()
            expect(ex.seq).to.not.exist

            c = children: [42, 54]
            expect(ex.onAdd(c)).to.equal ex
            expect(ex.seq).to.equal 3

    describe ".register(suiteFn, testFn, env)", ->

        it "invokes testFn w/.getTitle() and a callback that runs .runTest()", (done) ->

            ex = new Example(title: 'foo', code: '42', output: '42\n')
            env = new Environment()
            gts = spy.named 'getTitle', ex, 'getTitle'
            rts = spy.named 'runTest', ex, 'runTest'
            testCb = spy.named 'done'

            suiteFn = -> done new Error("shouldn't have called suiteFn")

            testFn = spy.named 'testFn', (title, cb) ->
                expect(typeof cb).to.equal 'function'
                expect(cb.length).to.equal 1
                expect(rts).to.not.have.been.called
                expect(gts).to.have.been.calledOnce
                expect(title).to.equal gts.returnValues[0]
                testOb = {}
                ctx = runnable: -> testOb

                cb.call(ctx, testCb)
                expect(rts).to.have.been.calledOnce
                expect(rts).to.have.been.calledWithExactly(env, testOb, testCb)
                expect(testCb).to.have.been.calledOnce
                expect(testCb).to.have.been.calledWithExactly(undefined)

            ex.register(suiteFn, testFn, env)
            expect(testFn).to.have.been.calledOnce
            done()

        it "creates a pending test if .opts.skip is truthy", (done) ->

            ex = new Example(title: 'bar', skip: yes)
            env = new Environment()
            gts = spy.named 'getTitle', ex, 'getTitle'
            rts = spy.named 'runTest', ex, 'runTest'
            testCb = spy.named 'done'

            suiteFn = -> done new Error("shouldn't have called suiteFn")

            testFn = spy.named 'testFn', (title, cb) ->
                expect(arguments.length).to.equal 1
                expect(rts).to.not.have.been.called
                expect(gts).to.have.been.calledOnce
                expect(title).to.equal gts.returnValues[0]
                expect(rts).to.not.have.been.called

            ex.register(suiteFn, testFn, env)
            expect(testFn).to.have.been.calledOnce
            done()





















specifyContainer = ->

    describe ".add(child)", ->

        it "appends child.onAdd(this) to .children", ->
            expect(@c.children).to.deep.equal []
            @c.add(onAdd: s1 = spy.named 's1', -> 41)
            expect(s1).to.have.been.calledWithExactly(@c)
            @c.add(onAdd: s2 = spy.named 's2', -> 42)
            expect(s2).to.have.been.calledWithExactly(@c)
            @c.add(onAdd: s3 = spy.named 's3', -> 43)
            expect(s3).to.have.been.calledWithExactly(@c)
            expect(@c.children).to.deep.equal [41, 42, 43]

        it "returns this", ->
            expect(@c.add({onAdd:->this})).to.equal @c

    describe ".registerChildren(suiteFn, testFn, env)", ->

        beforeEach ->
            @env = new Environment
            @c.add(onAdd: (-> this), register: @s1 = spy.named 's1')
            @c.add(onAdd: (-> this), register: @s2 = spy.named 's2')
            @c.add(onAdd: (-> this), register: @s3 = spy.named 's3')

        it "invokes child.register(...) for each child in .children", ->
            @c.registerChildren((s = ->), (t = ->), @env)
            expect(@s1).to.have.been.calledWithExactly(s, t, @env)
            expect(@s2).to.have.been.calledWithExactly(s, t, @env)
            expect(@s3).to.have.been.calledWithExactly(s, t, @env)
            expect(@s2).to.have.been.calledAfter @s1
            expect(@s3).to.have.been.calledAfter @s2

        it "returns this", ->
            expect(@c.registerChildren((->), (->), @env)).to.equal @c






describe "mockdown.Section(title)", ->

    beforeEach -> @c = new Section("Section A")

    it "sets .title from the given title", ->
        expect(@c.title).to.equal('Section A')

    specifyContainer()

    describe ".onAdd(container)", ->

        it "returns this", ->
            @c.add(onAdd: -> this)
            expect(@c.onAdd(container = {})).to.equal @c

        describe "when it contains a single Example instance", ->
            beforeEach ->
                @c.add(@ex = new Example)
                @s1 = spy.named 'onAdd', @ex, 'onAdd'

            it "returns example.onAdd(container) in place of itself", ->
                expect(@c.onAdd(container = {children: []})).to.equal @ex
                expect(@s1).to.have.been.calledWithExactly(container)

            it "sets the example's title if not already set", ->
                @c.onAdd(container = {children: []})
                expect(@ex.title).to.equal 'Section A'

            it "leaves the title alone if already set", ->
                @ex.title = 'First Example'
                @c.onAdd(container = {children: []})
                expect(@ex.title).to.equal 'First Example'









    describe ".register(suiteFn, testFn, env)", ->

        it "calls suiteFn(.title, callback to .registerChildren)", (done) ->

            env = new Environment()
            rc = spy.named 'registerChildren', @c, 'registerChildren'

            suiteFn = spy.named 'suiteFn', (title, cb) =>
                expect(typeof cb).to.equal 'function'
                expect(cb.length).to.equal 0
                expect(rc).to.not.have.been.called
                expect(title).to.equal @c.title
                cb()
                expect(rc).to.have.been.calledOnce
                expect(rc).to.have.been.calledWithExactly(suiteFn, testFn, env)

            testFn = -> done new Error("shouldn't have called suiteFn")
            @c.register(suiteFn, testFn, env)
            expect(suiteFn).to.have.been.calledOnce
            done()





















describe "mockdown.Document(opts)", ->

    beforeEach -> @c = new Document @o = new Options @a = globals: foo: 'bar'

    describe "sets .opts from the given opts", ->
        it "when passed an Options object", ->
            expect(@c.opts).to.be.instanceOf(Options).and.not.equal(@o)
            expect(@c.opts).to.deep.equal(@o)
        it "when passed a plain object", ->
            d = new Document(@a)
            expect(d.opts).to.be.instanceOf(Options).and.not.equal(@o)
            expect(d.opts).to.deep.equal(@o)

    specifyContainer()

    describe ".register(suiteFn, testFn)", ->

        it "passes along an optional env to .registerChildren()", ->
            env = new Environment
            rc = spy.named 'registerChildren', @c, 'registerChildren'
            sf = spy.named 'suiteFn'
            tf = spy.named 'testFn'
            @c.register(sf, tf, env)
            expect(sf).to.not.have.been.called
            expect(tf).to.not.have.been.called
            expect(rc).to.have.been.calledOnce
            expect(rc).to.have.been.calledWithExactly(sf, tf, env)

        it "creates an env using .opts.globals", ->
            rc = spy.named 'registerChildren', @c, 'registerChildren'
            sf = spy.named 'suiteFn'
            tf = spy.named 'testFn'
            @c.register(sf, tf)
            expect(sf).to.not.have.been.called
            expect(tf).to.not.have.been.called
            expect(rc).to.have.been.calledOnce
            env = rc.args[0][2]
            expect(rc).to.have.been.calledWithExactly(sf, tf, env)
            expect(env).to.be.an.instanceOf(Environment)
            expect(env.context.foo).to.exist.and.equal 'bar'

describe "mockdown.lex(src)", ->

    check = (src, out) -> lex(src).should.eql(out)

    it "assigns line numbers", -> check """\
        # Heading

        para
        """, [
          {type:'heading', depth:1, text: 'Heading', line:1}
          {type:'paragraph', text:'para', line:3}
        ]

    it "nests blockquotes", -> check """\
        > Text.
        >
        >     code()
        """, [{
          type: 'blockquote', line: 1, children: [
            {type: 'paragraph', text: 'Text.', line: 1}
            {type: 'code', text: 'code()', line: 3}
          ]
        }]

    it "tracks the original whitespace in a blockquote", -> check """\
        >     Sample
        >
        >     Output
        >
    """, [
        type: 'blockquote', line: 1, children: [
            type: 'code', line:1, text: 'Sample\n\nOutput\n'
        ]
    ]







    it "works around marked.Lexer ignoring single blank lines", -> check """\
        <!-- foo -->

        bar
        """, [
          {type: 'html', text: '<!-- foo -->\n', pre:no, line:1}
          {type: 'paragraph', text:'bar', line:3}
        ]

    it "nests lists and list items (w/o line numbers)", -> check """\
        - Outer list
          - Inner list
          - More
        - Stuff
        """, [{
          type: 'list', line: 1, ordered: no, children: [
            {type: 'list_item', children: [
              {type: 'text', text: 'Outer list'}
              {type: 'list', ordered: no, children: [
                {type: 'list_item', children: [
                  {type: 'text', text: 'Inner list'}
                ]}
                {type: 'list_item', children: [
                  {type: 'text', text: 'More'}
                ]}
              ]}
            ]}
            {type: 'list_item', children: [
              {type: 'text', text: 'Stuff'}
            ]}
          ]
        }]

    it "parses mockdown directives"







