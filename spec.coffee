{expect, should} = chai = require 'chai'
should = should()
chai.use require 'sinon-chai'

expect_fn = (item) -> expect(item).to.exist.and.be.a('function')

{spy, stub} = sinon = require 'sinon'
same = sinon.match.same

spy.named = (name, args...) ->
    s = if this is spy then spy(args...) else this
    s.displayName = name
    return s

withSpy = (ob, name, fn) ->
    s = spy.named name, ob, name
    try fn(s) finally s.restore()

failSafe = (done, fn) -> ->
    try fn.apply(this, arguments)
    catch e then done(e)

{lex, Parser, Section, Example, Environment, Document, Waiter} = require './'
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
















checkDefaults = (cls, isDocument=no) ->

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

        # Don't test internal props on Document
        return if isDocument and k in ['title', 'code', 'output', 'line']

        describe ".#{k} = #{util.inspect(dflt)}", ->
            it "when overwritten", ->
                expect(new cls("#{k}": alt)[k]).to.deep.equal(alt)
            it "when unsupplied", ->
                expect(new cls({})[k]).to.deep.equal(dflt)
            it "when no options given", ->
                expect(new cls()[k]).to.deep.equal(dflt)












describe "mockdown.Example(opts...)", ->

    describe "gets properties from opts, including", ->
        checkDefaults Example

    describe "argument validation", ->

        it "requires opts to be a plain Object, Document, or Example", ->
            expect(new Example new Document).to.eql new Example
            expect(new Example new Example).to.eql new Example
            expect(-> new Example new class Foo)
            .to.throw /must be plain Object/

        it "rejects invalid keys in opts", ->
            expect(-> new Example {x: 'y'})
            .to.throw /Unknown property: x/

        describe "allows empty arguments", ->

            it "by omission", ->
                expect(new Example).to.deep.equal new Example {}

            it "by passing null", ->
                expect(new Example null, null).to.deep.equal new Example {}

            it "by passing undefined", ->
                expect(new Example undefined, undefined)
                .to.deep.equal new Example {}













    describe ".mismatch(output)", ->
        mismatch = (opts, output) -> new Example(opts).mismatch(output)

        it "returns an untrue value if output matches .output", ->
            expect(!!new Example(output:'x').mismatch('x')).to.be.false

        it "normalizes whitespace when .ignoreWhitespace"
        it "treats .ellipsis as a wildcard when set"

        describe "returns an error object for mismatches, that", ->

            it "has .actual and .expected line-list properties", ->
                err = mismatch(output:'x\ny', 'y\nz')
                expect(err.name).to.equal('Failed example')
                expect(err).to.be.instanceOf(Error)
                expect(err.actual).to.deep.equal ['y','z']
                expect(err.expected).to.deep.equal ['x','y']

            it "has actual/expected in .message if .showOutput", ->
                expect(mismatch(
                    code:'foo()\nbar()', output:'a\nb', showOutput: no, 'b\nc'
                ).message).to.equal('')
                err = mismatch(code:'foo()\nbar()', output:'a\nb', 'b\nc')
                expect(err.message.split('\n')).to.deep.equal [
                    '', 'Code:', '    foo()', '    bar()'
                    'Expected:', '>     a', '>     b'
                    'Got:',      '>     b', '>     c'
                ]

            it "has a true .showDiff if .showDiff", ->
                expect(mismatch(output:'x\ny', 'y\nz').showDiff).to.be.false
                expect(mismatch(output:'x\ny', showDiff: yes, 'y\nz').showDiff)
                .to.be.true

            it "has a stack that includes .filename:.line", ->
                err = new Example(
                    output:'x\ny', line:55, filename:'foo.md', showOutput:no
                ).mismatch('y\nz')
                expect(err.stack.split('\n')[1])
                .to.equal "  at Example (foo.md:55)"

    describe ".evaluate(env, params)", ->

        evaluate = (opts, env=new Environment, params) ->
            o = new Example(opts)
            if arguments.length>2
                return o.evaluate(env, params)
            return o.evaluate(env)

        it "runs .code in env, returning the result", ->
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

        it "makes params.wait available under .waitName, if set", ->
            expect(evaluate(code:'wait', null, wait:42)).to.equal 42
            expect(evaluate(code:'hold', waitName: 'hold', null, wait:42))
            .to.equal 42


        it "makes params.test available under .testName, if set", ->
            expect(evaluate(code:'test', null, test:99)).to.equal 99
            expect(evaluate(code:'example', testName: 'example', null, test:99)
            ).to.equal 99







    describe ".writeError(env, err)", ->

        getError = (stackDepth, err) ->
            new Example({stackDepth}).writeError(env = new Environment, err)
            return env.getOutput()

        it "writes err.stack to env's console", ->
            expect(getError(Infinity, err = new Error("message")).split('\n'))
            .to.deep.equal (err.stack+'\n').split('\n')

        it "trims the stack to .stackDepth lines", ->
            expect(getError(1, err = new Error("message\n1\n2")).split('\n'))
            .to.deep.equal err.stack.split('\n').slice(0, 4).concat([''])




























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
                @evaled = spy.named 'evaluate', @ex, 'evaluate'
                @checked = spy.named 'mismatch', @ex, 'mismatch'
                @ex.runTest(@env, @testOb, @done)

            @checkRanOnce = ->
                expect(@evaled).to.have.been.calledOnce
                expect(@evaled).to.have.been.calledWith(@env)
                expect(@evaled).to.have.been.calledOn(@ex)
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

        it "makes a distinct wait() available under .waitName", ->
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

        it "creates a pending test if .skip is truthy", (done) ->

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






