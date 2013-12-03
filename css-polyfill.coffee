class Plugin
  providedFunctions: () -> {}
  # domVisitor: (funcs, env) ->
  # lessVisitor: ($root) ->


class DomVisitor

  constructor: (@_funcs={}, @_env={}) ->
    # Register all the tree.functions to use the current node if they need to look up
    for name, func of @_funcs
      less.tree.functions[name] = func

  evalWithContext: (dataKey, $context) ->
    expr = $context.data(dataKey)
    return if not expr

    @_env.$context = $context

    return expr

  domVisit: ($node) ->


class LessVisitor
  constructor: (@$root) ->
    @_visitor = new less.tree.visitor(@)
    @_frames = []

  run: (root) -> @_visitor.visit(root)

  peek: () -> @_frames[@_frames.length-1]
  push: (val) -> @_frames.push(val)
  pop:  () -> return @_frames.pop()

  # visitAnonymous: (node, visitArgs) ->
  # visitCall: (node, visitArgs) ->
  # visitCombinator: (node, visitArgs) ->
  # visitExpression: (node, visitArgs) ->
  # visitKeyword: (node, visitArgs) ->
  # visitQuoted: (node, visitArgs) ->
  # visitRule: (node, visitArgs) ->
  # visitSelector: (node, visitArgs) ->
  # visitValue: (node, visitArgs) ->


class AbstractSelectorVisitor extends LessVisitor

  operateOnElements: (frame, $els) -> console.error('BUG! Need to implement this method')

  # Helper to add things to jQuery.data()
  dataAppendAll: ($els, dataKey, exprs) ->
    if exprs
      console.error('BUG: dataAppendAll takes an array of expressions') if exprs not instanceof Array
      content = $els.data(dataKey) or []
      for c in exprs
        content.push(c)
      $els.data(dataKey, content)
      $els.addClass('js-polyfill-has-data')
      $els.addClass("js-polyfill-#{dataKey}")

  dataSet: ($els, dataKey, expr) ->
    if expr
      $els.data(dataKey, expr)
      $els.addClass('js-polyfill-has-data')
      $els.addClass("js-polyfill-#{dataKey}")

  visitRuleset: (node, visitArgs) ->
    # Begin here.
    @push {
      selectorAry: []
      pseudoName: null
    }
    # Build up a selector
    # Note if it ends in ::before or ::after

  visitElement: (node, visitArgs) ->
    frame = @peek()
    if /:before$/.test(node.value)
      frame.pseudoName = 'before'
      cls = "js-polyfill-pseudo-before"
      frame.selectorAry.push("> .#{cls}")
    else if /:after$/.test(node.value)
      frame.pseudoName = 'after'
      cls = "js-polyfill-pseudo-after"
      frame.selectorAry.push("> .#{cls}")
    else
      frame.selectorAry.push(node.combinator.value)
      frame.selectorAry.push(node.value)

  visitRulesetOut: (node) ->
    frame = @pop()
    # Select the nodes to add the pseudo-element
    pseudoName = frame.pseudoName
    selectorAry = frame.selectorAry

    selector = selectorAry.join(' ')
    $els = @$root.find(selector)
    @operateOnElements(frame, $els)


ClassRenamerPlugin =
  lessVisitor:
    class ClassRenamer extends AbstractSelectorVisitor
      constructor: () ->
        super(arguments...)
        @idCounter = 0
        @classMap = {}

      visitRuleset: (node, visitArgs) ->
        super(arguments...)
        selector = "js-polyfill-autoclass-#{@idCounter}"
        index = 0 # optional, but it seems to be the "specificity"; maybe it should be extracted from the original selector
        node.selectors = [new less.tree.Selector(new less.tree.Element('', selector, index))]

      operateOnElements: (frame, $els) ->
        $els.addClass("js-polyfill-autoclass-#{@idCounter}")
        @idCounter += 1


# Generates elements of the form `<span class="js-polyfill-pseudo-before"></span>`

# Use a "custom" element name so CSS does not "pick these up" accidentally
# TODO: have a pass at the end that converts them to <span> elements or something.
PSEUDO_ELEMENT_NAME = 'polyfillpseudo'

