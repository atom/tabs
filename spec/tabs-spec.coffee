{_, $, WorkspaceView, View}  = require 'atom'
TabBarView = require '../lib/tab-bar-view'

describe "Tabs package main", ->
  beforeEach ->
    atom.workspaceView = new WorkspaceView
    atom.workspaceView.openSync('sample.js')
    atom.packages.activatePackage("tabs")

  describe ".activate()", ->
    it "appends a tab bar all existing and new panes", ->
      expect(atom.workspaceView.panes.find('.pane').length).toBe 1
      expect(atom.workspaceView.panes.find('.pane > .tab-bar').length).toBe 1
      pane = atom.workspaceView.getActivePane()
      pane.splitRight(pane.copyActiveItem())
      expect(atom.workspaceView.find('.pane').length).toBe 2
      expect(atom.workspaceView.panes.find('.pane > .tab-bar').length).toBe 2

  describe ".deactivate()", ->
    it "removes all tab bar views and stops adding them to new panes", ->
      pane = atom.workspaceView.getActivePane()
      pane.splitRight(pane.copyActiveItem())
      expect(atom.workspaceView.panes.find('.pane').length).toBe 2
      expect(atom.workspaceView.panes.find('.pane > .tab-bar').length).toBe 2

      atom.packages.deactivatePackage('tabs')
      expect(atom.workspaceView.panes.find('.pane').length).toBe 2
      expect(atom.workspaceView.panes.find('.pane > .tab-bar').length).toBe 0

      pane.splitRight(pane.copyActiveItem())
      expect(atom.workspaceView.panes.find('.pane').length).toBe 3
      expect(atom.workspaceView.panes.find('.pane > .tab-bar').length).toBe 0

