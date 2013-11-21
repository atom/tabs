TabBarView = require './tab-bar-view'

module.exports =
  activate: ->
    @paneSubscription = atom.rootView.eachPane (pane) -> new TabBarView(pane)

  deactivate: ->
    @paneSubscription?.off()