PseudoExpanderPlugin =
  lessVisitor:
    class PseudoSelectorExpander extends LessVisitor
      isPreEvalVisitor: false
      isPreVisitor: true
      isReplacing: false

      # constructor: (@$root) -> super(arguments...)

      visitRuleset: (node, visitArgs) ->
        # Begin here.
        @push {
          selectorAry: []
          pseudoName: null
        }
        # Build up a selector
        # Note if it ends in ::before or ::after

      visitElement: (node, visitArgs) ->
        frame = @peek()
        if /:before$/.test(node.value)
          frame.pseudoName = 'before'
        else if /:after$/.test(node.value)
          frame.pseudoName = 'after'
        # Footnote options. See http://www.w3.org/TR/css3-gcpm/#footnotes
        else if /::footnote-call$/.test(node.value)
          frame.pseudoName = 'footnote-call'
        else if /::footnote-marker$/.test(node.value)
          frame.pseudoName = 'footnote-marker'
        else
          frame.selectorAry.push(node.combinator.value)
          frame.selectorAry.push(node.value)

      visitRulesetOut: (node) ->
        frame = @pop()
        # Select the nodes to add the pseudo-element
        pseudoName = frame.pseudoName
        selectorAry = frame.selectorAry

        if pseudoName
          selector = selectorAry.join(' ')
          $els = @$root.find(selector)

          op = switch pseudoName
            when 'before' then 'prepend'
            when 'after' then 'append'
            else console.error('BUG! unmatched pseudo-selector')

          # Prepend/Append if the DOM node does not yet exist
          cls = "js-polyfill-pseudo-#{pseudoName}"
          $els = $els.not($els.has(" > .#{cls}"))
          $els[op]("<#{PSEUDO_ELEMENT_NAME} class='js-polyfill-pseudo #{cls}'></#{PSEUDO_ELEMENT_NAME}>")



RemoveDisplayNonePlugin =
  lessVisitor:
    class RemoveDisplayNone extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        if 'display' == node.name
          # Make sure the display is exactly `none`
          # instead of checking if `none` is one of the Anonymous nodes
          if 'none' == node.value.eval().value # node.value?.value?[0]?.value
            frame.hasDisplayNone = true

      operateOnElements: (frame, $els) ->
        if frame.hasDisplayNone
          $els.remove()


# implements `less.tree.*` structure
class ValueNode
  # The `@value` is most important
  constructor: (@value) ->
  type: 'ValueNode',
  eval: () -> @
  compare: () -> console.error('BUG: Should not call compare on these nodes')
  genCSS: () -> console.warn('BUG: Should not call genCSS on these nodes')
  toCSS: () -> console.error('BUG: Should not call toCSS on these nodes')

class SelectorValueNode
  constructor: (@selector, @attr) ->
  eval: () -> @

MoveToPlugin =
  definedFunctions:
    # TODO: this func can be moved out of this plugin
    'attr': (attrName) ->
      return new ValueNode(@env.$context.attr(attrName.value))
    'x-filter': (selector, attrName=null) ->
      $els = @env.$context.find(selector.value)
      if attrName
        return new ValueNode($els.attr(attrName.value))
      else
        return new ValueNode($els)
    'x-selector': (selector, attrName=null) ->
      return new SelectorValueNode(selector.value, attrName?.value)

    'x-sort': (pendingElsNode, selectorToCompare=null) ->
      $pendingEls = pendingElsNode.value

      # "Push" a frame on the context
      $context = @env.$context

      sorted = _.clone($pendingEls).sort (a, b) =>
        if selectorToCompare
          $a = $(a)
          $b = $(b)
          a = $a.find(selectorToCompare.selector).text()
          b = $b.find(selectorToCompare.selector).text()
        else
          a = a.text()
          b = b.text()
        return -1 if (a < b)
        return 1 if (a > b)
        return 0

      # "Pop" the frame off the context
      @env.$context = $context

      $sorted = $('EMPTY_SET_OF_NODES')
      _.each sorted, (el) ->
        $sorted = $sorted.add(el)
      return new ValueNode($sorted)

    pending: (val) ->
      bucketName = val.eval(@env).value
      if @env.buckets
        $nodes = @env.buckets[bucketName] or $('EMPTY_SET_OF_NODES')
        delete @env.buckets[bucketName]
        return new ValueNode($nodes)

  lessVisitor:
    class MoveToLessVisitor extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        switch node.name
          when 'move-to'
            # Make sure the display is exactly `none`
            # instead of checking if `none` is one of the Anonymous nodes
            frame.moveTo = node.value

      operateOnElements: (frame, $els) ->
        @dataSet($els, 'polyfill-move-to', frame.moveTo)

  domVisitor:
    class MoveToDomVisitor extends DomVisitor

      domVisit: ($node) ->
        moveBucket = @evalWithContext('polyfill-move-to', $node)?.eval(@_env).value
        if moveBucket
          @_env.buckets ?= {}
          @_env.buckets[moveBucket] ?= []
          @_env.buckets[moveBucket].push($node)
          $node.detach() # Keep the jQuery.data()