describe "TabBarView", ->
  [item1, item2, editor1, pane, tabBar] = []

  class TestView extends View
    @deserialize: ({title, longTitle}) -> new TestView(title, longTitle)
    @content: (title) -> @div title
    initialize: (@title, @longTitle) ->
    getTitle: -> @title
    getLongTitle: -> @longTitle
    serialize: -> { deserializer: 'TestView', @title, @longTitle }

  beforeEach ->
    atom.workspaceView = new WorkspaceView
    atom.deserializers.add(TestView)
    item1 = new TestView('Item 1')
    item2 = new TestView('Item 2')
    editor1 = atom.workspaceView.openSync('sample.js')
    pane = atom.workspaceView.getActivePane()
    pane.addItem(item1, 0)
    pane.addItem(item2, 2)
    pane.showItem(item2)
    tabBar = new TabBarView(pane)

  afterEach ->
    atom.deserializers.remove(TestView)

  describe ".initialize(pane)", ->
    it "creates a tab for each item on the tab bar's parent pane", ->
      expect(pane.getItems().length).toBe 3
      expect(tabBar.find('.tab').length).toBe 3

      expect(tabBar.find('.tab:eq(0) .title').text()).toBe item1.getTitle()
      expect(tabBar.find('.tab:eq(1) .title').text()).toBe editor1.getTitle()
      expect(tabBar.find('.tab:eq(2) .title').text()).toBe item2.getTitle()

    it "highlights the tab for the active pane item", ->
      expect(tabBar.find('.tab:eq(2)')).toHaveClass 'active'

  describe "when the active pane item changes", ->
    it "highlights the tab for the new active pane item", ->
      pane.showItem(item1)
      expect(tabBar.find('.active').length).toBe 1
      expect(tabBar.find('.tab:eq(0)')).toHaveClass 'active'

      pane.showItem(item2)
      expect(tabBar.find('.active').length).toBe 1
      expect(tabBar.find('.tab:eq(2)')).toHaveClass 'active'

  describe "when a new item is added to the pane", ->
    it "adds a tab for the new item at the same index as the item in the pane", ->
      pane.showItem(item1)
      item3 = new TestView('Item 3')
      pane.showItem(item3)
      expect(tabBar.find('.tab').length).toBe 4
      expect(tabBar.tabAtIndex(1).find('.title')).toHaveText 'Item 3'

    it "adds the 'modified' class to the new tab if the item is initially modified", ->
      editor2 = atom.project.openSync('sample.txt')
      editor2.insertText('x')
      pane.showItem(editor2)
      expect(tabBar.tabForItem(editor2)).toHaveClass 'modified'

  describe "when an item is removed from the pane", ->
    it "removes the item's tab from the tab bar", ->
      pane.removeItem(item2)
      expect(tabBar.getTabs().length).toBe 2
      expect(tabBar.find('.tab:contains(Item 2)')).not.toExist()

    it "updates the titles of the remaining tabs", ->
      expect(tabBar.tabForItem(item2)).toHaveText 'Item 2'
      item2.longTitle = '2'
      item2a = new TestView('Item 2')
      item2a.longTitle = '2a'
      pane.showItem(item2a)
      expect(tabBar.tabForItem(item2)).toHaveText '2'
      expect(tabBar.tabForItem(item2a)).toHaveText '2a'
      pane.removeItem(item2a)
      expect(tabBar.tabForItem(item2)).toHaveText 'Item 2'

  describe "when a tab is clicked", ->
    it "shows the associated item on the pane and focuses the pane", ->
      spyOn(pane, 'focus')

      tabBar.tabAtIndex(0).click()
      expect(pane.activeItem).toBe pane.getItems()[0]

      tabBar.tabAtIndex(2).click()
      expect(pane.activeItem).toBe pane.getItems()[2]

      expect(pane.focus.callCount).toBe 2

  describe "when a tab's close icon is clicked", ->
    it "destroys the tab's item on the pane", ->
      tabBar.tabForItem(editor1).find('.close-icon').click()
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
      item1.trigger 'title-changed'
      item2.title = "Old Man"
      item2.longTitle = "Jolly Old Man"
      item2.trigger 'title-changed'

      expect(tabBar.tabForItem(item1)).toHaveText "Grumpy Old Man"
      expect(tabBar.tabForItem(item2)).toHaveText "Jolly Old Man"

      item2.longTitle = undefined
      item2.trigger 'title-changed'

      expect(tabBar.tabForItem(item1)).toHaveText "Grumpy Old Man"
      expect(tabBar.tabForItem(item2)).toHaveText "Old Man"

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
      expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
      pane.moveItem(item2, 1)
      expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "Item 2", "sample.js"]
      pane.moveItem(editor1, 0)
      expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 1", "Item 2"]
      pane.moveItem(item1, 2)
      expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 2", "Item 1"]

  describe "dragging and dropping tabs", ->
    buildDragEvents = (dragged, dropTarget) ->
      dataTransfer =
        data: {}
        setData: (key, value) -> @data[key] = value
        getData: (key) -> @data[key]

      dragStartEvent = $.Event()
      dragStartEvent.target = dragged[0]
      dragStartEvent.originalEvent = { dataTransfer }

      dropEvent = $.Event()
      dropEvent.target = dropTarget[0]
      dropEvent.originalEvent = { dataTransfer }

      [dragStartEvent, dropEvent]

    describe "when a tab is dragged within the same pane", ->
      describe "when it is dropped on tab that's later in the list", ->
        it "moves the tab and its item, shows the tab's item, and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.activeItem).toBe item2
          spyOn(pane, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar.tabAtIndex(1))
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 1", "Item 2"]
          expect(pane.getItems()).toEqual [editor1, item1, item2]
          expect(pane.activeItem).toBe item1
          expect(pane.focus).toHaveBeenCalled()

      describe "when it is dropped on a tab that's earlier in the list", ->
        it "moves the tab and its item, shows the tab's item, and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.activeItem).toBe item2
          spyOn(pane, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(2), tabBar.tabAtIndex(0))
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "Item 2", "sample.js"]
          expect(pane.getItems()).toEqual [item1, item2, editor1]
          expect(pane.activeItem).toBe item2
          expect(pane.focus).toHaveBeenCalled()

      describe "when it is dropped on itself", ->
        it "doesn't move the tab or item, but does make it the active item and focuses the pane", ->
          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.activeItem).toBe item2
          spyOn(pane, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar.tabAtIndex(0))
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.activeItem).toBe item1
          expect(pane.focus).toHaveBeenCalled()

      describe "when it is dropped on the tab bar", ->
        it "moves the tab and its item to the end", ->
          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.activeItem).toBe item2
          spyOn(pane, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar)
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 2", "Item 1"]
          expect(pane.getItems()).toEqual [editor1, item2, item1]

    describe "when a tab is dragged to a different pane", ->
      [pane2, tabBar2, item2b] = []

      beforeEach ->
        pane2 = pane.splitRight(pane.copyActiveItem())
        [item2b] = pane2.getItems()
        tabBar2 = new TabBarView(pane2)

      it "removes the tab and item from their original pane and moves them to the target pane", ->
        expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editor1, item2]
        expect(pane.activeItem).toBe item2

        expect(tabBar2.getTabs().map (tab) -> tab.text()).toEqual ["Item 2"]
        expect(pane2.getItems()).toEqual [item2b]
        expect(pane2.activeItem).toBe item2b
        spyOn(pane2, 'focus')

        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar2.tabAtIndex(0))
        tabBar.onDragStart(dragStartEvent)
        tabBar.onDrop(dropEvent)

        expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [editor1, item2]
        expect(pane.activeItem).toBe item2

        expect(tabBar2.getTabs().map (tab) -> tab.text()).toEqual ["Item 2", "Item 1"]
        expect(pane2.getItems()).toEqual [item2b, item1]
        expect(pane2.activeItem).toBe item1
        expect(pane2.focus).toHaveBeenCalled()

      describe "when the tab is dragged to an empty pane", ->
        it "removes the tab and item from their original pane and moves them to the target pane", ->
          pane2.destroyItems()

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [item1, editor1, item2]
          expect(pane.activeItem).toBe item2

          expect(tabBar2.getTabs().map (tab) -> tab.text()).toEqual []
          expect(pane2.getItems()).toEqual []
          expect(pane2.activeItem).toBeUndefined()
          spyOn(pane2, 'focus')

          [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar2)
          tabBar.onDragStart(dragStartEvent)
          tabBar.onDrop(dropEvent)

          expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["sample.js", "Item 2"]
          expect(pane.getItems()).toEqual [editor1, item2]
          expect(pane.activeItem).toBe item2

          expect(tabBar2.getTabs().map (tab) -> tab.text()).toEqual ["Item 1"]
          expect(pane2.getItems()).toEqual [item1]
          expect(pane2.activeItem).toBe item1
          expect(pane2.focus).toHaveBeenCalled()

    describe "when a non-tab is dragged to pane", ->
      it "has no effect", ->
        expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editor1, item2]
        expect(pane.activeItem).toBe item2
        spyOn(pane, 'focus')

        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(0), tabBar.tabAtIndex(0))
        tabBar.onDrop(dropEvent)

        expect(tabBar.getTabs().map (tab) -> tab.text()).toEqual ["Item 1", "sample.js", "Item 2"]
        expect(pane.getItems()).toEqual [item1, editor1, item2]
        expect(pane.activeItem).toBe item2
        expect(pane.focus).not.toHaveBeenCalled()

    describe "when a tab is dragged out of application", ->
      it "should carry file's information", ->
        [dragStartEvent, dropEvent] = buildDragEvents(tabBar.tabAtIndex(1), tabBar.tabAtIndex(1))
        tabBar.onDragStart(dragStartEvent)

        expect(dragStartEvent.originalEvent.dataTransfer.getData("text/plain")).toEqual editor1.getPath()
        expect(dragStartEvent.originalEvent.dataTransfer.getData("text/uri-list")).toEqual 'file://' + editor1.getPath()
