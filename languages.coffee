{assign} = require 'prop-schema'

module.exports = ->

    babel:
        options:
            retainLines: yes
        toJS: (example) ->
            options = assign {}, @options
            options.filename = example.filename
            return require('babel').transform(example.offset(), options).code

    es6: "babel"
    
    "coffee-script":
        options:
            bare: yes
            header: no
        toJS: (example) ->
            options = assign {}, @options
            options.filename = example.filename
            return example.offset(
                require('coffee-script').compile(example.offset(), options)
            )

    "coffee": "coffee-script"
    "coffeescript": "coffee-script"

    javascript:
        toJS: (example) -> example.offset()
    js: "javascript"

    html: "ignore"
    markdown: "ignore"
    text: "ignore"
    ignore: "ignore"

