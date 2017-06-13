{CompositeDisposable, Disposable} = require 'atom'
FileIcons = require './file-icons'
layout = require './layout'
TabBarView = require './tab-bar-view'
MRUListView = require './mru-list-view'
_ = require 'underscore-plus'

module.exports =
  activate: (state) ->
    layout.activate()
    @tabBarViews = []
    @mruListViews = []

    keyBindSource = 'tabs package'
    mruConfigKey = 'tabs.enableMruTabSwitching'
    listConfigKey = 'tabs.enableMruTabList'

    @updateTraversalKeybinds = ->
      # We don't modify keybindings based on our setting if the user has already tweaked them.
      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-tab')
      return if bindings.length > 1 and bindings[0].source isnt keyBindSource
      bindings = atom.keymaps.findKeyBindings(
        target: document.body,
        keystrokes: 'ctrl-shift-tab')
      return if bindings.length > 1 and bindings[0].source isnt keyBindSource

      if atom.config.get(mruConfigKey)
        atom.keymaps.removeBindingsFromSource(keyBindSource)
      else
        disabledBindings =
          'body':
            'ctrl-tab': 'pane:show-next-item'
            'ctrl-tab ^ctrl': 'unset!'
            'ctrl-shift-tab': 'pane:show-previous-item'
            'ctrl-shift-tab ^ctrl': 'unset!'
        atom.keymaps.add(keyBindSource, disabledBindings, 0)

    @updateTabListSubscription = ->
      if atom.config.get(mruConfigKey) and atom.config.get(listConfigKey)
        subscriptions =
          for location, container of paneContainers
            continue unless container
            container.observePanes @registerTabListPanes
        @tabListPaneSubscription = new CompositeDisposable(subscriptions...)
      else
        mruListView.destroy() for mruListView in @mruListViews
        @tabListPaneSubscription.dispose() if @tabListPaneSubscription

    @registerTabBarPanes = (pane) =>
      tabBarView = new TabBarView(pane, location)

      paneElement = atom.views.getView(pane)
      paneElement.insertBefore(tabBarView.element, paneElement.firstChild)

      @tabBarViews.push(tabBarView)
      pane.onDidDestroy => _.remove(@tabBarViews, tabBarView)

    @registerTabListPanes = (pane) =>
      mruListView = new MRUListView
      mruListView.initialize(pane)

      @mruListViews.push(mruListView)
      pane.onDidDestroy => _.remove(@mruListViews, mruListView)

    atom.keymaps.onDidLoadUserKeymap? => @updateTraversalKeybinds()
    atom.config.observe mruConfigKey, =>
      @updateTraversalKeybinds()
      @updateTabListSubscription() if atom.config.get(listConfigKey)

    atom.config.observe listConfigKey, => @updateTabListSubscription()

    # If the command bubbles up without being handled by a particular pane,
    # close all tabs in all panes
    atom.commands.add 'atom-workspace',
      'tabs:close-all-tabs': =>
        # We loop backwards because the panes are
        # removed from the array as we go
        for tabBarView in @tabBarViews by -1
          tabBarView.closeAllTabs()

    paneContainers =
      center: atom.workspace.getCenter?() ? atom.workspace
      left: atom.workspace.getLeftDock?()
      right: atom.workspace.getRightDock?()
      bottom: atom.workspace.getBottomDock?()

    subscriptions =
      for location, container of paneContainers
        continue unless container
        container.observePanes @registerTabBarPanes

    @tabBarPaneSubscription = new CompositeDisposable(subscriptions...)

  deactivate: ->
    layout.deactivate()
    @tabBarPaneSubscription.dispose()
    @tabListPaneSubscription.dispose()
    @fileIconsDisposable?.dispose()
    tabBarView.destroy() for tabBarView in @tabBarViews
    mruListView.destroy() for mruListView in @mruListViews
    return

  consumeFileIcons: (service) ->
    FileIcons.setService(service)
    @updateFileIcons()
    new Disposable =>
      FileIcons.resetService()
      @updateFileIcons()

  updateFileIcons: ->
    for tabBarView in @tabBarViews
      tabView.updateIcon() for tabView in tabBarView.getTabs()
