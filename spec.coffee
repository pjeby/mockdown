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

    beforeEach ->
        @waiter = new Waiter(@spy = spy.named 'done')

    describe "calls cb() with null context", ->
        it "when .done()"
        it "when .done(err)"

    describe ".finished", ->
        it "is initially false if a callback is given"
        it "is true immediately if no callback is given"
        it "becomes true as soon as done() is called"

    describe ".waiting", ->
        it "is initially false"
        it "is set to false as soon as done() is called"

    describe ".waitThenable()", ->
        it "returns its argument"
        it "invokes @done when the thenable resolves"
        it "forwards thenable errors to @done"
        it "marks the waiter as waiting"
        it "throws an error if already finished"

    describe ".waitPredicate(pred, interval)", ->
        it "calls pred after the timeout"
        it "calls pred repeatedly"
        it "uses the timeout value given"
        it "returns a timeout that can be canceled"
        it "forwards predicate() errors to @done"
        it "marks the waiter as waiting"
        it "throws an error if already finished"

    describe ".wait()", ->
        it "returns the .done method"
        it "marks the waiter as waiting"
        it "throws an error if already finished"



    describe ".wait(number)", ->
        it "returns .waitPredicate(->yes, number)"

    describe ".wait(number, function)", ->
        it "returns .waitPredicate(function, number)"

    describe ".wait(function)", ->
        it "returns .waitPredicate(function)"

    describe ".wait(thenable) returns thenable", ->
        it "when thenable is an object"
        it "when thenable is a function"

    describe ".wait(anything else)", ->
        it "throws a TypeError"


























describe "mockdown.Environment(globals)", ->

    beforeEach ->
        @env = new Environment(x:1, y:2)

    describe ".run(code, opts)", ->
        it "returns the result"
        it "throws any syntax errors"
        it "throws any runtime errors"
        it "sets the filename"

    describe ".getOutput()", ->
        it "returns all log/dir/warn/error text from .context.console"
        it "accumulates output until called"
        it "resets after each call"

    describe ".context variables", ->
        it "include the globals used to create the environment"
        it "are readable by run() code"
        it "are writable by run() code"
        it "can be defined by run() code"




















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