describe 'mockdown.Section({title:"..."})', ->

    beforeEach -> @c = new Section(title: "Section A")

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

    beforeEach -> @c = new Document @o = new Example @a = globals: foo: 'bar'

    describe "gets its properties from opts, including", ->
        checkDefaults(Document, yes)

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

        it "creates an env using .globals", ->
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







describe "mockdown.Parser(docOrOpts)", ->

    beforeEach -> @p = new Parser(@d = new Document)

    describe ".doc", ->

        it "is docOrOpts if Document", ->
            expect(@p.doc).to.equal @d

        it "gets properties from opts... otherwise", ->
            expect(new Parser({filename: 'foo.md'}, {stackDepth:20}).doc)
            .to.deep.equal new Document(filename: 'foo.md', stackDepth: 20)

    describe ".directiveEnv(docOrEx, allowed) returns an Environment", ->

        beforeEach ->
            @d = new Document
            @e = @p.directiveEnv(@d, {stackDepth: null, ellipsis: null})
            @c = @e.context

        it "with allowed subset of options mapped as globals", ->
            for tgt in ['c', 'd']
                for [prop, values] in [
                    ['stackDepth', [99,42,55]]
                    ['ellipsis', ['foo', 'bar', 'baz']]
                ] then for v in values
                    @[tgt][prop] = v
                    @c[prop].should.equal v, "c after setting #{tgt}.#{prop}"
                    @d[prop].should.equal v, "d after setting #{tgt}.#{prop}"

        it "with disallowed options raising an error", ->
            msg = " can only be accessed via mockdown-setup"
            (=> @c.globals).should.throw(TypeError, "globals" + msg)
            (=> @c.skip = true).should.throw(TypeError, "skip" + msg)







    describe ".directive(docOrEx, code, line, specs)", ->

        beforeEach -> @p = new Parser(@d = new Document)

        it "defaults to not allowing global specs", ->
            (=> @p.directive(@d, 'globals')).should.throw(
                TypeError, "globals can only be accessed via mockdown-setup"
            )
            @p.directive(@d, 'globals', 1, {globals: null})
            .should.equal @d.globals

        it "runs code w/filename and line number", ->
            my = this
            de = stub @p, 'directiveEnv', ->
                e = Parser::directiveEnv.apply(this, arguments)
                my.r = spy.named 'run', e, 'run'
                return e
            @p.directive(e=new Example, '1', 5, s={skip:null})
            de.should.have.been.calledOnce
            de.should.have.been.calledWithExactly(same(e), same(s))
            @r.should.have.been.calledOnce
            @r.should.have.been.calledWithExactly(
                '\n\n\n\n1', {filename:@d.filename}
            )

        it "code can modify boolean opts using ++ and --", ->
            e = new Example()
            e.ignore.should.be.false
            @p.directive(e, '++ignore')
            e.ignore.should.be.true
            @p.directive(e, '--ignore')
            e.ignore.should.be.false

        it "code can modify options by assignment", ->
            @d.ellipsis.should.equal '...'
            @p.directive(@d, "ellipsis='foo'")
            @d.ellipsis.should.equal 'foo'




    describe "Matching Functions", ->

        describe ".match(tok, predicate)", ->

            describe "with string predicate", ->
                it "returns tok if tok.type === predicate", ->
                    expect(@p.match(tok = type: 'foo', 'foo')).to.equal tok

                it "returns undefined otherwise", ->
                    expect(@p.match(type: 'foo', 'bar')).not.to.exist

            describe "with array predicate", ->
                it "invokes .match() recursively for each element", ->
                    withSpy @p, 'match', (m) =>
                        res = @p.match(tok = type: 'baz', ['foo', 'bar'])
                        expect(res).not.to.exist
                        m.should.have.been.calledThrice
                        m.should.have.been.calledWithExactly(same(tok), 'foo')
                        m.should.have.been.calledWithExactly(same(tok), 'bar')

                it "returns tok if any element matched", ->
                    res = @p.match(tok = type: 'baz', ['foo', 'baz'])
                    expect(res).to.equal tok

                it "returns undefined otherwise", ->
                    res = @p.match(tok = type: 'bar', ['foo', 'baz'])
                    expect(res).to.not.exist

        describe ".matchDeep(tok, pred, subpreds...)", ->
            it "returns undefined unless .match(tok, pred)", ->
                expect(@p.matchDeep(tok=type:'foo', 'foo')).to.equal tok
                expect(@p.matchDeep(tok=type:'foo', ['bar'])).to.not.exist

            it "returns undefined if tok has more than one child", ->
                tok = type: 'foo', children: [{type:'a'}, {type:'b'}]
                expect(@p.matchDeep(tok, 'foo', 'a')).to.not.exist

            it "returns recursive sub-match of predicate's child", ->
                t1 = type: 'foo', children: [t2=type:'bar']
                expect(@p.matchDeep(t1, 'foo', 'bar')).to.equal t2

        describe ".matchDirective(tok)", ->

            before -> @md = (text, line=1) =>
                @p.matchDirective {text, line, type: 'html'}

            it "rejects non-HTML tokens", ->
                expect(@p.matchDirective type:'bar').to.not.exist

            it "rejects tokens w/out '<!--' and 'mockdown' ", ->
                expect(@md('<!-- -->')).to.not.exist

            it "throws a SyntaxError for malformed directives", ->
                for bad in [
                    '<!-- mockdown -->  blah'
                    'blah <!-- mockdown: foo -->'
                    '<!-- mockdown-foo: bar -->'
                ]
                    (=> @md(bad))
                    .should.throw SyntaxError, "malformed mockdown directive"

                    try @md('\n'+bad, 5) catch err
                        expect(err.stack.split('\n')[1])
                        .to.equal "  at (<anonymous>:6)"

            it "calculates the correct line number for embedded code", ->
                expect(@md("<!-- mockdown: x-->").line).to.equal 1
                expect(@md("\n<!-- mockdown: x-->").line).to.equal 2
                expect(@md("\n<!-- \nmockdown: x-->").line).to.equal 3

            it "resets the token type according to directive type", ->
                for kind in ['mockdown', 'mockdown-set', 'mockdown-setup']
                    expect(@md("<!-- #{kind}: x -->").type).to.equal kind

            it "resets the token text to the directive content", ->
                expect(@md("<!-- mockdown:whee-->").text).to.equal 'whee'






    describe "Parsing Functions", ->

        describe ".parseDirective(tok, haveDirective)", ->
            it "rejects tokens that fail .matchDirective()"
            it "only accepts plain 'mockdown' directives if haveDirective"

            describe "when directive is 'mockdown'", ->
                it "invokes .directive(.setExample(), tok.text, tok.line)"
                it "returns .HAVE_DIRECTIVE state and sets .started"

            describe "when directive is 'mockdown-set'", ->
                it "invokes .directive(.doc, tok.text, tok.line)"
                it "returns .SCAN state and sets .started"

            describe "when directive is 'mockdown-setup'", ->
                it "throws an error if already .started"
                it "invokes .directive(.doc, tok.text, tok.line, specs)"
                it "with specs that permit global options to be set"
                it "returns .SCAN state and sets .started"

        describe ".parseTitle(tok)", ->
            it "rejects tokens without the appropriate children"
            it "invokes .setExample(title:) with the nested text"
            it "returns .SCAN on success"

        describe ".parseHeading(tok)", ->
            it "rejects non-headings"
            it "sets .current to a new Section with a title"

        describe ".parseCode(tok)", ->
            it "rejects non-code tokens"
            it "calls .setExample(code: tok.text, line: tok.line)"
            it "sets example .language if supplied"
            it "returns .HAVE_CODE state and sets .started"







    describe "Parser States", ->

        describe ".SCAN(tok)", ->
            it "accepts any directive and returns .HAVE_DIRECTIVE"
            it "accepts code and returns .HAVE_CODE"
            it "accepts titles and returns .SCAN"
            it "accepts headings and returns .SCAN"
            it "returns .SCAN for everything else"

        describe ".HAVE_DIRECTIVE(tok)", ->
            it "accepts plain directives and returns .HAVE_DIRECTIVE"
            it "accepts code and returns .HAVE_CODE"
            it "throws a SyntaxError for anything else"

        describe ".HAVE_CODE(tok)", ->
            it "accepts output and adds it to the example"
            it "adds .example to the current doc or section"
            it "clears the current .example"
            it "returns .SCAN(tok)"

    describe "State Management", ->

        describe ".syntaxError(line, message)", ->

            it "returns an error with file and line in its .stack", ->
                @d.filename = 'bar.md'
                err = @p.syntaxError(42, "what\nup")
                expect(err.stack.split('\n')[2]).to.equal "  at (bar.md:42)"
                expect(err.message).to.equal 'what\nup'


        describe ".setExample(props)", ->
            it "returns an Example that === .example"
            it "has the specified properties"
            it "updates an existing .example if found"
            it "creates a new .example if empty"

    describe "Headings (.parseHeading(tok) and .finishHeadings())", ->



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









