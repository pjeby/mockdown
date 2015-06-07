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

{lex, Section, Example, Environment, Document, Waiter} = require './'
























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

            afterEach -> expect(typeof foobly).to.equal "undefined"

            it "simple assignment", -> expect(@env.run('foobly=1')).to.equal(1)

            it "var declaration", -> expect(@env.run(
                'var q, foobly=2; foobly'
            )).to.equal(2)

            it "nested assignment", -> expect(@env.run(
                'function q(){ return foobly=3;}; q()'
            )).to.equal(3)

            it "function declaration", -> expect(@env.run(
                'function foobly() { return 4; }; foobly()'
            )).to.equal(4)

            it "conditional declaration", -> expect(@env.run(
                'if (1) function foobly() { return 5; }; foobly()'
            )).to.equal(5)

            it "strict mode assignment", -> expect(@env.run(
                'function x() { "use strict"; foobly=6; }; x(); foobly'
            )).to.equal(6)

            it "global.property assignment", -> expect(@env.run(
                'global.foobly = 7; foobly'
            )).to.equal(7)

            it "`this` assignment", ->
                expect(@env.run('this.foobly = 8; foobly')).to.equal(8)









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







