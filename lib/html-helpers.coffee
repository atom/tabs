matches = (element, selector) ->
  element.matches(selector) or element.matches(selector + " *")

module.exports = {matches}
