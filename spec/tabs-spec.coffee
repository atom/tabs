{$, View}  = require 'atom-space-pen-views'
_ = require 'underscore-plus'
path = require 'path'
temp = require 'temp'
TabBarView = require '../lib/tab-bar-view'
TabView = require '../lib/tab-view'
{triggerMouseEvent, buildDragEvents, buildWheelEvent, buildWheelPlusShiftEvent} = require "./event-helpers"

describe "Tabs package main", ->
  workspaceElement = null

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.workspace.open('sample.js')

    waitsForPromise ->
      atom.packages.activatePackage("tabs")

  describe ".activate()", ->
    it "appends a tab bar all existing and new panes", ->
      expect(workspaceElement.querySelectorAll('.pane').length).toBe 1
      expect(workspaceElement.querySelectorAll('.pane > .tab-bar').length).toBe 1

      pane = atom.workspace.getActivePane()
      pane.splitRight()

      expect(workspaceElement.querySelectorAll('.pane').length).toBe 2
      expect(workspaceElement.querySelectorAll('.pane > .tab-bar').length).toBe 2

  describe ".deactivate()", ->
    it "removes all tab bar views and stops adding them to new panes", ->
      pane = atom.workspace.getActivePane()
      pane.splitRight()
      expect(workspaceElement.querySelectorAll('.pane').length).toBe 2
      expect(workspaceElement.querySelectorAll('.pane > .tab-bar').length).toBe 2

      atom.packages.deactivatePackage('tabs')
      expect(workspaceElement.querySelectorAll('.pane').length).toBe 2
      expect(workspaceElement.querySelectorAll('.pane > .tab-bar').length).toBe 0

      pane.splitRight()
      expect(workspaceElement.querySelectorAll('.pane').length).toBe 3
      expect(workspaceElement.querySelectorAll('.pane > .tab-bar').length).toBe 0

    it "serializes preview tab state", ->
      atom.config.set('tabs.usePreviewTabs', true)

      waitsForPromise ->
        atom.workspace.open('sample.txt')

      runs ->
        expect(workspaceElement.querySelectorAll('.tab.preview-tab .title').length).toBe 1
        expect(workspaceElement.querySelector('.tab.preview-tab .title')?.textContent).toBe 'sample.txt'

        atom.packages.deactivatePackage('tabs')

        expect(workspaceElement.querySelectorAll('.tab.preview-tab .title').length).toBe 0

      waitsForPromise ->
        atom.packages.activatePackage('tabs')

      runs ->
        expect(workspaceElement.querySelectorAll('.tab.preview-tab .title').length).toBe 1
        expect(workspaceElement.querySelector('.tab.preview-tab .title')?.textContent).toBe 'sample.txt'

