closest = (element, selector) ->
  return element if element.matches(selector)
  closest(element.parentElement, selector)

indexOf = (element) ->
  for child, index in element.parentElement.children
    return index if element is child
  return -1

module.exports = {closest, indexOf}
