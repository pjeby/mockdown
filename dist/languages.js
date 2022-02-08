var assign;

assign = require('prop-schema').assign;

module.exports = function() {
  return {
    babel: {
      options: {
        retainLines: true
      },
      module: 'babel-core',
      toJS: function(example, line) {
        var code, options;
        options = assign({}, this.options);
        options.filename = example.filename;
        code = example.offset(line);
        code = require(this.module).transform(code, options).code;
        if (!options.retainLines) {
          code = example.offset(line, code);
        }
        return code;
      }
    },
    es6: "babel",
    coffee: {
      options: {
        bare: true,
        header: false
      },
      module: "coffee-script",
      toJS: function(example, line) {
        var options;
        options = assign({}, this.options);
        options.filename = example.filename;
        return example.offset(line, require(this.module).compile(example.offset(line), options));
      }
    },
    "coffee-script": "coffee",
    "coffeescript": "coffee",
    javascript: {
      toJS: function(example, line) {
        return example.offset(line);
      }
    },
    js: "javascript",
    html: "ignore",
    markdown: "ignore",
    text: "ignore",
    ignore: "ignore"
  };
};
