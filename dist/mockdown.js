var Container, bool, document_specs, empty, example_specs, infinInt, injectStack, int, languages, maybe, mdast, mkArray, mockdown, object, offset, pattern, posInt, props, recursive, ref, reformatCode, splitLines, storage_opts, string, toMarked,
  extend = function(child, parent) { for (var key in parent) { if (hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; },
  hasProp = {}.hasOwnProperty,
  bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; },
  slice = [].slice;

mockdown = exports;

mockdown.testFiles = function(paths, suiteFn, testFn, options) {
  var j, len, path, results;
  results = [];
  for (j = 0, len = paths.length; j < len; j++) {
    path = paths[j];
    results.push(mockdown.parseFile(path, options).register(suiteFn, testFn));
  }
  return results;
};

mockdown.Environment = require('mock-globals').Environment;

ref = props = require('prop-schema'), string = ref.string, object = ref.object, empty = ref.empty;

bool = props.integer.and(function(v) {
  return v > 0;
}).or(props.boolean);

int = props.integer.and(props.nonNegative);

posInt = props.integer.and(props.positive);

maybe = function(t) {
  return empty.or(t);
};

infinInt = int.or(props.check("must be integer or Infinity", function(v) {
  return v === 2e308;
}));

mkArray = props.type(function(val) {
  if (val == null) {
    val = [];
  }
  return [].concat(val);
});

splitLines = function(txt) {
  return txt.split(/\r\n?|\n\r?/g);
};

offset = function(line, code) {
  return Array(line).join('\n') + code;
};

injectStack = function(err, txt, replace) {
  var stack;
  if (replace == null) {
    replace = false;
  }
  stack = splitLines(err.stack);
  stack.splice(splitLines(err.message).length, (replace ? stack.length : 0), txt);
  err.stack = stack.join('\n');
  return err;
};

storage_opts = {
  descriptorFor: function(name, spec) {
    name = name + '_';
    return {
      get: function() {
        return this[name];
      },
      set: function(v) {
        return this[name] = spec.convert(v);
      },
      enumerable: true,
      configurable: true
    };
  },
  setupStorage: function() {}
};

recursive = props.compose(object.and(function(v) {
  var j, k, len, ref1;
  ref1 = Object.keys(v);
  for (j = 0, len = ref1.length; j < len; j++) {
    k = ref1[j];
    if (props.isPlainObject(v[k])) {
      v[k] = recursive(v[k]);
    }
  }
  return v;
}));

pattern = props["function"].or(function(val) {
  if (typeof val === "string") {
    return function(arg) {
      return ~arg.indexOf(val);
    };
  } else if (val instanceof RegExp) {
    return function(arg) {
      return arg.match(val);
    };
  } else {
    return props.check("must be string, function, or regexp").converter(val);
  }
});

languages = require('./languages')();

example_specs = {
  ellipsis: empty.or(string)('...', "wildcard for output matching"),
  ignoreWhitespace: bool(false, "normalize whitespace for output mathching?"),
  showCompiled: bool(false, "show compiled code in errors"),
  showOutput: bool(true, "show expected/actual output in errors"),
  showDiff: bool(false, "use mocha's diffing for match errors"),
  stackDepth: infinInt(0, "max # of stack trace lines in error output"),
  skip: bool(false, "mark the test pending?"),
  ignore: bool(false, "treat the example as a non-test"),
  waitForOutput: maybe(pattern)(void 0, "output to stop on"),
  waitName: maybe(string)('wait', "name of 'wait()' function"),
  testName: maybe(string)('test', "name of current mocha test object"),
  printResults: bool(false, "output the result of evaluating each example"),
  ingoreUndefined: bool(true, "don't output undefined results"),
  writer: maybe(props["function"])(void 0, "function used to format results"),
  defaultLanguage: maybe(string)("javascript", "language to use for code without an explicit language")
};

document_specs = props.assign({}, example_specs, {
  filename: string('<anonymous>', "filename for stack traces"),
  globals: object({}, "global vars for examples"),
  languages: props.type(recursive)(languages, "language specs")
});

Container = (function() {
  var ctor;

  function Container() {
    return ctor.apply(this, arguments);
  }

  props(Container, {
    children: mkArray(void 0, "contained items")
  }, storage_opts);

  ctor = props.Base;

  Container.prototype.add = function(child) {
    var c;
    if ((c = child.onAdd(this)) != null) {
      this.children.push(c);
    }
    return this;
  };

  Container.prototype.registerChildren = function(suiteFn, testFn, env) {
    var child, j, len, ref1;
    ref1 = this.children;
    for (j = 0, len = ref1.length; j < len; j++) {
      child = ref1[j];
      child.register(suiteFn, testFn, env);
    }
    return this;
  };

  return Container;

})();

mockdown.Document = (function(superClass) {
  extend(Document, superClass);

  function Document() {
    return Document.__super__.constructor.apply(this, arguments);
  }

  props(Document, document_specs);

  Document.prototype.getEngine = function(lang) {
    var info;
    info = this.languages[lang.toLowerCase()];
    if (typeof info === "string") {
      info = this.languages[info.toLowerCase()];
    }
    return info;
  };

  Document.prototype.register = function(suite, test, env) {
    if (env == null) {
      env = new mockdown.Environment(this.globals);
    }
    return this.registerChildren(suite, test, env);
  };

  return Document;

})(Container);

mockdown.Section = (function(superClass) {
  extend(Section, superClass);

  function Section() {
    return Section.__super__.constructor.apply(this, arguments);
  }

  props(Section, {
    title: maybe(string)(void 0, "section title"),
    level: posInt(1, "heading level")
  });

  Section.prototype.onAdd = function(container) {
    var child;
    if (this.children.length === 1 && (child = this.children[0]) instanceof mockdown.Example && (child.getTitle(true) == null)) {
      child.title = this.title;
      return child.onAdd(container);
    } else if (this.children.length) {
      return this;
    }
  };

  Section.prototype.register = function(suiteFn, testFn, env) {
    return suiteFn(this.title, (function(_this) {
      return function() {
        return _this.registerChildren(suiteFn, testFn, env);
      };
    })(this));
  };

  return Section;

})(Container);

mockdown.Builder = (function() {
  function Builder(container1) {
    this.container = container1;
    this.stack = [];
  }

  Builder.prototype.startSection = function(level, title) {
    var ref1;
    while (level <= ((ref1 = this.container.level) != null ? ref1 : -1)) {
      this.endSection();
    }
    this.stack.push(this.container);
    this.container = new mockdown.Section({
      level: level,
      title: title
    });
    return this;
  };

  Builder.prototype.addExample = function(e) {
    this.container.add(e);
    return this;
  };

  Builder.prototype.endSection = function() {
    this.container = this.stack.pop().add(this.container);
    return this;
  };

  Builder.prototype.end = function() {
    while (this.stack.length) {
      this.endSection();
    }
    return this.container;
  };

  return Builder;

})();

mockdown.Example = (function() {
  var number;

  props(Example, example_specs, storage_opts);

  props(Example, {
    filename: document_specs.filename,
    engine: props.spec(languages.javascript, "language engine to use"),
    line: maybe(posInt)(void 0, "line number for stack traces"),
    code: maybe(string)(void 0, "code of the test"),
    output: string('', "expected output"),
    seq: maybe(int)(void 0, "an example's sequence #"),
    title: maybe(string)(void 0, "title of the test")
  });

  function Example() {
    props.Base.apply(this, arguments);
  }

  Example.prototype.onAdd = function(container) {
    this.seq = container.children.length + 1;
    return this;
  };

  Example.prototype.register = function(suiteFn, testFn, env) {
    var my;
    if (this.skip) {
      return testFn(this.getTitle());
    } else {
      my = this;
      return testFn(this.getTitle(), function(done) {
        return my.runTest(env, this.runnable(), done);
      });
    }
  };

  Example.prototype.getTitle = function(explicit) {
    var m, ref1;
    if (explicit == null) {
      explicit = false;
    }
    if (this.title != null) {
      return this.title;
    }
    if (m = (ref1 = this.code) != null ? ref1.match(/^\s*(\/\/|#|--|%)\s*([^\n]+)/) : void 0) {
      return m[2].trim();
    }
    if (!explicit) {
      if (this.seq) {
        return "Example " + this.seq + (this.line ? ' at line ' + this.line : '');
      } else {
        return "Example";
      }
    } else {
      return void 0;
    }
  };

  Example.prototype.runTest = function(env, testObj, done) {
    var e, finished, waiter;
    finished = false;
    waiter = new mockdown.Waiter((function(_this) {
      return function(err) {
        var matchErr;
        if (finished) {
          if (err) {
            return done(err);
          }
        } else {
          finished = true;
          if (_this.waitForOutput) {
            _this.unwatch(env);
          }
          if (err) {
            _this.writeError(env, err);
          }
          matchErr = _this.mismatch(env.getOutput());
          if (!matchErr) {
            return done.call(null, void 0);
          } else if (err == null) {
            return done.call(null, matchErr);
          } else {
            matchErr.originalError = err;
            return done.call(null, injectStack(matchErr, err.stack, true));
          }
        }
      };
    })(this));
    testObj.callback = waiter.done;
    try {
      if (this.waitForOutput) {
        this.watch(env, this.waitForOutput, waiter.wait());
      }
      this.evaluate(env, {
        wait: waiter.wait,
        test: testObj
      });
      if (!waiter.waiting) {
        return waiter.done();
      }
    } catch (error) {
      e = error;
      if (waiter.waiting) {
        return this.writeError(env, e);
      } else {
        return waiter.done(e);
      }
    }
  };

  Example.prototype.watch = function(env, pred, done) {
    var os;
    pred = pattern.converter(pred);
    os = env.outputStream;
    return os.write = (function(_this) {
      return function(arg) {
        os.push(arg);
        if (pred(arg.toString())) {
          _this.unwatch(env);
          return process.nextTick(done);
        }
      };
    })(this);
  };

  Example.prototype.unwatch = function(env) {
    var os;
    os = env.outputStream;
    return os.write = os.push;
  };

  number = function(line, text) {
    line = "      " + (+line) + " | " + text;
    return line.substr(-(9 + text.length));
  };

  Example.prototype.mismatch = function(output) {
    var actual, code, err, expected, i, j, l, len, len1, len2, msg, n, o, ref1, ref2, ref3;
    if (output === this.output) {
      return;
    }
    msg = [''];
    if (this.showOutput) {
      code = this.showCompiled ? this.toJS(1) : this.code;
      msg.push('Code:');
      ref1 = splitLines(code != null ? code : '');
      for (i = j = 0, len = ref1.length; j < len; i = ++j) {
        l = ref1[i];
        msg.push(this.line != null ? number(i + this.line, l) : '    ' + l);
      }
      msg.push('Expected:');
      ref2 = expected = splitLines(this.output);
      for (n = 0, len1 = ref2.length; n < len1; n++) {
        l = ref2[n];
        msg.push('>     ' + l);
      }
      msg.push('Got:');
      ref3 = actual = splitLines(output);
      for (o = 0, len2 = ref3.length; o < len2; o++) {
        l = ref3[o];
        msg.push('>     ' + l);
      }
    }
    err = new Error(msg.join('\n'));
    err.name = 'Failed example';
    err.showDiff = this.showDiff;
    err.expected = expected;
    err.actual = actual;
    return injectStack(err, "  at Example (" + this.filename + ":" + this.line + ")");
  };

  Example.prototype.offset = function(line, code) {
    if (line == null) {
      line = this.line;
    }
    if (code == null) {
      code = this.code;
    }
    return offset(line, code);
  };

  Example.prototype.toJS = function(line) {
    if (line == null) {
      line = this.line;
    }
    return this.engine.toJS(this, line);
  };

  Example.prototype.evaluate = function(env, params) {
    var j, k, len, name, ref1;
    if (params) {
      ref1 = Object.keys(params);
      for (j = 0, len = ref1.length; j < len; j++) {
        k = ref1[j];
        if (name = this[k + "Name"]) {
          env.context[name] = params[k];
        }
      }
    }
    return env.run(this.toJS(), this);
  };

  Example.prototype.writeError = function(env, err) {
    var msgLines, stack;
    msgLines = splitLines(err.message).length;
    stack = splitLines(err.stack).slice(0, this.stackDepth + msgLines);
    return env.context.console.error(stack.join('\n'));
  };

  return Example;

})();

mockdown.Waiter = (function() {
  function Waiter(callback) {
    this.callback = callback;
    this.wait = bind(this.wait, this);
    this.done = bind(this.done, this);
    this.finished = this.waiting = false;
  }

  Waiter.prototype.done = function() {
    this.finished = true;
    this.waiting = false;
    return this.callback.apply(null, arguments);
  };

  Waiter.prototype._startWaiting = function() {
    if (this.finished) {
      throw new Error("Can't wait if already finished");
    }
    return this.waiting = true;
  };

  Waiter.prototype.wait = function(arg, pred) {
    if (arguments.length) {
      if (typeof (arg != null ? arg.then : void 0) === "function") {
        return this.waitThenable(arg);
      } else if (typeof arg === "function") {
        return this.waitPredicate(arg);
      } else if (typeof arg === "number") {
        return this.waitPredicate(pred != null ? pred : function() {
          return true;
        }, arg);
      } else {
        throw new TypeError('must wait on timeout, function, promise, or nothing');
      }
    } else {
      this._startWaiting();
      return this.done;
    }
  };

  Waiter.prototype.waitThenable = function(p) {
    var done;
    this._startWaiting();
    done = this.done;
    p.then(function(v) {
      return done();
    }, function(e) {
      return done(e || new Error('Empty promise rejection'));
    });
    return p;
  };

  Waiter.prototype.waitPredicate = function(pred, interval) {
    if (interval == null) {
      interval = 1;
    }
    this._startWaiting();
    return setTimeout(((function(_this) {
      return function() {
        var e;
        if (_this.finished) {
          return;
        }
        try {
          if (pred()) {
            return _this.done();
          } else {
            return _this.waitPredicate(pred);
          }
        } catch (error) {
          e = error;
          return _this.done(e);
        }
      };
    })(this)), interval);
  };

  return Waiter;

})();

mockdown.parse = function(input, options) {
  return new mockdown.Parser(options).parse(input);
};

mockdown.parseFile = function(path, options) {
  return new mockdown.Parser(options).parseFile(path);
};

mockdown.Parser = (function() {
  var directiveStart, validDirective;

  function Parser() {
    this.doc = (function(func, args, ctor) {
      ctor.prototype = func.prototype;
      var child = new ctor, result = func.apply(child, args);
      return Object(result) === result ? result : child;
    })(mockdown.Document, arguments, function(){});
    this.builder = new mockdown.Builder(this.doc);
    this.example = void 0;
  }

  Parser.prototype.match = function(tok, pred) {
    var j, len, p, t;
    if (typeof pred === 'string') {
      if (tok.type === pred) {
        return tok;
      }
    } else {
      for (j = 0, len = pred.length; j < len; j++) {
        p = pred[j];
        t = this.match(tok, p);
        if (t != null) {
          return t;
        }
      }
    }
  };

  Parser.prototype.matchDeep = function() {
    var c, children, pred, subpreds, tok;
    tok = arguments[0], pred = arguments[1], subpreds = 3 <= arguments.length ? slice.call(arguments, 2) : [];
    if ((tok = this.match(tok, pred)) == null) {
      return;
    }
    if (!subpreds.length) {
      return tok;
    }
    children = (function() {
      var j, len, ref1, ref2, results;
      ref2 = (ref1 = tok.children) != null ? ref1 : [];
      results = [];
      for (j = 0, len = ref2.length; j < len; j++) {
        c = ref2[j];
        if (c.type !== 'space') {
          results.push(c);
        }
      }
      return results;
    })();
    if (children.length !== 1) {
      return;
    }
    return this.matchDeep.apply(this, [children[0]].concat(slice.call(subpreds)));
  };

  Parser.prototype.syntaxError = function(line, message) {
    return injectStack(new SyntaxError(message), "  at (" + this.doc.filename + ":" + line + ")");
  };

  Parser.prototype.parseFile = function(path) {
    if (this.doc.filename === '<anonymous>') {
      this.doc.filename = path;
    }
    return this.parse(require('fs').readFileSync(path, 'utf8'));
  };

  Parser.prototype.parse = function(input) {
    var j, len, parser, state, tok;
    if (typeof input === 'string') {
      input = mockdown.lex(input);
    }
    parser = new this.constructor(this.doc);
    state = parser.SCAN;
    for (j = 0, len = input.length; j < len; j++) {
      tok = input[j];
      if (tok.type !== 'space') {
        state = state.call(parser, tok);
      }
    }
    state.call(parser, {
      type: 'END'
    });
    return parser.builder.end();
  };

  Parser.prototype.SCAN = function(tok) {
    return this.parseDirective(tok, false) || this.parseCode(tok) || this.parseHeading(tok) || this.SCAN;
  };

  Parser.prototype.HAVE_DIRECTIVE = function(tok) {
    return this.parseDirective(tok, true) || this.parseCode(tok) || (function() {
      throw this.syntaxError(tok.line, "no example found for preceding directives");
    }).call(this);
  };

  Parser.prototype.HAVE_CODE = function(tok) {
    var out;
    if (out = this.matchDeep(tok, 'blockquote', 'code')) {
      this.setExample({
        output: out.text + '\n'
      });
    }
    if (!this.example.ignore) {
      this.builder.addExample(this.example);
    }
    this.example = void 0;
    return this.SCAN(tok);
  };

  Parser.prototype.setExample = function(data) {
    if (this.example != null) {
      return props.assign(this.example, data);
    }
    return this.example != null ? this.example : this.example = new mockdown.Example(data, this.doc);
  };

  Parser.prototype.parseCode = function(tok) {
    var lang, ref1;
    if (tok.type !== 'code') {
      return;
    }
    this.setExample({
      line: tok.line,
      code: tok.text
    });
    lang = (ref1 = tok.lang) != null ? ref1 : this.example.defaultLanguage;
    if (!(this.example.engine = this.doc.getEngine(lang))) {
      throw this.syntaxError(tok.line, "Unrecognized language: " + lang);
    }
    if (this.example.engine === 'ignore') {
      this.example.ignore = true;
    }
    this.started = true;
    return this.HAVE_CODE;
  };

  Parser.prototype.parseHeading = function(tok) {
    if (tok.type !== 'heading') {
      return;
    }
    this.builder.startSection(tok.depth, tok.text);
    return this.SCAN;
  };

  Parser.prototype.parseDirective = function(tok, haveDirective) {
    if (!(tok = this.matchDirective(tok))) {
      return;
    }
    switch (tok.type) {
      case 'mockdown':
        this.directive(this.setExample(), tok.text, tok.line);
        this.started = true;
        return this.HAVE_DIRECTIVE;
      case 'mockdown-set':
        if (haveDirective) {
          return;
        }
        this.directive(this.doc, tok.text, tok.line);
        break;
      case 'mockdown-setup':
        if (haveDirective) {
          return;
        }
        if (this.started) {
          throw this.syntaxError(tok.line, "setup must be before other code or directives");
        }
        this.directive(this.doc, tok.text, tok.line, document_specs);
    }
    this.started = true;
    return this.SCAN;
  };

  directiveStart = /^([\S\s]*<!--\s*)mockdown/;

  validDirective = /^\s*<!--\s*(mockdown(?:-set|-setup|)):((?:[^-]|-(?!->))*)-->\s*$/;

  Parser.prototype.matchDirective = function(tok) {
    var all, match, prefix;
    if (tok.type !== 'html') {
      return;
    }
    if (!(match = tok.text.match(directiveStart))) {
      return;
    }
    all = match[0], prefix = match[1];
    tok.line += splitLines(prefix).length - 1;
    if (!(match = tok.text.match(validDirective))) {
      throw this.syntaxError(tok.line, "malformed mockdown directive");
    }
    all = match[0], tok.type = match[1], tok.text = match[2];
    return tok;
  };

  Parser.prototype.directive = function(ob, code, line, specs) {
    if (specs == null) {
      specs = example_specs;
    }
    return this.directiveEnv(ob, specs).run(offset(line, code), {
      filename: this.doc.filename
    });
  };

  Parser.prototype.directiveEnv = function(ob, allowed) {
    var ctx, env;
    ctx = (env = new mockdown.Environment).context;
    Object.keys(document_specs).forEach(function(name) {
      var descr, err, msg;
      msg = name + " can only be accessed via mockdown-setup";
      err = function() {
        throw new TypeError(msg);
      };
      descr = {
        get: err,
        set: err
      };
      if (allowed.hasOwnProperty(name)) {
        descr.set = function(val) {
          return ob[name] = val;
        };
        descr.get = function() {
          return ob[name];
        };
      }
      return Object.defineProperty(ctx, name, descr);
    });
    return env;
  };

  return Parser;

})();

mdast = require('mdast')();

mockdown.lex = function(src) {
  var j, len, ref1, results, tok;
  ref1 = mdast.parse(src).children;
  results = [];
  for (j = 0, len = ref1.length; j < len; j++) {
    tok = ref1[j];
    results.push(toMarked(tok));
  }
  return results;
};

toMarked = function(tok, parent) {
  var c, lineCount, p, ref1;
  if (tok.value != null) {
    tok.text = tok.value;
    delete tok.value;
  }
  if (tok.children != null) {
    if ((ref1 = tok.type) === 'heading' || ref1 === 'paragraph') {
      tok.text = ((function() {
        var j, len, ref2, results;
        ref2 = tok.children;
        results = [];
        for (j = 0, len = ref2.length; j < len; j++) {
          c = ref2[j];
          results.push(mdast.stringify(c));
        }
        return results;
      })()).join('');
      delete tok.children;
    } else {
      tok.children = (function() {
        var j, len, ref2, results;
        ref2 = tok.children;
        results = [];
        for (j = 0, len = ref2.length; j < len; j++) {
          c = ref2[j];
          results.push(toMarked(c, tok));
        }
        return results;
      })();
    }
  }
  if ((p = tok.position) != null) {
    tok.line = p.start.line;
    lineCount = p.end.line - tok.line + 1;
    if (tok.type === 'code') {
      reformatCode(tok, parent, lineCount);
    }
    delete tok.position;
  }
  return tok;
};

reformatCode = function(tok, parent, lineCount) {
  var add, missing;
  if (missing = lineCount - splitLines(tok.text).length) {
    ++tok.line;
  }
  if ((parent != null ? parent.type : void 0) === 'blockquote' && parent.children.length === 1) {
    add = parent.position.end.line - tok.position.end.line;
    return tok.text += Array(add + 1).join('\n');
  }
};
