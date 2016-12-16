describe 'MRU List', ->
  workspaceElement = null

  beforeEach ->
    workspaceElement = atom.views.getView(atom.workspace)

    waitsForPromise ->
      atom.workspace.open('sample.js')

    waitsForPromise ->
      atom.packages.activatePackage("tabs")

  describe ".activate()", ->
    it "has exactly one modal panel per pane", ->
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 1

      pane = atom.workspace.getActivePane()
      pane.splitRight()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 2

      pane = atom.workspace.getActivePane()
      pane.splitDown()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 3

      pane = atom.workspace.getActivePane()
      pane.close()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 2

      pane = atom.workspace.getActivePane()
      pane.close()
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 1

    it "Doesn't build list until activated for the first time", ->
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher').length).toBe 1
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 0

    it "Doesn't activate when a single pane item is open", ->
      pane = atom.workspace.getActivePane()
      atom.commands.dispatch(pane, 'pane:show-next-recently-used-item')
      expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 0

  describe "contents", ->
    pane = null

    beforeEach ->
      waitsForPromise ->
        atom.workspace.open("sample.png")
      pane = atom.workspace.getActivePane()

    it "has one item per tab", ->
      if pane.onChooseNextMRUItem?
        expect(pane.getItems().length).toBe 2
        atom.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
        expect(workspaceElement.querySelectorAll('.tabs-mru-switcher li').length).toBe 2

    it "switches between two items", ->
      firstActiveItem = pane.getActiveItem()
      atom.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
      secondActiveItem = pane.getActiveItem()
      expect(secondActiveItem).toNotBe(firstActiveItem)
      atom.commands.dispatch(workspaceElement, 'pane:move-active-item-to-top-of-stack')
      thirdActiveItem = pane.getActiveItem()
      expect(thirdActiveItem).toBe(secondActiveItem)
      atom.commands.dispatch(workspaceElement, 'pane:show-next-recently-used-item')
      atom.commands.dispatch(workspaceElement, 'pane:move-active-item-to-top-of-stack')
      fourthActiveItem = pane.getActiveItem()
      expect(fourthActiveItem).toBe(firstActiveItem)
