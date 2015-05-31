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

{lex, Document, Section, Example, Environment, Console} = require './'
























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