SetContentPlugin =
  lessVisitor:
    class SetContentVisitor extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        # TODO: test to see if this `content: ` is evaluatable using this set of polyfills
        switch node.name
          when 'content'
            frame.setContent ?= []
            frame.setContent.push(node.value)

      operateOnElements: (frame, $els) ->
        @dataAppendAll($els, 'polyfill-content', frame.setContent)

  domVisitor:
    class SetContentDomVisitor extends DomVisitor

      domVisit: ($node) ->
        # content can be a string OR a set of nodes (`move-to`)
        contents = @evalWithContext('polyfill-content', $node)

        # The `content:` rule is a bit annoying.
        #
        # There can be many content rules, only some of which work with the
        # polyfills loaded.

        # TODO: Move this into the Visitor (but it needs to know that all of these will resolve)

        # NOTE: There may be some "invalid" `content: ` options, keep trying until one works.
        #
        # NOTE: the "value" of `content: ` may be one of:
        #
        # - `tree.Quoted` value (ie `content: 'hello'; `)
        # - `tree.Expression` containing `tree.Quoted` (ie `content: 'hello' ' there';`)
        # - `tree.Expression` containing an unresolved `tree.Call` (ie `content: 'hello' foo();`)
        # - `ValueNode` containing a set of elements (ie `content: pending(bucket-name); `)

        if contents
          for content in contents
            expr = content.eval(@_env)

            if expr.value instanceof Array and expr instanceof less.tree.Expression
              exprValues = expr.value
            else
              exprValues = [expr]

            # concatenate all the strings
            strings = []
            isValid = true
            for val in exprValues
              if val instanceof less.tree.Call
                console.warn("Skipping {content: #{expr.toCSS()};} because no way to handle #{val.name}().")
                isValid = false
              else
                strings.push(val.value)

            if isValid
              $node.empty()
              # Append 1-by-1 because they values may be multiple jQuery sets (like `content: pending(bucket1) pending(bucket2)`)
              for val in strings
                $node.append(val)




# Iterate over the DOM and calculate the counter state for each interesting node, adding in pseudo-nodes
parseCounters = (val, defaultNum) ->

  # If the counter list contains a `-` then Less parses "name -1 othername 3" as Keyword, Dimension, Keyword, Dimension.
  # Otherwise, Less parses "name 0 othername 3" as Anonymous["name 0 othername 3"].
  # So, just convert it to a CSS string and have parseCounters split it up.
  cssStr = val.toCSS({})

  tokens = cssStr.split(' ')
  counters = {}

  # The counters to increment/reset can be 'none' in which case nothing is returned
  return counters if 'none' == tokens[0]

  # counter-reset can have the following structure: "counter1 counter2 -10 counter3 100 counter4 counter5"

  i = 0
  while i < tokens.length
    name = tokens[i]
    if i == tokens.length - 1
      val = defaultNum
    else if isNaN(parseInt(tokens[i+1])) # tokens[i+1] instanceof less.tree.Keyword
      val = defaultNum
    else # if tokens[i+1] instanceof less.tree.Dimension
      val = parseInt(tokens[i+1])
      i++
    # else
    #  console.error('BUG! Unsupported Counter Token', tokens[i+1])
    counters[name] = val
    i++

  counters


# These are used to format numbers and aren't terribly interesting

# convert integer to Roman numeral. From http://www.diveintopython.net/unit_testing/romantest.html
toRoman = (num) ->
  romanNumeralMap = [
    ['M',  1000]
    ['CM', 900]
    ['D',  500]
    ['CD', 400]
    ['C',  100]
    ['XC', 90]
    ['L',  50]
    ['XL', 40]
    ['X',  10]
    ['IX', 9]
    ['V',  5]
    ['IV', 4]
    ['I',  1]
  ]
  if not (0 < num < 5000)
    console.error 'number out of range (must be 1..4999)'
    return num

  result = ''
  for [numeral, integer] in romanNumeralMap
    while num >= integer
      result += numeral
      num -= integer
  result