describe "TabBarView", ->
  [deserializerDisposable, item1, item2, editor1, pane, tabBar] = []

  class TestView extends View
    @deserialize: ({title, longTitle, iconName}) -> new TestView(title, longTitle, iconName)
    @content: (title) -> @div title
    initialize: (@title, @longTitle, @iconName) ->
    getTitle: -> @title
    getLongTitle: -> @longTitle
    getIconName: -> @iconName
    serialize: -> {deserializer: 'TestView', @title, @longTitle, @iconName}
    onDidChangeTitle: (callback) ->
      @titleCallbacks ?= []
      @titleCallbacks.push(callback)
      dispose: => _.remove(@titleCallbacks, callback)
    emitTitleChanged: ->
      callback() for callback in @titleCallbacks ? []
    onDidChangeIcon: (callback) ->
      @iconCallbacks ?= []
      @iconCallbacks.push(callback)
      dispose: => _.remove(@iconCallbacks, callback)
    emitIconChanged: ->
      callback() for callback in @iconCallbacks ? []
    onDidChangeModified: -> # to suppress deprecation warning
      dispose: ->

  beforeEach ->
    deserializerDisposable = atom.deserializers.add(TestView)
    item1 = new TestView('Item 1', undefined, "squirrel")
    item2 = new TestView('Item 2')

    waitsForPromise ->
      atom.workspace.open('sample.js')

    runs ->
      editor1 = atom.workspace.getActiveTextEditor()
      pane = atom.workspace.getActivePane()
      pane.addItem(item1, 0)
      pane.addItem(item2, 2)
      pane.activateItem(item2)
      tabBar = new TabBarView(pane)

  afterEach ->
    deserializerDisposable.dispose()

  describe ".initialize(pane)", ->
    it "creates a tab for each item on the tab bar's parent pane", ->
      expect(pane.getItems().length).toBe 3
      expect(tabBar.find('.tab').length).toBe 3

      expect(tabBar.find('.tab:eq(0) .title').text()).toBe item1.getTitle()
      expect(tabBar.find('.tab:eq(0) .title')).not.toHaveAttr('data-name')
      expect(tabBar.find('.tab:eq(0) .title')).not.toHaveAttr('data-path')
      expect(tabBar.find('.tab:eq(0)')).toHaveAttr('data-type', 'TestView')

      expect(tabBar.find('.tab:eq(1) .title').text()).toBe editor1.getTitle()
      expect(tabBar.find('.tab:eq(1) .title')).toHaveAttr('data-name', path.basename(editor1.getPath()))
      expect(tabBar.find('.tab:eq(1) .title')).toHaveAttr('data-path', editor1.getPath())
      expect(tabBar.find('.tab:eq(1)')).toHaveAttr('data-type', 'TextEditor')

      expect(tabBar.find('.tab:eq(2) .title').text()).toBe item2.getTitle()
      expect(tabBar.find('.tab:eq(2) .title')).not.toHaveAttr('data-name')
      expect(tabBar.find('.tab:eq(2) .title')).not.toHaveAttr('data-path')
      expect(tabBar.find('.tab:eq(2)')).toHaveAttr('data-type', 'TestView')

    it "highlights the tab for the active pane item", ->
      expect(tabBar.find('.tab:eq(2)')).toHaveClass 'active'

    it "emits a warning when ::onDid... functions are not valid Disposables", ->
      class BadView extends View
        @content: (title) -> @div title
        getTitle: -> "Anything"
        onDidChangeTitle: ->
        onDidChangeIcon: ->
        onDidChangeModified: ->
        onDidSave: ->

      warnings = []
      spyOn(console, "warn").andCallFake (message, object) ->
        warnings.push({message, object})

      badItem = new BadView('Item 3')
      pane.addItem(badItem)

      expect(warnings[0].message).toContain("onDidChangeTitle")
      expect(warnings[0].object).toBe(badItem)

      expect(warnings[1].message).toContain("onDidChangeIcon")
      expect(warnings[1].object).toBe(badItem)

      expect(warnings[2].message).toContain("onDidChangeModified")
      expect(warnings[2].object).toBe(badItem)

      expect(warnings[3].message).toContain("onDidSave")
      expect(warnings[3].object).toBe(badItem)

  describe "when the active pane item changes", ->
    it "highlights the tab for the new active pane item", ->
      pane.activateItem(item1)
      expect(tabBar.find('.active').length).toBe 1
      expect(tabBar.find('.tab:eq(0)')).toHaveClass 'active'

      pane.activateItem(item2)
      expect(tabBar.find('.active').length).toBe 1
      expect(tabBar.find('.tab:eq(2)')).toHaveClass 'active'

  describe "when a new item is added to the pane", ->
    it "adds a tab for the new item at the same index as the item in the pane", ->
      pane.activateItem(item1)
      item3 = new TestView('Item 3')
      pane.activateItem(item3)
      expect(tabBar.find('.tab').length).toBe 4
      expect($(tabBar.tabAtIndex(1)).find('.title')).toHaveText 'Item 3'

    it "adds the 'modified' class to the new tab if the item is initially modified", ->
      editor2 = null

      waitsForPromise ->
        opener =
          if atom.workspace.buildTextEditor?
            atom.workspace.open('sample.txt', activateItem: false)
          else
            atom.project.open('sample.txt')

        opener.then (o) -> editor2 = o

      runs ->
        editor2.insertText('x')
        pane.activateItem(editor2)
        expect(tabBar.tabForItem(editor2)).toHaveClass 'modified'

  describe "when an item is removed from the pane", ->
    it "removes the item's tab from the tab bar", ->
      pane.destroyItem(item2)
      expect(tabBar.getTabs().length).toBe 2
      expect(tabBar.find('.tab:contains(Item 2)')).not.toExist()

    it "updates the titles of the remaining tabs", ->
      expect(tabBar.tabForItem(item2)).toHaveText 'Item 2'
      item2.longTitle = '2'
      item2a = new TestView('Item 2')
      item2a.longTitle = '2a'
      pane.activateItem(item2a)
      expect(tabBar.tabForItem(item2)).toHaveText '2'
      expect(tabBar.tabForItem(item2a)).toHaveText '2a'
      pane.destroyItem(item2a)
      expect(tabBar.tabForItem(item2)).toHaveText 'Item 2'

  describe "when a tab is clicked", ->
    it "shows the associated item on the pane and focuses the pane", ->
      spyOn(pane, 'activate')

      event = triggerMouseEvent('mousedown', tabBar.tabAtIndex(0), which: 1)
      expect(pane.getActiveItem()).toBe pane.getItems()[0]
      expect(event.preventDefault).not.toHaveBeenCalled() # allows dragging

      event = triggerMouseEvent('mousedown', tabBar.tabAtIndex(2), which: 1)
      expect(pane.getActiveItem()).toBe pane.getItems()[2]
      expect(event.preventDefault).not.toHaveBeenCalled() # allows dragging

      # Pane activation is delayed because focus is stolen by the tab bar
      # immediately afterward unless propagation of the mousedown event is
      # stopped. But stopping propagation of the mousedown event prevents the
      # dragstart event from occurring.
      waits(1)
      runs -> expect(pane.activate.callCount).toBe 2

    it "closes the tab when middle clicked", ->
      event = triggerMouseEvent('mousedown', tabBar.tabForItem(editor1), which: 2)

      expect(pane.getItems().length).toBe 2
      expect(pane.getItems().indexOf(editor1)).toBe -1
      expect(editor1.destroyed).toBeTruthy()
      expect(tabBar.getTabs().length).toBe 2
      expect(tabBar.find('.tab:contains(sample.js)')).not.toExist()

      expect(event.preventDefault).toHaveBeenCalled()

    it "doesn't switch tab when right (or ctrl-left) clicked", ->
      spyOn(pane, 'activate')

      event = triggerMouseEvent('mousedown', tabBar.tabAtIndex(0), which: 3)
      expect(pane.getActiveItem()).not.toBe pane.getItems()[0]
      expect(event.preventDefault).toHaveBeenCalled()

      event = triggerMouseEvent('mousedown', tabBar.tabAtIndex(0), which: 1, ctrlKey: true)
      expect(pane.getActiveItem()).not.toBe pane.getItems()[0]
      expect(event.preventDefault).toHaveBeenCalled()

      expect(pane.activate).not.toHaveBeenCalled()

  describe "when a tab's close icon is clicked", ->
    it "destroys the tab's item on the pane", ->
      $(tabBar.tabForItem(editor1)).find('.close-icon').click()
      expect(pane.getItems().length).toBe 2
      expect(pane.getItems().indexOf(editor1)).toBe -1
      expect(editor1.destroyed).toBeTruthy()
      expect(tabBar.getTabs().length).toBe 2
      expect(tabBar.find('.tab:contains(sample.js)')).not.toExist()

  describe "when a tab item's title changes", ->
    it "updates the title of the item's tab", ->
      editor1.buffer.setPath('/this/is-a/test.txt')
      expect(tabBar.tabForItem(editor1)).toHaveText 'test.txt'

  describe "when two tabs have the same title", ->
    it "displays the long title on the tab if it's available from the item", ->
      item1.title = "Old Man"
      item1.longTitle = "Grumpy Old Man"
      item1.emitTitleChanged()
      item2.title = "Old Man"
      item2.longTitle = "Jolly Old Man"
      item2.emitTitleChanged()

      expect(tabBar.tabForItem(item1)).toHaveText "Grumpy Old Man"
      expect(tabBar.tabForItem(item2)).toHaveText "Jolly Old Man"

      item2.longTitle = undefined
      item2.emitTitleChanged()

      expect(tabBar.tabForItem(item1)).toHaveText "Grumpy Old Man"
      expect(tabBar.tabForItem(item2)).toHaveText "Old Man"

  describe "when an item has an icon defined", ->
    it "displays the icon on the tab", ->
      expect(tabBar.find('.tab:eq(0) .title')).toHaveClass "icon"
      expect(tabBar.find('.tab:eq(0) .title')).toHaveClass "icon-squirrel"

    it "hides the icon from the tab if the icon is removed", ->
      item1.getIconName = null
      item1.emitIconChanged()
      expect(tabBar.find('.tab:eq(0) .title')).not.toHaveClass "icon"
      expect(tabBar.find('.tab:eq(0) .title')).not.toHaveClass "icon-squirrel"

    it "updates the icon on the tab if the icon is changed", ->
      item1.getIconName = -> "zap"
      item1.emitIconChanged()
      expect(tabBar.find('.tab:eq(0) .title')).toHaveClass "icon"
      expect(tabBar.find('.tab:eq(0) .title')).toHaveClass "icon-zap"

    describe "when showIcon is set to true in package settings", ->
      beforeEach ->
        spyOn(tabBar.tabForItem(item1), 'updateIconVisibility').andCallThrough()

        atom.config.set("tabs.showIcons", true)

        waitsFor ->
          tabBar.tabForItem(item1).updateIconVisibility.callCount > 0

        runs ->
          tabBar.tabForItem(item1).updateIconVisibility.reset()

      it "doesn't hide the icon", ->
        expect(tabBar.find('.tab:eq(0) .title')).not.toHaveClass "hide-icon"

      it "hides the icon from the tab when showIcon is changed to false", ->
        atom.config.set("tabs.showIcons", false)

        waitsFor ->
          tabBar.tabForItem(item1).updateIconVisibility.callCount > 0

        runs ->
          expect(tabBar.find('.tab:eq(0) .title')).toHaveClass "hide-icon"

    describe "when showIcon is set to false in package settings", ->
      beforeEach ->
        spyOn(tabBar.tabForItem(item1), 'updateIconVisibility').andCallThrough()

        atom.config.set("tabs.showIcons", false)

        waitsFor ->
          tabBar.tabForItem(item1).updateIconVisibility.callCount > 0

        runs ->
          tabBar.tabForItem(item1).updateIconVisibility.reset()

      it "hides the icon", ->
        expect(tabBar.find('.tab:eq(0) .title')).toHaveClass "hide-icon"

      it "shows the icon on the tab when showIcon is changed to true", ->
        atom.config.set("tabs.showIcons", true)

        waitsFor ->
          tabBar.tabForItem(item1).updateIconVisibility.callCount > 0

        expect(tabBar.find('.tab:eq(0) .title')).not.toHaveClass "hide-icon"

  describe "when the item doesn't have an icon defined", ->
    it "doesn't display an icon on the tab", ->
      expect(tabBar.find('.tab:eq(2) .title')).not.toHaveClass "icon"
      expect(tabBar.find('.tab:eq(2) .title')).not.toHaveClass "icon-squirrel"

    it "shows the icon on the tab if an icon is defined", ->
      item2.getIconName = -> "squirrel"
      item2.emitIconChanged()
      expect(tabBar.find('.tab:eq(2) .title')).toHaveClass "icon"
      expect(tabBar.find('.tab:eq(2) .title')).toHaveClass "icon-squirrel"

  describe "when a tab item's modified status changes", ->
    it "adds or removes the 'modified' class to the tab based on the status", ->
      tab = tabBar.tabForItem(editor1)
      expect(editor1.isModified()).toBeFalsy()
      expect(tab).not.toHaveClass 'modified'

      editor1.insertText('x')
      advanceClock(editor1.buffer.stoppedChangingDelay)
      expect(editor1.isModified()).toBeTruthy()
      expect(tab).toHaveClass 'modified'

      editor1.undo()
      advanceClock(editor1.buffer.stoppedChangingDelay)
      expect(editor1.isModified()).toBeFalsy()
      expect(tab).not.toHaveClass 'modified'

  describe "when a pane item moves to a new index", ->
    it "updates the order of the tabs to match the new item order", ->
      expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
      pane.moveItem(item2, 1)
      expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "Item 2", "sample.js"]
      pane.moveItem(editor1, 0)
      expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["sample.js", "Item 1", "Item 2"]
      pane.moveItem(item1, 2)
      expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["sample.js", "Item 2", "Item 1"]

  describe "context menu commands", ->
    beforeEach ->
      paneElement = atom.views.getView(pane)
      paneElement.insertBefore(tabBar.element, paneElement.firstChild)

    describe "when tabs:close-tab is fired", ->
      it "closes the active tab", ->
        triggerMouseEvent('mousedown', tabBar.tabForItem(item2), which: 3)
        atom.commands.dispatch(tabBar.element, 'tabs:close-tab')
        expect(pane.getItems().length).toBe 2
        expect(pane.getItems().indexOf(item2)).toBe -1
        expect(tabBar.getTabs().length).toBe 2
        expect(tabBar.find('.tab:contains(Item 2)')).not.toExist()

    describe "when tabs:close-other-tabs is fired", ->
      it "closes all other tabs except the active tab", ->
        triggerMouseEvent('mousedown', tabBar.tabForItem(item2), which: 3)
        atom.commands.dispatch(tabBar.element, 'tabs:close-other-tabs')
        expect(pane.getItems().length).toBe 1
        expect(tabBar.getTabs().length).toBe 1
        expect(tabBar.find('.tab:contains(sample.js)')).not.toExist()
        expect(tabBar.find('.tab:contains(Item 2)')).toExist()

    describe "when tabs:close-tabs-to-right is fired", ->
      it "closes only the tabs to the right of the active tab", ->
        pane.activateItem(editor1)
        triggerMouseEvent('mousedown', tabBar.tabForItem(editor1), which: 3)
        atom.commands.dispatch(tabBar.element, 'tabs:close-tabs-to-right')
        expect(pane.getItems().length).toBe 2
        expect(tabBar.getTabs().length).toBe 2
        expect(tabBar.find('.tab:contains(Item 2)')).not.toExist()
        expect(tabBar.find('.tab:contains(Item 1)')).toExist()

    describe "when tabs:close-all-tabs is fired", ->
      it "closes all the tabs", ->
        expect(pane.getItems().length).toBeGreaterThan 0
        atom.commands.dispatch(tabBar.element, 'tabs:close-all-tabs')
        expect(pane.getItems().length).toBe 0

    describe "when tabs:close-saved-tabs is fired", ->
      it "closes all the saved tabs", ->
        item1.isModified = -> true
        atom.commands.dispatch(tabBar.element, 'tabs:close-saved-tabs')
        expect(pane.getItems().length).toBe 1
        expect(pane.getItems()[0]).toBe item1

    describe "when tabs:split-up is fired", ->
      it "splits the selected tab up", ->
        triggerMouseEvent('mousedown', tabBar.tabForItem(item2), which: 3)
        expect(atom.workspace.getPanes().length).toBe 1

        atom.commands.dispatch(tabBar.element, 'tabs:split-up')
        expect(atom.workspace.getPanes().length).toBe 2
        expect(atom.workspace.getPanes()[1]).toBe pane
        expect(atom.workspace.getPanes()[0].getItems()[0].getTitle()).toBe item2.getTitle()

    describe "when tabs:split-down is fired", ->
      it "splits the selected tab down", ->
        triggerMouseEvent('mousedown', tabBar.tabForItem(item2), which: 3)
        expect(atom.workspace.getPanes().length).toBe 1

        atom.commands.dispatch(tabBar.element, 'tabs:split-down')
        expect(atom.workspace.getPanes().length).toBe 2
        expect(atom.workspace.getPanes()[0]).toBe pane
        expect(atom.workspace.getPanes()[1].getItems()[0].getTitle()).toBe item2.getTitle()

    describe "when tabs:split-left is fired", ->
      it "splits the selected tab to the left", ->
        triggerMouseEvent('mousedown', tabBar.tabForItem(item2), which: 3)
        expect(atom.workspace.getPanes().length).toBe 1

        atom.commands.dispatch(tabBar.element, 'tabs:split-left')
        expect(atom.workspace.getPanes().length).toBe 2
        expect(atom.workspace.getPanes()[1]).toBe pane
        expect(atom.workspace.getPanes()[0].getItems()[0].getTitle()).toBe item2.getTitle()

    describe "when tabs:split-right is fired", ->
      it "splits the selected tab to the right", ->
        triggerMouseEvent('mousedown', tabBar.tabForItem(item2), which: 3)
        expect(atom.workspace.getPanes().length).toBe 1

        atom.commands.dispatch(tabBar.element, 'tabs:split-right')
        expect(atom.workspace.getPanes().length).toBe 2
        expect(atom.workspace.getPanes()[0]).toBe pane
        expect(atom.workspace.getPanes()[1].getItems()[0].getTitle()).toBe item2.getTitle()

  describe "command palette commands", ->
    paneElement = null

    beforeEach ->
      paneElement = atom.views.getView(pane)

    describe "when tabs:close-tab is fired", ->
      it "closes the active tab", ->
        atom.commands.dispatch(paneElement, 'tabs:close-tab')
        expect(pane.getItems().length).toBe 2
        expect(pane.getItems().indexOf(item2)).toBe -1
        expect(tabBar.getTabs().length).toBe 2
        expect(tabBar.find('.tab:contains(Item 2)')).not.toExist()

      it "does nothing if no tabs are open", ->
        atom.commands.dispatch(paneElement, 'tabs:close-tab')
        atom.commands.dispatch(paneElement, 'tabs:close-tab')
        atom.commands.dispatch(paneElement, 'tabs:close-tab')
        expect(pane.getItems().length).toBe 0
        expect(tabBar.getTabs().length).toBe 0

    describe "when tabs:close-other-tabs is fired", ->
      it "closes all other tabs except the active tab", ->
        atom.commands.dispatch(paneElement, 'tabs:close-other-tabs')
        expect(pane.getItems().length).toBe 1
        expect(tabBar.getTabs().length).toBe 1
        expect(tabBar.find('.tab:contains(sample.js)')).not.toExist()
        expect(tabBar.find('.tab:contains(Item 2)')).toExist()

    describe "when tabs:close-tabs-to-right is fired", ->
      it "closes only the tabs to the right of the active tab", ->
        pane.activateItem(editor1)
        atom.commands.dispatch(paneElement, 'tabs:close-tabs-to-right')
        expect(pane.getItems().length).toBe 2
        expect(tabBar.getTabs().length).toBe 2
        expect(tabBar.find('.tab:contains(Item 2)')).not.toExist()
        expect(tabBar.find('.tab:contains(Item 1)')).toExist()

    describe "when tabs:close-all-tabs is fired", ->
      it "closes all the tabs", ->
        expect(pane.getItems().length).toBeGreaterThan 0
        atom.commands.dispatch(paneElement, 'tabs:close-all-tabs')
        expect(pane.getItems().length).toBe 0

    describe "when tabs:close-saved-tabs is fired", ->
      it "closes all the saved tabs", ->
        item1.isModified = -> true
        atom.commands.dispatch(paneElement, 'tabs:close-saved-tabs')
        expect(pane.getItems().length).toBe 1
        expect(pane.getItems()[0]).toBe item1

  describe "dragging and dropping tabs", ->
    describe "when a tab is dragged within the same pane", ->
      describe "when it is dropped on tab that's later in the list", ->
        it "moves the tab and its item, shows the tab's item, and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.getActiveItem()).toBe item2
          spyOn(pane, 'activate')

          tabToDrag = tabBar.tabAtIndex(0)
          spyOn(tabToDrag, 'destroyTooltip')
          spyOn(tabToDrag, 'updateTooltip')
          [dragStartEvent, dropEvent] = buildDragEvents(tabToDrag, tabBar.tabAtIndex(1))
          tabBar.onDragStart(dragStartEvent)

          expect(tabToDrag.destroyTooltip).toHaveBeenCalled()
          expect(tabToDrag.updateTooltip).not.toHaveBeenCalled()

          tabBar.onDrop(dropEvent)
          expect(tabToDrag.updateTooltip).toHaveBeenCalled()

          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["sample.js", "Item 1", "Item 2"]
          expect(pane.getItems()).toEqual [editor1, item1, item2]
          expect(pane.getActiveItem()).toBe item1
          expect(pane.activate).toHaveBeenCalled()

      describe "when it is dropped on a tab that's earlier in the list", ->
        it "moves the tab and its item, shows the tab's item, and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.getActiveItem()).toBe item2
          spyOn(pane, 'activate')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(2), tabBar.tabAtIndex(0))
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "Item 2", "sample.js"]
          expect(pane.getItems()).toEqual [item1, item2, editor1]
          expect(pane.getActiveItem()).toBe item2
          expect(pane.activate).toHaveBeenCalled()

      describe "when it is dropped on itself", ->
        it "doesn't move the tab or item, but does make it the active item and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.getActiveItem()).toBe item2
          spyOn(pane, 'activate')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar.tabAtIndex(0))
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.getActiveItem()).toBe item1
          expect(pane.activate).toHaveBeenCalled()

      describe "when it is dropped on the tab bar", ->
        it "moves the tab and its item to the end", ->
          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.getActiveItem()).toBe item2
          spyOn(pane, 'activate')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar)
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["sample.js", "Item 2", "Item 1"]
          expect(pane.getItems()).toEqual [editor1, item2, item1]

    describe "when a tab is dragged to a different pane", ->
      [pane2, tabBar2, item2b] = []

      beforeEach ->
        pane2 = pane.splitRight(copyActiveItem: true)
        [item2b] = pane2.getItems()
        tabBar2 = new TabBarView(pane2)

      it "removes the tab and item from their original pane and moves them to the target pane", ->
        expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editor1, item2]
        expect(pane.getActiveItem()).toBe item2

        expect(tabBar2.getTabs().map (tab) -> tab.textContent).toEqual ["Item 2"]
        expect(pane2.getItems()).toEqual [item2b]
        expect(pane2.activeItem).toBe item2b
        spyOn(pane2, 'activate')

        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar2.tabAtIndex(0))
        tabBar.onDragStart(dragStartEvent)
        tabBar2.onDrop(dropEvent)

        expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [editor1, item2]
        expect(pane.getActiveItem()).toBe item2

        expect(tabBar2.getTabs().map (tab) -> tab.textContent).toEqual ["Item 2", "Item 1"]
        expect(pane2.getItems()).toEqual [item2b, item1]
        expect(pane2.activeItem).toBe item1
        expect(pane2.activate).toHaveBeenCalled()

      describe "when the tab is dragged to an empty pane", ->
        it "removes the tab and item from their original pane and moves them to the target pane", ->
          pane2.destroyItems()

          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.getActiveItem()).toBe item2

          expect(tabBar2.getTabs().map (tab) -> tab.textContent).toEqual []
          expect(pane2.getItems()).toEqual []
          expect(pane2.activeItem).toBeUndefined()
          spyOn(pane2, 'activate')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar2)
          tabBar.onDragStart(dragStartEvent)
          tabBar2.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [editor1, item2]
          expect(pane.getActiveItem()).toBe item2

          expect(tabBar2.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1"]
          expect(pane2.getItems()).toEqual [item1]
          expect(pane2.activeItem).toBe item1
          expect(pane2.activate).toHaveBeenCalled()

    describe "when a non-tab is dragged to pane", ->
      it "has no effect", ->
        expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editor1, item2]
        expect(pane.getActiveItem()).toBe item2
        spyOn(pane, 'activate')

        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar.tabAtIndex(0))
        tabBar.onDrop(dropEvent)

        expect(tabBar.getTabs().map (tab) -> tab.textContent).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editor1, item2]
        expect(pane.getActiveItem()).toBe item2
        expect(pane.activate).not.toHaveBeenCalled()

    describe "when a tab is dragged out of application", ->
      it "should carry the file's information", ->
        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(1), tabBar.tabAtIndex(1))
        tabBar.onDragStart(dragStartEvent)

        expect(dragStartEvent.originalEvent.dataTransfer.getData("text/plain")).toEqual editor1.getPath()
        if process.platform is 'darwin'
          expect(dragStartEvent.originalEvent.dataTransfer.getData("text/uri-list")).toEqual "file://#{editor1.getPath()}"

    describe "when a tab is dragged to another Atom window", ->
      it "closes the tab in the first window and opens the tab in the second window", ->
        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(1), tabBar.tabAtIndex(0))
        tabBar.onDragStart(dragStartEvent)
        tabBar.onDropOnOtherWindow(pane.id, 1)

        expect(pane.getItems()).toEqual [item1, item2]
        expect(pane.getActiveItem()).toBe item2

        dropEvent.originalEvent.dataTransfer.setData('from-window-id', tabBar.getWindowId() + 1)

        spyOn(tabBar, 'moveItemBetweenPanes').andCallThrough()
        tabBar.onDrop(dropEvent)

        waitsFor ->
          tabBar.moveItemBetweenPanes.callCount > 0

        runs ->
          editor = atom.workspace.getActiveTextEditor()
          expect(editor.getPath()).toBe editor1.getPath()
          expect(pane.getItems()).toEqual [item1, editor, item2]

      it "transfers the text of the editor when it is modified", ->
        editor1.setText('I came from another window')
        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(1), tabBar.tabAtIndex(0))
        tabBar.onDragStart(dragStartEvent)
        tabBar.onDropOnOtherWindow(pane.id, 1)

        dropEvent.originalEvent.dataTransfer.setData('from-window-id', tabBar.getWindowId() + 1)

        spyOn(tabBar, 'moveItemBetweenPanes').andCallThrough()
        tabBar.onDrop(dropEvent)

        waitsFor ->
          tabBar.moveItemBetweenPanes.callCount > 0

        runs ->
          expect(atom.workspace.getActiveTextEditor().getText()).toBe 'I came from another window'

      it "allows untitled editors to be moved between windows", ->
        editor1.getBuffer().setPath(null)
        editor1.setText('I have no path')

        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(1), tabBar.tabAtIndex(0))
        tabBar.onDragStart(dragStartEvent)
        tabBar.onDropOnOtherWindow(pane.id, 1)

        dropEvent.originalEvent.dataTransfer.setData('from-window-id', tabBar.getWindowId() + 1)

        spyOn(tabBar, 'moveItemBetweenPanes').andCallThrough()
        tabBar.onDrop(dropEvent)

        waitsFor ->
          tabBar.moveItemBetweenPanes.callCount > 0

        runs ->
          expect(atom.workspace.getActiveTextEditor().getText()).toBe 'I have no path'
          expect(atom.workspace.getActiveTextEditor().getPath()).toBeUndefined()

  describe "when the tab bar is double clicked", ->
    it "opens a new empty editor", ->
      newFileHandler = jasmine.createSpy('newFileHandler')
      atom.commands.add(tabBar.element, 'application:new-file', newFileHandler)

      triggerMouseEvent("dblclick", tabBar.getTabs()[0])
      expect(newFileHandler.callCount).toBe 0

      triggerMouseEvent("dblclick", tabBar[0])
      expect(newFileHandler.callCount).toBe 1

  describe "when the mouse wheel is used on the tab bar", ->
    describe "when tabScrolling is true in package settings", ->
      beforeEach ->
        atom.config.set("tabs.tabScrolling", true)
        atom.config.set("tabs.tabScrollingThreshold", 120)

      describe "when the mouse wheel scrolls up", ->
        it "changes the active tab to the previous tab", ->
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelEvent(120))
          expect(pane.getActiveItem()).toBe editor1

        it "changes the active tab to the previous tab only after the wheelDelta crosses the threshold", ->
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelEvent(50))
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelEvent(50))
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelEvent(50))
          expect(pane.getActiveItem()).toBe editor1

      describe "when the mouse wheel scrolls down", ->
        it "changes the active tab to the previous tab", ->
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelEvent(-120))
          expect(pane.getActiveItem()).toBe item1

      describe "when the mouse wheel scrolls up and shift key is pressed", ->
        it "does not change the active tab", ->
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelPlusShiftEvent(120))
          expect(pane.getActiveItem()).toBe item2

      describe "when the mouse wheel scrolls down and shift key is pressed", ->
        it "does not change the active tab", ->
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelPlusShiftEvent(-120))
          expect(pane.getActiveItem()).toBe item2

    describe "when tabScrolling is false in package settings", ->
      beforeEach ->
        atom.config.set("tabs.tabScrolling", false)

      describe "when the mouse wheel scrolls up one unit", ->
        it "does not change the active tab", ->
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelEvent(120))
          expect(pane.getActiveItem()).toBe item2

      describe "when the mouse wheel scrolls down one unit", ->
        it "does not change the active tab", ->
          expect(pane.getActiveItem()).toBe item2
          tabBar.trigger(buildWheelEvent(-120))
          expect(pane.getActiveItem()).toBe item2

  describe "when alwaysShowTabBar is true in package settings", ->
    beforeEach ->
      atom.config.set("tabs.alwaysShowTabBar", true)

    describe "when 2 tabs are open", ->
      it "shows the tab bar", ->
        expect(pane.getItems().length).toBe 3
        expect(tabBar.element).not.toHaveClass 'hidden'

    describe "when 1 tab is open", ->
      it "shows the tab bar", ->
        expect(pane.getItems().length).toBe 3
        pane.destroyItem(item1)
        pane.destroyItem(item2)
        expect(pane.getItems().length).toBe 1
        expect(tabBar.element).not.toHaveClass 'hidden'

  describe "when alwaysShowTabBar is false in package settings", ->
    beforeEach ->
      atom.config.set("tabs.alwaysShowTabBar", false)

    describe "when 2 tabs are open", ->
      it "shows the tab bar", ->
        expect(pane.getItems().length).toBe 3
        expect(tabBar.element).not.toHaveClass 'hidden'

    describe "when 1 tab is open", ->
      it "hides the tab bar", ->
        expect(pane.getItems().length).toBe 3
        pane.destroyItem(item1)
        pane.destroyItem(item2)
        expect(pane.getItems().length).toBe 1
        expect(tabBar.element).toHaveClass 'hidden'

  describe "when usePreviewTabs is true in package settings", ->
    beforeEach ->
      atom.config.set("tabs.usePreviewTabs", true)
      pane.destroyItems()

    describe "when opening a new tab", ->
      it "adds tab with class 'temp'", ->
        editor1 = null
        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) -> editor1 = o

        runs ->
          pane.activateItem(editor1)
          expect(tabBar.find('.tab .temp').length).toBe 1
          expect(tabBar.find('.tab:eq(0) .title')).toHaveClass 'temp'

    describe "when tabs:keep-preview-tab is trigger on the pane", ->
      it "removes the 'temp' class", ->
        editor1 = null
        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) -> editor1 = o

        runs ->
          pane.activateItem(editor1)
          expect(tabBar.find('.tab .temp').length).toBe 1
          atom.commands.dispatch(atom.views.getView(atom.workspace.getActivePane()), 'tabs:keep-preview-tab')
          expect(tabBar.find('.tab .temp').length).toBe 0

    describe "when there is a temp tab already", ->
      it "it will replace an existing temporary tab", ->
        editor1 = null
        editor2 = null

        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) ->
            editor1 = o
            pane.activateItem(editor1)
            atom.workspace.open('sample2.txt').then (o) ->
              editor2 = o
              pane.activateItem(editor2)

        runs ->
          expect(editor1.isDestroyed()).toBe true
          expect(editor2.isDestroyed()).toBe false
          expect(tabBar.tabForItem(editor1)).not.toExist()
          expect($(tabBar.tabForItem(editor2)).find('.title')).toHaveClass 'temp'

      it 'makes the tab permanent when double clicking the tab', ->
        editor2 = null

        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) -> editor2 = o

        runs ->
          pane.activateItem(editor2)
          dbclickEvt = document.createEvent 'MouseEvents'
          dbclickEvt.initEvent 'dblclick'
          tabBar.tabForItem(editor2).dispatchEvent dbclickEvt
          expect($(tabBar.tabForItem(editor2)).find('.title')).not.toHaveClass 'temp'

    describe 'when opening views that do not have file paths', ->
      editor2 = null
      settingsView = null

      beforeEach ->
        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) ->
            editor2 = o
            pane.activateItem(editor2)

        waitsForPromise ->
          atom.packages.activatePackage('settings-view').then ->
            atom.workspace.open('atom://config').then (o) ->
              settingsView = o
              pane.activateItem(settingsView)

      it 'creates a permanent tab', ->
        expect(tabBar.tabForItem(settingsView)).toExist()
        expect($(tabBar.tabForItem(settingsView)).find('.title')).not.toHaveClass 'temp'

      it 'keeps an existing temp tab', ->
        expect(tabBar.tabForItem(editor2)).toExist()
        expect($(tabBar.tabForItem(editor2)).find('.title')).toHaveClass 'temp'

    describe 'when editing a file', ->
      it 'makes the tab permanent', ->
        editor1 = null
        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) ->
            editor1 = o
            pane.activateItem(editor1)
            editor1.insertText('x')
            advanceClock(editor1.buffer.stoppedChangingDelay)

        runs ->
          expect($(tabBar.tabForItem(editor1)).find('.title')).not.toHaveClass 'temp'

    describe 'when saving a file', ->
      it 'makes the tab permanent', ->
        editor1 = null
        waitsForPromise ->
          atom.workspace.open(path.join(temp.mkdirSync('tabs-'), 'sample.txt')).then (o) ->
            editor1 = o
            pane.activateItem(editor1)
            editor1.save()

        runs ->
          expect($(tabBar.tabForItem(editor1)).find('.title')).not.toHaveClass 'temp'

    describe 'when switching from a preview tab to a permanent tab', ->
      it "keeps the preview tab open", ->
        atom.config.set("tabs.usePreviewTabs", false)
        editor1 = null
        editor2 = null

        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) ->
            editor1 = o
            pane.activateItem(editor1)

        runs ->
          atom.config.set("tabs.usePreviewTabs", true)

        waitsForPromise ->
          atom.workspace.open('sample2.txt').then (o) ->
            editor2 = o
            pane.activateItem(editor2)

        runs ->
          pane.activateItem(editor1)
          expect(pane.getItems().length).toBe 2
          expect($(tabBar.tabForItem(editor1)).find('.title')).not.toHaveClass 'temp'
          expect($(tabBar.tabForItem(editor2)).find('.title')).toHaveClass 'temp'

    describe "when splitting a preview tab", ->
      it "makes the tab permanent in the new pane", ->
        editor1 = null
        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) -> editor1 = o

        runs ->
          pane.activateItem(editor1)
          pane2 = pane.splitRight(copyActiveItem: true)
          tabBar2 = new TabBarView(pane2)

          expect($(tabBar2.tabForItem(pane2.getActiveItem())).find('.title')).not.toHaveClass 'temp'

    describe "when dragging a preview tab to a different pane", ->
      it "makes the tab permanent in the other pane", ->
        editor1 = null
        waitsForPromise ->
          atom.workspace.open('sample.txt').then (o) -> editor1 = o

        runs ->
          pane.activateItem(editor1)
          pane2 = pane.splitRight()

          tabBar2 = new TabBarView(pane2)
          tabBar2.moveItemBetweenPanes(pane, 0, pane2, 1, editor1)

          expect($(tabBar2.tabForItem(pane2.getActiveItem())).find('.title')).not.toHaveClass 'temp'

    describe "when a non-text file is opened", ->
      it "opens a preview tab", ->
        imageView = null
        waitsForPromise ->
          atom.workspace.open('sample.png').then (o) ->
            imageView = o
            pane.activateItem(imageView)

        runs ->
          expect(tabBar.tabForItem(imageView)).toExist()
          expect($(tabBar.tabForItem(imageView)).find('.title')).toHaveClass 'temp'

    describe "when double clicking a file in the tree view", ->
      it "makes the tab for that file permanent", ->
        editor1 = null
        workspaceElement = atom.views.getView(atom.workspace)
        jasmine.attachToDOM(workspaceElement)

        waitsForPromise ->
          atom.packages.activatePackage('tree-view')

        runs ->
          atom.commands.dispatch(workspaceElement, 'tree-view:show')

        waitsFor ->
          workspaceElement.querySelector('.tree-view')

        waitsForPromise ->
          atom.workspace.open('sample.js').then (o) -> editor1 = o

        runs ->
          pane.activateItem(editor1)

          expect($(tabBar.tabForItem(editor1)).find('.title')).toHaveClass 'temp'

          fileNode = workspaceElement.querySelector(".tree-view [data-path=\"#{path.join(__dirname, 'fixtures', 'sample.js')}\"]")
          fileNode.dispatchEvent(new MouseEvent('click', detail: 1, bubbles: true, cancelable: true))
          fileNode.dispatchEvent(new MouseEvent('click', detail: 2, bubbles: true, cancelable: true))
          fileNode.dispatchEvent(new MouseEvent('dblclick', detail: 2, bubbles: true, cancelable: true))

          expect($(tabBar.tabForItem(editor1)).find('.title')).not.toHaveClass 'temp'

  describe "integration with version control systems", ->
    [repository, tab, tab1] = []

    beforeEach ->
      tab = tabBar.tabForItem editor1
      spyOn(tab, 'setupVcsStatus').andCallThrough()
      spyOn(tab, 'updateVcsStatus').andCallThrough()

      tab1 = tabBar.tabForItem item1
      tab1.path = '/some/path/outside/the/repository'
      spyOn(tab1, 'updateVcsStatus').andCallThrough()

      # Mock the repository
      repository = jasmine.createSpyObj 'repo', ['isPathIgnored', 'getCachedPathStatus', 'isStatusNew', 'isStatusModified']
      repository.isStatusNew.andCallFake (status) -> status is 'new'
      repository.isStatusModified.andCallFake (status) -> status is 'modified'

      repository.onDidChangeStatus = (callback) ->
        @changeStatusCallbacks ?= []
        @changeStatusCallbacks.push(callback)
        dispose: => _.remove(@changeStatusCallbacks, callback)
      repository.emitDidChangeStatus = (event) ->
        callback(event) for callback in @changeStatusCallbacks ? []

      repository.onDidChangeStatuses = (callback) ->
        @changeStatusesCallbacks ?= []
        @changeStatusesCallbacks.push(callback)
        dispose: => _.remove(@changeStatusesCallbacks, callback)
      repository.emitDidChangeStatuses = (event) ->
        callback(event) for callback in @changeStatusesCallbacks ? []

      # Mock atom.project to pretend we are working within a repository
      spyOn(atom.project, 'repositoryForDirectory').andReturn Promise.resolve(repository)

      atom.config.set "tabs.enableVcsColoring", true

      waitsFor ->
        repository.changeStatusCallbacks?.length > 0

    describe "when working inside a VCS repository", ->
      it "adds custom style for new items", ->
        repository.getCachedPathStatus.andReturn 'new'
        tab.updateVcsStatus(repository)
        expect(tabBar.find('.tab:eq(1) .title')).toHaveClass "status-added"

      it "adds custom style for modified items", ->
        repository.getCachedPathStatus.andReturn 'modified'
        tab.updateVcsStatus(repository)
        expect(tabBar.find('.tab:eq(1) .title')).toHaveClass "status-modified"

      it "adds custom style for ignored items", ->
        repository.isPathIgnored.andReturn true
        tab.updateVcsStatus(repository)
        expect(tabBar.find('.tab:eq(1) .title')).toHaveClass "status-ignored"

      it "does not add any styles for items not in the repository", ->
        expect(tabBar.find('.tab:eq(0) .title')).not.toHaveClass "status-added"
        expect(tabBar.find('.tab:eq(0) .title')).not.toHaveClass "status-modified"
        expect(tabBar.find('.tab:eq(0) .title')).not.toHaveClass "status-ignored"

    describe "when changes in item statuses are notified", ->
      it "updates status for items in the repository", ->
        tab.updateVcsStatus.reset()
        repository.emitDidChangeStatuses()
        expect(tab.updateVcsStatus.calls.length).toEqual 1

      it "updates the status of an item if it has changed", ->
        repository.getCachedPathStatus.reset()
        expect(tabBar.find('.tab:eq(1) .title')).not.toHaveClass "status-modified"
        repository.emitDidChangeStatus {path: tab.path, pathStatus: "modified"}
        expect(tabBar.find('.tab:eq(1) .title')).toHaveClass "status-modified"
        expect(repository.getCachedPathStatus.calls.length).toBe 0

      it "does not update status for items not in the repository", ->
        tab1.updateVcsStatus.reset()
        repository.emitDidChangeStatuses()
        expect(tab1.updateVcsStatus.calls.length).toEqual 0

    describe "when an item is saved", ->
      it "does not update VCS subscription if the item's path remains the same", ->
        tab.setupVcsStatus.reset()
        tab.item.buffer.emitter.emit 'did-save', {path: tab.path}
        expect(tab.setupVcsStatus.calls.length).toBe 0

      it "updates VCS subscription if the item's path has changed", ->
        tab.setupVcsStatus.reset()
        tab.item.buffer.emitter.emit 'did-save', {path: '/some/other/path'}
        expect(tab.setupVcsStatus.calls.length).toBe 1

    describe "when enableVcsColoring changes in package settings", ->
      it "removes status from the tab if enableVcsColoring is set to false", ->
        repository.emitDidChangeStatus {path: tab.path, pathStatus: 'new'}

        expect(tabBar.find('.tab:eq(1) .title')).toHaveClass "status-added"
        atom.config.set "tabs.enableVcsColoring", false
        expect(tabBar.find('.tab:eq(1) .title')).not.toHaveClass "status-added"

      it "adds status to the tab if enableVcsColoring is set to true", ->
        atom.config.set "tabs.enableVcsColoring", false
        repository.getCachedPathStatus.andReturn 'modified'
        expect(tabBar.find('.tab:eq(1) .title')).not.toHaveClass "status-modified"
        atom.config.set "tabs.enableVcsColoring", true

        waitsFor ->
          repository.changeStatusCallbacks?.length > 0

        runs ->
          expect(tabBar.find('.tab:eq(1) .title')).toHaveClass "status-modified"
