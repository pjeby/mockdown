{assign} = require 'prop-schema'

module.exports = ->
    babel:
        options:
            retainLines: yes
        module: '@babel/core'
        toJS: (example, line) ->
            options = assign {}, @options
            options.filename = example.filename
            code = example.offset(line)
            code = require(@module).transform(code, options).code
            code = example.offset(line, code) unless options.retainLines
            return code

    es6: "babel"

    coffee:
        options:
            bare: yes
            header: no
        module: "coffeescript"
        toJS: (example, line) ->
            options = assign {}, @options
            options.filename = example.filename
            return example.offset(
                line,
                require(@module).compile(example.offset(line), options)
            )
    "coffee-script": "coffee"
    "coffeescript": "coffee"

    javascript: toJS: (example, line) -> example.offset(line)
    js: "javascript"

    html: "ignore"
    markdown: "ignore"
    text: "ignore"
    ignore: "ignore"

