define ['jquery', 'chai', 'cs!polyfill-path/index'], ($, chai, CSSPolyfill) ->

  assert = chai.assert
  expect = chai.expect

  strExpect = (expected, actual) ->
    expected = expected.trim().replace(/\s+/g, '') # strip **all** whitespace
    actual   =   actual.trim().replace(/\s+/g, '') # strip **all** whitespace
    expect(actual).to.equal(expected)


  # Simple test that compares CSS+HTML with the expected text output.
  # **Note:** ALL whitespace is stripped for the comparison
  return (css, html, expected) ->
    # FIXME: remove the need to append to `body` once target-counter does not use `body` as the hardcoded root
    $content = $('<div></div>').appendTo('body')
    $content.append(html)

    CSSPolyfill($content, css)
    $content.remove()
    strExpect(expected, $content.text())