closest = (element, selector) ->
  return element if element.matches(selector)
  closest(element.parentElement, selector)

indexOf = (element) ->
  for child, index in element.parentElement.children
    return index if element is child
  return -1

contains = (elements, element) ->
  Array::indexOf.call(elements, element) isnt -1

matches = (element, selector) ->
  element.matches(selector) or element.matches(selector + " *")

module.exports = {matches, closest, indexOf, contains}