# Options are defined by http://www.w3.org/TR/CSS21/generate.html#propdef-list-style-type
numberingStyle = (num, style='decimal') ->
  switch style
    when 'decimal-leading-zero'
      if num < 10 then "0#{num}"
      else num
    when 'lower-roman'
      toRoman(num).toLowerCase()
    when 'upper-roman'
      toRoman(num)
    when 'lower-latin'
      if not (1 <= num <= 26)
        console.error 'number out of range (must be 1...26)'
      String.fromCharCode(num + 96)
    when 'upper-latin'
      if not (1 <= num <= 26)
        console.error 'number out of range (must be 1...26)'
      String.fromCharCode(num + 64)
    when 'decimal'
      num
    else
      console.warn "Counter numbering not supported for list type #{style}. Using decimal."
      num


CounterPlugin =

  definedFunctions:
    counter: (counterName, counterStyle=null) ->

      counterName = counterName.value
      counterStyle = counterStyle?.value or 'decimal'

      # Defined by http://www.w3.org/TR/CSS21/generate.html#propdef-list-style-type
      val = @env.counters?[counterName] or 0
      return new ValueNode(numberingStyle(val, counterStyle))

  lessVisitor:
    class CounterLessVisitor extends AbstractSelectorVisitor

      visitRule: (node, visitArgs) ->
        frame = @peek()
        # TODO: test to see if this `content: ` is evaluatable using this set of polyfills
        switch node.name
          when 'counter-reset'
            frame.setCounterReset ?= []
            frame.setCounterReset.push(node.value)
          when 'counter-increment'
            frame.setCounterIncrement ?= []
            frame.setCounterIncrement.push(node.value)

      operateOnElements: (frame, $els) ->
        @dataAppendAll($els, 'polyfill-counter-reset', frame.setCounterReset)
        @dataAppendAll($els, 'polyfill-counter-increment', frame.setCounterIncrement)

        # For each element set a class marking which counters were changed in this node.
        # This is useful for implementing `target-counter` since it will traverse
        # backwards to the nearest node where the counter changes.
        counters = {}
        if frame.setCounterReset
          # TODO: instead of using last, err on the side of caution and just use all counters
          val = _.last(frame.setCounterReset).eval()
          _.defaults(counters, parseCounters(val, true))
        if frame.setCounterIncrement
          val = _.last(frame.setCounterIncrement).eval()
          _.defaults(counters, parseCounters(val, true))

        for counterName of counters
          $els.addClass("js-polyfill-counter-change")
          $els.addClass("js-polyfill-counter-change-#{counterName}")



  domVisitor:
    class CounterDomVisitor extends DomVisitor

      domVisit: ($node) ->
        @_env.counters ?= {} # make sure it is defined
        countersChanged = false

        exprs = @evalWithContext('polyfill-counter-reset', $node)
        if exprs
          countersChanged = true
          val = exprs[exprs.length-1].eval(@_env)
          counters = parseCounters(val, 0)
          _.extend(@_env.counters, counters)

        exprs = @evalWithContext('polyfill-counter-increment', $node)
        if exprs
          countersChanged = true
          val = exprs[exprs.length-1].eval(@_env)
          counters = parseCounters(val, 1)
          for key, value of counters
            @_env.counters[key] ?= 0
            @_env.counters[key] += value

        # Squirrel away the counters if this node is "interesting" (for target-counter)
        if countersChanged
          $node.data('polyfill-counter-state', _.clone(@_env.counters))
          $node.addClass('js-polyfill-has-data')
          $node.addClass("js-polyfill-polyfill-counter-state")




# TODO: Make this a recursive traversal (for Large Documents)
findBefore = (el, root, iterator) ->
  $root = $(root)
  all = _.toArray($root.add($root.find('*')))

  # Find the index of `el`
  index = -1
  for i in [0..all.length]
    if all[i] == el
      index = i
      break

  # iterate until `iterator` returns `true` or we run out of elements
  ret = false
  while not ret and index > -1
    ret = iterator(all[index])
    index--
  return ret

