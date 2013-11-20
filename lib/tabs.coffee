TabBarView = require './tab-bar-view'

module.exports =
  activate: ->
    atom.rootView.eachPane (pane) -> new TabBarView(pane)