TargetCounterPlugin =
  definedFunctions:
    # TODO: this func can be moved out of this plugin
    'attr': (attrName) ->
      return new ValueNode(@env.$context.attr(attrName.value))

    # Traverse the DOM until the nearest node where the counter changes is found
    'target-counter': (id, counterName, counterStyle=null) ->
      counterName = counterName.value
      counterStyle = counterStyle?.value or 'decimal'

      id = id.value
      console.error('BUG: target-id MUST start with #') if id[0] != '#'
      $target = $(id)
      if $target.length
        val = 0
        findBefore $target[0], $('body')[0], (node) ->
          $node = $(node)
          if $node.is(".js-polyfill-counter-change-#{counterName}")
            counters = $node.data('polyfill-counter-state')
            console.error('BUG: SHould have found a counter for this element') if not counters
            val = counters[counterName]
            return true
          # Otherwise, continue searching
          return false

        return new ValueNode(numberingStyle(val, counterStyle))

      else
        # TODO: decide whether to fail silently by returning '' or return 'ERROR_TARGET_ID_NOT_FOUND'
        console.warn('ERROR: target-counter id not found having id:', id)
        return new ValueNode('ERROR_TARGET_ID_NOT_FOUND')



TargetTextPlugin =

  definedFunctions:
    # TODO: this func can be moved out of this plugin
    'attr': (attrName) ->
      return new ValueNode(@env.$context.attr(attrName.value))

    'target-text': (id, whichNode=null) ->
      console.error('BUG: target-id MUST start with #') if id.value[0] != '#'

      $target = $(id.value)

      whichText = 'before' # default
      if whichNode
        console.error('BUG: must be a content(...) call') if 'content' != whichNode.name
        if whichNode.args.length == 0
          whichText = 'contents'
        else
          whichText = whichNode.args[0].value

      switch whichText
        when 'before'   then ret = $target.children('.js-polyfill-pseudo-before').text()
        when 'after'    then ret = $target.children('.js-polyfill-pseudo-after').text()
        when 'contents' then ret = $target.text() # TODO: ignore the pseudo elements
        when 'first-letter' then ret = $target.text()[0]
        else console.error('BUG! invalid whichText')

      return new ValueNode(ret)


window.CSSPolyfill = ($root, cssStyle) ->

  p1 = new less.Parser()
  p1.parse cssStyle, (err, val) ->

    console.error(err) if err

    # Use a global env so various passes can share data (grumble)
    env = {}

    doStuff = (plugins) ->

      lessPlugins = []
      for plugin in plugins
        lessPlugins.push(new (plugin.lessVisitor)($root)) if plugin.lessVisitor

      # Use the same env for toCSS as the visitors so they can share context
      # Use a global env so various passes can share data (grumble)
      env.plugins = lessPlugins
      val.toCSS(env)

      funcs = {}
      for plugin in plugins
        for name, func of plugin.definedFunctions
          funcs[name] = func

      domVisitors = []
      for plugin in plugins
        if plugin.domVisitor
          domVisitors.push(new (plugin.domVisitor)(funcs, env))


      $root.find('*').each (i, el) ->
        $el = $(el)
        for v in domVisitors
          v.domVisit($el)

      #deregister the functions when done
      for funcName of funcs
        delete less.tree.functions[funcName]

    # Run the plugins in multiple phases because move-to manipulates the DOM
    # and jQuery.data() disappears when the element detaches from the DOM
    plugins = [
      ClassRenamerPlugin # Must be run **before** the MoveTo plugin so the styles continue to apply to the element when it is moved
      MoveToPlugin # Run in the 1st phase because jQuery.data() is lost when DOM nodes move
      SetContentPlugin # Always run last
    ]
    doStuff(plugins)

    plugins = [
      PseudoExpanderPlugin
      RemoveDisplayNonePlugin # Important to run **before** the CounterPlugin
    ]
    doStuff(plugins)

    plugins = [
      CounterPlugin # Run the counter plugin **before** TargetCounterPlugin so links to elements later in the DOM work
      SetContentPlugin # Used to populate content that just uses counter() for things like pseudoselectors
    ]
    doStuff(plugins)

    plugins = [
      TargetCounterPlugin
      TargetTextPlugin
      SetContentPlugin
    ]
    doStuff(plugins)
